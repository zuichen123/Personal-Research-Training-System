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

type ImageAttachment struct {
	Name     string `json:"name,omitempty"`
	Source   string `json:"source,omitempty"`
	MimeType string `json:"mime_type,omitempty"`
	DataURL  string `json:"data_url,omitempty"`
}

type GradeRequest struct {
	Question    question.Question `json:"question"`
	UserAnswer  []string          `json:"user_answer"`
	Attachments []ImageAttachment `json:"attachments,omitempty"`
}

type GradeResult struct {
	Score         float64 `json:"score"`
	Correct       bool    `json:"correct"`
	Feedback      string  `json:"feedback"`
	Analysis      string  `json:"analysis,omitempty"`
	Explanation   string  `json:"explanation,omitempty"`
	WrongReason   string  `json:"wrong_reason,omitempty"`
	ModelMetadata string  `json:"model_metadata,omitempty"`
}

type LearnRequest struct {
	Mode           string               `json:"mode"`
	Subject        string               `json:"subject"`
	Unit           string               `json:"unit"`
	CurrentStage   string               `json:"current_stage"`
	Goals          []string             `json:"goals"`
	FinalGoal      string               `json:"final_goal"`
	TotalHours     int                  `json:"total_hours"`
	StartDate      string               `json:"start_date"`
	EndDate        string               `json:"end_date"`
	CurrentStatus  string               `json:"current_status"`
	Themes         []string             `json:"themes"`
	Supplement     string               `json:"supplement"`
	UserID         string               `json:"user_id"`
	Profile        LearnProfileSnapshot `json:"profile"`
	ProfileSummary string               `json:"profile_summary"`
}

type LearnResult struct {
	Mode              string              `json:"mode"`
	Subject           string              `json:"subject"`
	Unit              string              `json:"unit"`
	CreatedAt         string              `json:"created_at"`
	FinalGoal         string              `json:"final_goal"`
	CurrentStatus     string              `json:"current_status"`
	PlanStartDate     string              `json:"plan_start_date"`
	PlanEndDate       string              `json:"plan_end_date"`
	StudyOutline      []string            `json:"study_outline"`
	ReviewChecklist   []string            `json:"review_checklist"`
	StageSuggestion   string              `json:"stage_suggestion"`
	MissingFields     []string            `json:"missing_fields"`
	FollowUpQuestions []string            `json:"follow_up_questions"`
	Themes            []LearnTheme        `json:"themes"`
	PlanItems         []LearnPlanItemNote `json:"plan_items"`
	OptimizationHints []string            `json:"optimization_hints"`
}

type LearnProfileSnapshot struct {
	AcademicStatus    string   `json:"academic_status"`
	DailyStudyMinutes int      `json:"daily_study_minutes"`
	Goals             []string `json:"goals"`
	WeakSubjects      []string `json:"weak_subjects"`
	TargetDestination string   `json:"target_destination"`
	Notes             string   `json:"notes"`
}

type LearnTheme struct {
	Name           string          `json:"name"`
	EstimatedHours float64         `json:"estimated_hours"`
	Children       []LearnPlanNode `json:"children"`
}

type LearnPlanNode struct {
	Level          string          `json:"level"`
	Title          string          `json:"title"`
	EstimatedHours float64         `json:"estimated_hours"`
	StartDate      string          `json:"start_date"`
	EndDate        string          `json:"end_date"`
	Details        []string        `json:"details"`
	Children       []LearnPlanNode `json:"children"`
}

type LearnPlanItemNote struct {
	PlanType   string `json:"plan_type"`
	Title      string `json:"title"`
	Content    string `json:"content"`
	TargetDate string `json:"target_date"`
	Status     string `json:"status"`
	Priority   int    `json:"priority"`
}

type OptimizeLearnRequest struct {
	Plan       LearnResult `json:"plan"`
	Action     string      `json:"action"`
	Days       int         `json:"days"`
	Reason     string      `json:"reason"`
	Supplement string      `json:"supplement"`
}

type OptimizeLearnResult struct {
	Action        string      `json:"action"`
	ChangeSummary []string    `json:"change_summary"`
	UpdatedPlan   LearnResult `json:"updated_plan"`
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

type PromptTemplateConfig struct {
	Key                         string `json:"key"`
	Name                        string `json:"name"`
	PresetPrompt                string `json:"preset_prompt"`
	PresetOutputFormatPrompt    string `json:"preset_output_format_prompt"`
	CustomPrompt                string `json:"custom_prompt"`
	OutputFormatPrompt          string `json:"output_format_prompt"`
	EffectivePrompt             string `json:"effective_prompt"`
	EffectiveOutputFormatPrompt string `json:"effective_output_format_prompt"`
	UpdatedAt                   string `json:"updated_at,omitempty"`
}

type UpdatePromptTemplateRequest struct {
	CustomPrompt       *string `json:"custom_prompt"`
	OutputFormatPrompt *string `json:"output_format_prompt"`
}

type Client interface {
	GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error)
	GradeAnswer(ctx context.Context, req GradeRequest) (GradeResult, error)
	BuildLearningPlan(ctx context.Context, req LearnRequest) (LearnResult, error)
	OptimizeLearningPlan(ctx context.Context, req OptimizeLearnRequest) (OptimizeLearnResult, error)
	EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error)
	ScoreLearning(ctx context.Context, req ScoreRequest) (ScoreResult, error)
	ProviderName() string
	ModelName() string
	IsReady() bool
}
