package ai

import (
	"context"
	"time"

	"self-study-tool/internal/modules/question"
)

type GenerateRequest struct {
	Topic      string `json:"topic"`
	Subject    string `json:"subject"`
	Scope      string `json:"scope"`
	Count      int    `json:"count"`
	Difficulty int    `json:"difficulty"`
}

type GradeRequest struct {
	Question   question.Question `json:"question"`
	UserAnswer []string          `json:"user_answer"`
}

type GradeResult struct {
	Score         float64 `json:"score"`
	Correct       bool    `json:"correct"`
	Feedback      string  `json:"feedback"`
	WrongReason   string  `json:"wrong_reason,omitempty"`
	ModelMetadata string  `json:"model_metadata,omitempty"`
}

type LearnRequest struct {
	Mode         string   `json:"mode"`
	Subject      string   `json:"subject"`
	Unit         string   `json:"unit"`
	CurrentStage string   `json:"current_stage"`
	Goals        []string `json:"goals"`
}

type LearnResult struct {
	Mode            string   `json:"mode"`
	Subject         string   `json:"subject"`
	Unit            string   `json:"unit"`
	StudyOutline    []string `json:"study_outline"`
	ReviewChecklist []string `json:"review_checklist"`
	StageSuggestion string   `json:"stage_suggestion"`
}

type EvaluateRequest struct {
	Mode       string            `json:"mode"`
	Question   question.Question `json:"question"`
	UserAnswer []string          `json:"user_answer"`
	Context    string            `json:"context"`
}

type EvaluateResult struct {
	Score                    float64                `json:"score"`
	SingleEvaluation         string                 `json:"single_evaluation"`
	ComprehensiveEvaluation  string                 `json:"comprehensive_evaluation"`
	SingleExplanation        string                 `json:"single_explanation"`
	ComprehensiveExplanation string                 `json:"comprehensive_explanation"`
	KnowledgeSupplements     []string               `json:"knowledge_supplements"`
	RetestQuestions          []question.CreateInput `json:"retest_questions"`
}

type ScoreRequest struct {
	Topic     string  `json:"topic"`
	Accuracy  float64 `json:"accuracy"`
	Stability float64 `json:"stability"`
	Speed     float64 `json:"speed"`
}

type ScoreResult struct {
	Score  float64  `json:"score"`
	Grade  string   `json:"grade"`
	Advice []string `json:"advice"`
}

type ProviderStatus struct {
	Provider           string `json:"provider"`
	ConfiguredProvider string `json:"configured_provider,omitempty"`
	Model              string `json:"model"`
	ConfiguredModel    string `json:"configured_model,omitempty"`
	Ready              bool   `json:"ready"`
	Fallback           bool   `json:"fallback"`
	HasAPIKey          bool   `json:"has_api_key,omitempty"`
	OpenAIBaseURL      string `json:"openai_base_url,omitempty"`
}

type RuntimeConfig struct {
	Provider       string
	FallbackToMock bool
	MockLatency    time.Duration
	AIHTTPTimeout  time.Duration

	OpenAIBaseURL string
	OpenAIAPIKey  string
	OpenAIModel   string
	GeminiAPIKey  string
	GeminiModel   string
	ClaudeAPIKey  string
	ClaudeModel   string
}

type UpdateProviderConfigRequest struct {
	Provider      string `json:"provider"`
	APIKey        string `json:"api_key"`
	Model         string `json:"model"`
	OpenAIBaseURL string `json:"openai_base_url"`
}

type Client interface {
	GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error)
	GradeAnswer(ctx context.Context, req GradeRequest) (GradeResult, error)
	BuildLearningPlan(ctx context.Context, req LearnRequest) (LearnResult, error)
	EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error)
	ScoreLearning(ctx context.Context, req ScoreRequest) (ScoreResult, error)
	ProviderName() string
	ModelName() string
	IsReady() bool
}
