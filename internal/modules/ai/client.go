package ai

import (
	"context"
	"time"

	"prts/internal/modules/question"
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
	Mode            string               `json:"mode"`
	Subject         string               `json:"subject"`
	Unit            string               `json:"unit"`
	CurrentStage    string               `json:"current_stage"`
	Goals           []string             `json:"goals"`
	FinalGoal       string               `json:"final_goal"`
	TotalHours      int                  `json:"total_hours"`
	StartDate       string               `json:"start_date"`
	EndDate         string               `json:"end_date"`
	CurrentStatus   string               `json:"current_status"`
	Themes          []string             `json:"themes"`
	Supplement      string               `json:"supplement"`
	UserID          string               `json:"user_id"`
	ScheduleType    string               `json:"schedule_type"`
	Profile         LearnProfileSnapshot `json:"profile"`
	ProfileSummary  string               `json:"profile_summary"`
	ScheduleBinding *ScheduleBinding     `json:"schedule_binding,omitempty"`
	PromptPatch     PromptRuntimePatch   `json:"prompt_patch,omitempty"`
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
	Plan            LearnResult        `json:"plan"`
	Action          string             `json:"action"`
	Days            int                `json:"days"`
	Reason          string             `json:"reason"`
	Supplement      string             `json:"supplement"`
	ScheduleBinding *ScheduleBinding   `json:"schedule_binding,omitempty"`
	PromptPatch     PromptRuntimePatch `json:"prompt_patch,omitempty"`
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

type MathComputeRequest struct {
	Expression string             `json:"expression"`
	Variables  map[string]float64 `json:"variables,omitempty"`
	Precision  int                `json:"precision,omitempty"`
}

type MathComputeResult struct {
	Expression string             `json:"expression"`
	Variables  map[string]float64 `json:"variables,omitempty"`
	Value      float64            `json:"value"`
	Formatted  string             `json:"formatted"`
	Precision  int                `json:"precision"`
}

type MathVerifyRequest struct {
	Question        string `json:"question"`
	CandidateAnswer string `json:"candidate_answer"`
	ReferenceAnswer string `json:"reference_answer"`
	SolutionProcess string `json:"solution_process"`
}

type MathVerifyResult struct {
	Correct       bool    `json:"correct"`
	Difficulty    int     `json:"difficulty"`
	UniqueAnswer  bool    `json:"unique_answer"`
	ProcessValid  bool    `json:"process_valid"`
	Confidence    float64 `json:"confidence"`
	Summary       string  `json:"summary"`
	NormalizedRef string  `json:"normalized_reference,omitempty"`
}

type CourseScheduleLessonRequest struct {
	Title     string `json:"title,omitempty"`
	Date      string `json:"date"`
	Period    int    `json:"period,omitempty"`
	Subject   string `json:"subject"`
	Topic     string `json:"topic"`
	Classroom string `json:"classroom,omitempty"`
	StartTime string `json:"start_time,omitempty"`
	EndTime   string `json:"end_time,omitempty"`
	Status    string `json:"status,omitempty"`
	Priority  int    `json:"priority,omitempty"`
	Notes     string `json:"notes,omitempty"`
}

type CourseScheduleLessonListQuery struct {
	Date        string `json:"date,omitempty"`
	DateFrom    string `json:"date_from,omitempty"`
	DateTo      string `json:"date_to,omitempty"`
	Subject     string `json:"subject,omitempty"`
	Topic       string `json:"topic,omitempty"`
	Granularity string `json:"granularity,omitempty"` // day/week/month
}

type CourseScheduleLessonUpdateRequest struct {
	Title     string `json:"title,omitempty"`
	Date      string `json:"date,omitempty"`
	Period    int    `json:"period,omitempty"`
	Subject   string `json:"subject,omitempty"`
	Topic     string `json:"topic,omitempty"`
	Classroom string `json:"classroom,omitempty"`
	StartTime string `json:"start_time,omitempty"`
	EndTime   string `json:"end_time,omitempty"`
	Status    string `json:"status,omitempty"`
	Priority  int    `json:"priority,omitempty"`
	Notes     string `json:"notes,omitempty"`
}

type CourseScheduleLesson struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Date      string    `json:"date"`
	Period    int       `json:"period"`
	Subject   string    `json:"subject"`
	Topic     string    `json:"topic"`
	Classroom string    `json:"classroom"`
	StartTime string    `json:"start_time"`
	EndTime   string    `json:"end_time"`
	Status    string    `json:"status"`
	Priority  int       `json:"priority"`
	Notes     string    `json:"notes,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
	Key                         string            `json:"key"`
	Name                        string            `json:"name"`
	PresetPrompt                string            `json:"preset_prompt"`
	PresetOutputFormatPrompt    string            `json:"preset_output_format_prompt"`
	PresetSegments              map[string]string `json:"preset_segments,omitempty"`
	CustomPrompt                string            `json:"custom_prompt"`
	OutputFormatPrompt          string            `json:"output_format_prompt"`
	SegmentOverrides            map[string]string `json:"segment_overrides,omitempty"`
	EffectiveSegments           map[string]string `json:"effective_segments,omitempty"`
	EffectivePrompt             string            `json:"effective_prompt"`
	EffectiveOutputFormatPrompt string            `json:"effective_output_format_prompt"`
	UpdatedAt                   string            `json:"updated_at,omitempty"`
}

type UpdatePromptTemplateRequest struct {
	CustomPrompt       *string           `json:"custom_prompt"`
	OutputFormatPrompt *string           `json:"output_format_prompt"`
	SegmentUpdates     map[string]string `json:"segment_updates,omitempty"`
	SegmentDeletes     []string          `json:"segment_deletes,omitempty"`
	ReplaceSegments    bool              `json:"replace_segments,omitempty"`
}

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type IntentResult struct {
	Action     string         `json:"action"`
	Confidence float64        `json:"confidence"`
	Reason     string         `json:"reason,omitempty"`
	Params     map[string]any `json:"params,omitempty"`
}

type PendingConfirmation struct {
	Action  string         `json:"action"`
	Prompt  string         `json:"prompt"`
	Params  map[string]any `json:"params,omitempty"`
	Created string         `json:"created_at,omitempty"`
}

type AgentArtifact struct {
	ID           string         `json:"id"`
	SessionID    string         `json:"session_id"`
	MessageID    string         `json:"message_id"`
	Type         string         `json:"type"`
	Payload      map[string]any `json:"payload"`
	ImportStatus string         `json:"import_status"`
	CreatedAt    string         `json:"created_at"`
	ImportedAt   string         `json:"imported_at,omitempty"`
}

type ChatRequest struct {
	SystemPrompt string             `json:"system_prompt,omitempty"`
	Messages     []ChatMessage      `json:"messages"`
	Attachments  []ImageAttachment  `json:"attachments,omitempty"`
	Mode         string             `json:"mode,omitempty"`
	PromptPatch  PromptRuntimePatch `json:"prompt_patch,omitempty"`
}

type ChatResponse struct {
	Content string       `json:"content"`
	Intent  IntentResult `json:"intent"`
}

type PromptRuntimePatch struct {
	SegmentUpdates  map[string]string `json:"segment_updates,omitempty"`
	SegmentDeletes  []string          `json:"segment_deletes,omitempty"`
	ReplaceSegments bool              `json:"replace_segments,omitempty"`
}

type ScheduleBinding struct {
	Mode               string   `json:"mode"`
	Theme              string   `json:"theme,omitempty"`
	ManualPlanIDs      []string `json:"manual_plan_ids,omitempty"`
	AutoEnabled        bool     `json:"auto_enabled"`
	UpdatedAt          string   `json:"updated_at,omitempty"`
	LastAutoTheme      string   `json:"last_auto_theme,omitempty"`
	LastMatchedPlanIDs []string `json:"last_matched_plan_ids,omitempty"`
}

type DefaultAgentProvider struct {
	Available bool                `json:"available"`
	Provider  string              `json:"provider"`
	Protocol  AgentProtocol       `json:"protocol,omitempty"`
	Primary   AgentProviderConfig `json:"primary,omitempty"`
}

type Client interface {
	GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error)
	GradeAnswer(ctx context.Context, req GradeRequest) (GradeResult, error)
	BuildLearningPlan(ctx context.Context, req LearnRequest) (LearnResult, error)
	OptimizeLearningPlan(ctx context.Context, req OptimizeLearnRequest) (OptimizeLearnResult, error)
	EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error)
	ScoreLearning(ctx context.Context, req ScoreRequest) (ScoreResult, error)
	Chat(ctx context.Context, req ChatRequest) (ChatResponse, error)
	ProviderName() string
	ModelName() string
	IsReady() bool
}
