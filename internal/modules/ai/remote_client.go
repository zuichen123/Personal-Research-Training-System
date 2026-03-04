package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
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

func (c *remoteLLMClient) buildOperationPrompt(operation, userInput string) string {
	if c.promptRuntime == nil {
		return strings.TrimSpace(userInput)
	}
	return c.promptRuntime.Compose(operation, userInput)
}

func (c *remoteLLMClient) GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error) {
	if !c.ready {
		return nil, errs.BadRequest("ai provider is not ready")
	}
	if req.Count <= 0 {
		req.Count = 3
	}
	if req.Count > 20 {
		req.Count = 20
	}
	if req.Difficulty < 1 {
		req.Difficulty = 2
	}
	if strings.TrimSpace(req.Subject) == "" {
		req.Subject = "general"
	}

	userInput := fmt.Sprintf(
		`Generate %d items.
topic=%s
subject=%s
scope=%s
difficulty=%d`,
		req.Count,
		req.Topic,
		req.Subject,
		req.Scope,
		req.Difficulty,
	)
	prompt := c.buildOperationPrompt(PromptKeyGenerateQuestions, userInput)

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
	if !c.ready {
		return GradeResult{}, errs.BadRequest("ai provider is not ready")
	}
	userInput := fmt.Sprintf(
		`question_title=%s
question_stem=%s
answer_key=%v
user_answer=%v
attachment_files=%d`,
		req.Question.Title,
		req.Question.Stem,
		req.Question.AnswerKey,
		req.UserAnswer,
		len(req.Attachments),
	)
	prompt := c.buildOperationPrompt(PromptKeyGradeAnswer, userInput)
	var out GradeResult
	if err := c.invokeJSON(ctx, "grade_answer", prompt, req.Attachments, &out); err != nil {
		return GradeResult{}, err
	}
	if out.Score < 0 {
		out.Score = 0
	}
	if out.Score > 100 {
		out.Score = 100
	}
	out.Score = math.Round(out.Score*10) / 10
	return out, nil
}

func (c *remoteLLMClient) BuildLearningPlan(ctx context.Context, req LearnRequest) (LearnResult, error) {
	if !c.ready {
		return LearnResult{}, errs.BadRequest("ai provider is not ready")
	}
	userInput := fmt.Sprintf(
		`mode=%s
subject=%s
unit=%s
current_stage=%s
goals=%v
final_goal=%s
total_hours=%d
start_date=%s
end_date=%s
current_status=%s
themes=%v
supplement=%s
profile_summary=%s`,
		req.Mode, req.Subject, req.Unit, req.CurrentStage, req.Goals,
		req.FinalGoal, req.TotalHours, req.StartDate, req.EndDate, req.CurrentStatus,
		req.Themes, req.Supplement, req.ProfileSummary,
	)
	prompt := c.buildOperationPrompt(PromptKeyBuildLearningPlan, userInput)
	var out LearnResult
	if err := c.invokeJSON(ctx, "build_learning_plan", prompt, nil, &out); err != nil {
		return LearnResult{}, err
	}
	return out, nil
}

func (c *remoteLLMClient) OptimizeLearningPlan(ctx context.Context, req OptimizeLearnRequest) (OptimizeLearnResult, error) {
	if !c.ready {
		return OptimizeLearnResult{}, errs.BadRequest("ai provider is not ready")
	}
	planJSON, _ := json.Marshal(req.Plan)
	userInput := fmt.Sprintf(
		`action=%s
days=%d
reason=%s
supplement=%s
plan=%s`,
		req.Action,
		req.Days,
		req.Reason,
		req.Supplement,
		string(planJSON),
	)
	prompt := c.buildOperationPrompt(PromptKeyOptimizeLearning, userInput)
	var out OptimizeLearnResult
	if err := c.invokeJSON(ctx, "optimize_learning_plan", prompt, nil, &out); err != nil {
		return OptimizeLearnResult{}, err
	}
	return out, nil
}

func (c *remoteLLMClient) EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error) {
	if !c.ready {
		return EvaluateResult{}, errs.BadRequest("ai provider is not ready")
	}
	userInput := fmt.Sprintf(
		`mode=%s
question=%s
answer_key=%v
user_answer=%v
context=%s`,
		req.Mode,
		req.Question.Stem,
		req.Question.AnswerKey,
		req.UserAnswer,
		req.Context,
	)
	prompt := c.buildOperationPrompt(PromptKeyEvaluateLearning, userInput)
	var out EvaluateResult
	if err := c.invokeJSON(ctx, "evaluate_learning", prompt, nil, &out); err != nil {
		return EvaluateResult{}, err
	}
	if out.Score < 0 {
		out.Score = 0
	}
	if out.Score > 100 {
		out.Score = 100
	}
	out.Score = math.Round(out.Score*10) / 10
	return out, nil
}

func (c *remoteLLMClient) ScoreLearning(ctx context.Context, req ScoreRequest) (ScoreResult, error) {
	if !c.ready {
		return ScoreResult{}, errs.BadRequest("ai provider is not ready")
	}
	userInput := fmt.Sprintf(
		`topic=%s
accuracy=%.1f
stability=%.1f
speed=%.1f`,
		req.Topic, req.Accuracy, req.Stability, req.Speed,
	)
	prompt := c.buildOperationPrompt(PromptKeyScoreLearning, userInput)
	var out ScoreResult
	if err := c.invokeJSON(ctx, "score_learning", prompt, nil, &out); err != nil {
		return ScoreResult{}, err
	}
	if out.Score < 0 {
		out.Score = 0
	}
	if out.Score > 100 {
		out.Score = 100
	}
	out.Score = math.Round(out.Score*10) / 10
	return out, nil
}

func (c *remoteLLMClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	if !c.ready {
		return ChatResponse{}, errs.BadRequest("ai provider is not ready")
	}
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
		userInput = "user: hello"
	}

	mode := strings.ToLower(strings.TrimSpace(req.Mode))
	key := PromptKeyAgentChat
	operation := "agent_chat"
	if mode == "detect_intent" {
		key = PromptKeyDetectIntent
		operation = "detect_intent"
	} else if mode == "compress_session" {
		key = PromptKeyCompressSession
		operation = "compress_session"
	}
	prompt := c.buildOperationPrompt(key, userInput)
	var out ChatResponse
	if err := c.invokeJSON(ctx, operation, prompt, nil, &out); err != nil {
		return ChatResponse{}, err
	}
	if strings.TrimSpace(out.Content) == "" && mode != "detect_intent" {
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
		logger.Error("ai call failed",
			slog.String("event", "ai.call.summary"),
			slog.String("ai_provider", c.provider),
			slog.String("ai_model", c.model),
			slog.String("ai_op", operation),
			slog.Int64("latency_ms", latency),
			slog.String("error", err.Error()),
		)
		return errs.Internal(fmt.Sprintf("ai %s failed: %v", operation, err))
	}
	jsonText := extractJSONText(raw)
	if err := json.Unmarshal([]byte(jsonText), out); err != nil {
		logger.Error("ai response parse failed",
			slog.String("event", "ai.call.summary"),
			slog.String("ai_provider", c.provider),
			slog.String("ai_model", c.model),
			slog.String("ai_op", operation),
			slog.Int64("latency_ms", latency),
			slog.String("error", err.Error()),
			slog.String("response_preview", truncate(raw, 500)),
		)
		return errs.Internal("ai response format invalid")
	}
	logger.Info("ai call success",
		slog.String("event", "ai.call.summary"),
		slog.String("ai_provider", c.provider),
		slog.String("ai_model", c.model),
		slog.String("ai_op", operation),
		slog.Int64("latency_ms", latency),
		slog.Int("attachment_files", len(attachments)),
		slog.Int("response_chars", len(raw)),
	)
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

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
