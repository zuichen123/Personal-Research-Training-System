package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/platform/observability/logx"
	"self-study-tool/internal/shared/errs"
)

type promptInvokeInput struct {
	Prompt      string
	Attachments []ImageAttachment
}

type promptInvoker func(ctx context.Context, input promptInvokeInput) (string, error)

type remoteLLMClient struct {
	provider string
	model    string
	ready    bool
	invoke   promptInvoker

	promptRuntime *PromptTemplateRuntime
}

func newRemoteLLMClient(provider, model string, ready bool, invoke promptInvoker) *remoteLLMClient {
	return &remoteLLMClient{
		provider: provider,
		model:    model,
		ready:    ready,
		invoke:   invoke,

		promptRuntime: NewPromptTemplateRuntime(),
	}
}

func (c *remoteLLMClient) ProviderName() string {
	return c.provider
}

func (c *remoteLLMClient) ModelName() string {
	return c.model
}

func (c *remoteLLMClient) IsReady() bool {
	return c.ready
}

func (c *remoteLLMClient) SetPromptTemplateRuntime(runtime *PromptTemplateRuntime) {
	if runtime == nil {
		return
	}
	c.promptRuntime = runtime
}

func (c *remoteLLMClient) buildOperationPrompt(operation, userInput string, patch PromptRuntimePatch) string {
	if c.promptRuntime == nil {
		return strings.TrimSpace(userInput)
	}
	return c.promptRuntime.ComposeWithPatch(operation, userInput, patch)
}

func (c *remoteLLMClient) ensureReady() error {
	if c.ready {
		return nil
	}
	return errs.BadRequest("ai provider is not ready")
}

func (c *remoteLLMClient) GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error) {
	if err := c.ensureReady(); err != nil {
		return nil, err
	}
	req = normalizeGenerateRequest(req)

	userInput := buildPromptKeyValueInput(
		promptField{key: "instruction", value: fmt.Sprintf("Generate %d items.", req.Count)},
		promptField{key: "topic", value: req.Topic},
		promptField{key: "subject", value: req.Subject},
		promptField{key: "scope", value: req.Scope},
		promptField{key: "difficulty", value: req.Difficulty},
	)
	prompt := c.buildOperationPrompt(PromptKeyGenerateQuestions, userInput, PromptRuntimePatch{})

	var payload struct {
		Items []question.CreateInput `json:"items"`
	}
	if err := c.invokeJSON(ctx, "generate_questions", prompt, nil, &payload); err != nil {
		return nil, err
	}
	if len(payload.Items) == 0 {
		return nil, errs.Internal("ai provider returned empty generated questions")
	}
	for i := range payload.Items {
		payload.Items[i].Source = question.SourceAIGenerated
		if strings.TrimSpace(payload.Items[i].Subject) == "" {
			payload.Items[i].Subject = req.Subject
		}
		if payload.Items[i].Difficulty <= 0 {
			payload.Items[i].Difficulty = req.Difficulty
		}
		if len(payload.Items[i].AnswerKey) == 0 {
			payload.Items[i].AnswerKey = []string{"core concept"}
		}
		if payload.Items[i].Type == "" {
			payload.Items[i].Type = question.ShortAnswer
		}
	}
	return payload.Items, nil
}

func (c *remoteLLMClient) GradeAnswer(ctx context.Context, req GradeRequest) (GradeResult, error) {
	if err := c.ensureReady(); err != nil {
		return GradeResult{}, err
	}
	userInput := buildPromptKeyValueInput(
		promptField{key: "question_title", value: req.Question.Title},
		promptField{key: "question_stem", value: req.Question.Stem},
		promptField{key: "answer_key", value: req.Question.AnswerKey},
		promptField{key: "user_answer", value: req.UserAnswer},
		promptField{key: "attachment_files", value: len(req.Attachments)},
	)
	prompt := c.buildOperationPrompt(PromptKeyGradeAnswer, userInput, PromptRuntimePatch{})
	var out GradeResult
	if err := c.invokeJSON(ctx, "grade_answer", prompt, req.Attachments, &out); err != nil {
		return GradeResult{}, err
	}
	out.Score = normalizePercentageScore(out.Score)
	return out, nil
}

func (c *remoteLLMClient) BuildLearningPlan(ctx context.Context, req LearnRequest) (LearnResult, error) {
	if err := c.ensureReady(); err != nil {
		return LearnResult{}, err
	}
	userInput := buildPromptKeyValueInput(
		promptField{key: "mode", value: req.Mode},
		promptField{key: "subject", value: req.Subject},
		promptField{key: "unit", value: req.Unit},
		promptField{key: "current_stage", value: req.CurrentStage},
		promptField{key: "goals", value: req.Goals},
		promptField{key: "final_goal", value: req.FinalGoal},
		promptField{key: "total_hours", value: req.TotalHours},
		promptField{key: "start_date", value: req.StartDate},
		promptField{key: "end_date", value: req.EndDate},
		promptField{key: "current_status", value: req.CurrentStatus},
		promptField{key: "themes", value: req.Themes},
		promptField{key: "supplement", value: req.Supplement},
		promptField{key: "profile_summary", value: req.ProfileSummary},
	)
	prompt := c.buildOperationPrompt(PromptKeyBuildLearningPlan, userInput, req.PromptPatch)
	var out LearnResult
	if err := c.invokeJSON(ctx, "build_learning_plan", prompt, nil, &out); err != nil {
		return LearnResult{}, err
	}
	return out, nil
}

func (c *remoteLLMClient) OptimizeLearningPlan(ctx context.Context, req OptimizeLearnRequest) (OptimizeLearnResult, error) {
	if err := c.ensureReady(); err != nil {
		return OptimizeLearnResult{}, err
	}
	userInput := buildPromptKeyValueInput(
		promptField{key: "action", value: req.Action},
		promptField{key: "days", value: req.Days},
		promptField{key: "reason", value: req.Reason},
		promptField{key: "supplement", value: req.Supplement},
		promptField{key: "plan", value: jsonPromptValue(req.Plan)},
	)
	prompt := c.buildOperationPrompt(PromptKeyOptimizeLearning, userInput, req.PromptPatch)
	var out OptimizeLearnResult
	if err := c.invokeJSON(ctx, "optimize_learning_plan", prompt, nil, &out); err != nil {
		return OptimizeLearnResult{}, err
	}
	return out, nil
}

func (c *remoteLLMClient) EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error) {
	if err := c.ensureReady(); err != nil {
		return EvaluateResult{}, err
	}
	userInput := buildPromptKeyValueInput(
		promptField{key: "mode", value: req.Mode},
		promptField{key: "question", value: req.Question.Stem},
		promptField{key: "answer_key", value: req.Question.AnswerKey},
		promptField{key: "user_answer", value: req.UserAnswer},
		promptField{key: "context", value: req.Context},
	)
	prompt := c.buildOperationPrompt(PromptKeyEvaluateLearning, userInput, PromptRuntimePatch{})
	var out EvaluateResult
	if err := c.invokeJSON(ctx, "evaluate_learning", prompt, nil, &out); err != nil {
		return EvaluateResult{}, err
	}
	out.Score = normalizePercentageScore(out.Score)
	return out, nil
}

func (c *remoteLLMClient) ScoreLearning(ctx context.Context, req ScoreRequest) (ScoreResult, error) {
	if err := c.ensureReady(); err != nil {
		return ScoreResult{}, err
	}
	userInput := buildPromptKeyValueInput(
		promptField{key: "topic", value: req.Topic},
		promptField{key: "accuracy", value: fmt.Sprintf("%.1f", req.Accuracy)},
		promptField{key: "stability", value: fmt.Sprintf("%.1f", req.Stability)},
		promptField{key: "speed", value: fmt.Sprintf("%.1f", req.Speed)},
	)
	prompt := c.buildOperationPrompt(PromptKeyScoreLearning, userInput, PromptRuntimePatch{})
	var out ScoreResult
	if err := c.invokeJSON(ctx, "score_learning", prompt, nil, &out); err != nil {
		return ScoreResult{}, err
	}
	out.Score = normalizePercentageScore(out.Score)
	return out, nil
}

func (c *remoteLLMClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	if err := c.ensureReady(); err != nil {
		return ChatResponse{}, err
	}
	userInput := buildChatUserInput(req)
	modeConfig := resolveChatModeConfig(req.Mode)
	prompt := c.buildOperationPrompt(modeConfig.promptKey, userInput, req.PromptPatch)
	var out ChatResponse
	if err := c.invokeJSON(ctx, modeConfig.operation, prompt, req.Attachments, &out); err != nil {
		return ChatResponse{}, err
	}
	if strings.TrimSpace(out.Content) == "" && modeConfig.mode != PromptKeyDetectIntent {
		out.Content = "I have processed your message."
	}
	if out.Intent.Params == nil {
		out.Intent.Params = map[string]any{}
	}
	return out, nil
}

func (c *remoteLLMClient) invokeJSON(
	ctx context.Context,
	operation, prompt string,
	attachments []ImageAttachment,
	out any,
) error {
	start := time.Now()
	raw, err := c.invoke(ctx, promptInvokeInput{
		Prompt:      prompt,
		Attachments: attachments,
	})
	latency := time.Since(start).Milliseconds()
	logger := logx.LoggerFromContext(ctx)

	if err != nil {
		logger.Error("ai call failed", c.aiCallSummaryArgs(
			operation,
			latency,
			slog.String("error", err.Error()),
		)...)
		return errs.Internal(fmt.Sprintf("ai %s failed: %v", operation, err))
	}
	jsonText := extractJSONText(raw)
	if err := json.Unmarshal([]byte(jsonText), out); err != nil {
		logger.Error("ai response parse failed", c.aiCallSummaryArgs(
			operation,
			latency,
			slog.String("error", err.Error()),
			slog.String("response_preview", truncate(raw, 500)),
		)...)
		return errs.Internal("ai response format invalid")
	}
	logger.Info("ai call success", c.aiCallSummaryArgs(
		operation,
		latency,
		slog.Int("attachment_files", len(attachments)),
		slog.Int("response_chars", len(raw)),
	)...)
	return nil
}

func extractJSONText(raw string) string {
	trimmed := strings.TrimSpace(raw)
	trimmed = strings.TrimPrefix(trimmed, "```json")
	trimmed = strings.TrimPrefix(trimmed, "```")
	trimmed = strings.TrimSuffix(trimmed, "```")
	trimmed = strings.TrimSpace(trimmed)

	start := strings.Index(trimmed, "{")
	end := strings.LastIndex(trimmed, "}")
	if start >= 0 && end >= 0 && end > start {
		return trimmed[start : end+1]
	}
	return trimmed
}

func normalizePercentageScore(score float64) float64 {
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	return roundOneDecimal(score)
}

type chatModeConfig struct {
	mode      string
	promptKey string
	operation string
}

func buildChatUserInput(req ChatRequest) string {
	lines := make([]string, 0, len(req.Messages)+2)
	if strings.TrimSpace(req.SystemPrompt) != "" {
		lines = append(lines, "system: "+strings.TrimSpace(req.SystemPrompt))
	}
	for _, message := range req.Messages {
		role := strings.TrimSpace(message.Role)
		if role == "" {
			role = "user"
		}
		content := strings.TrimSpace(message.Content)
		if content == "" {
			continue
		}
		lines = append(lines, fmt.Sprintf("%s: %s", role, content))
	}
	userInput := strings.Join(lines, "\n")
	if userInput == "" {
		return "user: hello"
	}
	return userInput
}

func resolveChatModeConfig(mode string) chatModeConfig {
	normalized := strings.ToLower(strings.TrimSpace(mode))
	config := chatModeConfig{
		mode:      normalized,
		promptKey: PromptKeyAgentChat,
		operation: "agent_chat",
	}
	switch normalized {
	case PromptKeyDetectIntent:
		config.promptKey = PromptKeyDetectIntent
		config.operation = "detect_intent"
	case PromptKeyCompressSession:
		config.promptKey = PromptKeyCompressSession
		config.operation = "compress_session"
	}
	return config
}

func (c *remoteLLMClient) aiCallSummaryArgs(operation string, latency int64, extra ...slog.Attr) []any {
	args := []any{
		slog.String("event", "ai.call.summary"),
		slog.String("ai_provider", c.provider),
		slog.String("ai_model", c.model),
		slog.String("ai_op", operation),
		slog.Int64("latency_ms", latency),
	}
	for _, attr := range extra {
		args = append(args, attr)
	}
	return args
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
