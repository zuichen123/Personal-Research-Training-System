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

type promptInvoker func(ctx context.Context, prompt string) (string, error)

type remoteLLMClient struct {
	provider string
	model    string
	ready    bool
	invoke   promptInvoker
}

func newRemoteLLMClient(provider, model string, ready bool, invoke promptInvoker) *remoteLLMClient {
	return &remoteLLMClient{
		provider: provider,
		model:    model,
		ready:    ready,
		invoke:   invoke,
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

	prompt := fmt.Sprintf(
		`You are an exam question generator.
Return ONLY valid JSON object with this schema:
{
  "items":[
    {
      "title":"string",
      "stem":"string",
      "type":"single_choice|multi_choice|short_answer",
      "subject":"string",
      "source":"ai_generated",
      "options":[{"key":"A","text":"...","score":0}],
      "answer_key":["string"],
      "tags":["string"],
      "difficulty":1-5,
      "mastery_level":0-100
    }
  ]
}
Generate %d items for topic "%s", subject "%s", scope "%s", difficulty %d.`,
		req.Count,
		req.Topic,
		req.Subject,
		req.Scope,
		req.Difficulty,
	)

	var payload struct {
		Items []question.CreateInput `json:"items"`
	}
	if err := c.invokeJSON(ctx, "generate_questions", prompt, &payload); err != nil {
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
	prompt := fmt.Sprintf(
		`You are a strict grader.
Question title: %s
Question stem: %s
Answer key: %v
User answer: %v
Return ONLY JSON:
{
  "score":0-100,
  "correct":true|false,
  "feedback":"string",
  "wrong_reason":"string"
}`,
		req.Question.Title,
		req.Question.Stem,
		req.Question.AnswerKey,
		req.UserAnswer,
	)
	var out GradeResult
	if err := c.invokeJSON(ctx, "grade_answer", prompt, &out); err != nil {
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
	prompt := fmt.Sprintf(
		`Build a study plan in JSON only.
Input:
mode=%s
subject=%s
unit=%s
current_stage=%s
goals=%v
Output schema:
{
  "mode":"string",
  "subject":"string",
  "unit":"string",
  "study_outline":["string"],
  "review_checklist":["string"],
  "stage_suggestion":"string"
}`,
		req.Mode, req.Subject, req.Unit, req.CurrentStage, req.Goals,
	)
	var out LearnResult
	if err := c.invokeJSON(ctx, "build_learning_plan", prompt, &out); err != nil {
		return LearnResult{}, err
	}
	return out, nil
}

func (c *remoteLLMClient) EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error) {
	if !c.ready {
		return EvaluateResult{}, errs.BadRequest("ai provider is not ready")
	}
	prompt := fmt.Sprintf(
		`Evaluate learning result.
mode=%s
question=%s
answer_key=%v
user_answer=%v
context=%s
Return ONLY JSON:
{
  "score":0-100,
  "single_evaluation":"string",
  "comprehensive_evaluation":"string",
  "single_explanation":"string",
  "comprehensive_explanation":"string",
  "knowledge_supplements":["string"],
  "retest_questions":[
    {
      "title":"string",
      "stem":"string",
      "type":"short_answer",
      "subject":"string",
      "source":"wrong_book",
      "answer_key":["string"],
      "tags":["retest"],
      "difficulty":1-5,
      "mastery_level":0
    }
  ]
}`,
		req.Mode,
		req.Question.Stem,
		req.Question.AnswerKey,
		req.UserAnswer,
		req.Context,
	)
	var out EvaluateResult
	if err := c.invokeJSON(ctx, "evaluate_learning", prompt, &out); err != nil {
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
	prompt := fmt.Sprintf(
		`You are a learning score assistant.
topic=%s accuracy=%.1f stability=%.1f speed=%.1f
Return ONLY JSON:
{
  "score":0-100,
  "grade":"A|B|C|D|E",
  "advice":["string"]
}`,
		req.Topic, req.Accuracy, req.Stability, req.Speed,
	)
	var out ScoreResult
	if err := c.invokeJSON(ctx, "score_learning", prompt, &out); err != nil {
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

func (c *remoteLLMClient) invokeJSON(ctx context.Context, operation, prompt string, out any) error {
	start := time.Now()
	raw, err := c.invoke(ctx, prompt)
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
