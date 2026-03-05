package ai

import (
	"context"
	"fmt"
	"math"
	"net/url"
	"strings"
	"sync"
	"time"

	"self-study-tool/internal/modules/plan"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/shared/errs"
)

type Service struct {
	mu              sync.RWMutex
	client          Client
	questionService *question.Service
	planService     *plan.Service
	appControl      AppControl
	fallbackEnabled bool
	runtime         RuntimeConfig
	configStore     ProviderConfigStore
	agentStore      AgentChatStore

	promptStore   PromptTemplateStore
	promptRuntime *PromptTemplateRuntime
}

type promptTemplateRuntimeAware interface {
	SetPromptTemplateRuntime(runtime *PromptTemplateRuntime)
}

type AppControlRequest struct {
	Module    string         `json:"module"`
	Operation string         `json:"operation"`
	Params    map[string]any `json:"params"`
}

type AppControlResult struct {
	Summary string         `json:"summary"`
	Data    map[string]any `json:"data,omitempty"`
}

type AppControl interface {
	Execute(ctx context.Context, req AppControlRequest) (AppControlResult, error)
}

func NewService(client Client, questionService *question.Service, fallbackEnabled bool, runtime RuntimeConfig) *Service {
	return NewServiceWithStore(client, questionService, fallbackEnabled, runtime, nil)
}

func NewServiceWithStore(
	client Client,
	questionService *question.Service,
	fallbackEnabled bool,
	runtime RuntimeConfig,
	configStore ProviderConfigStore,
) *Service {
	return NewServiceWithStoreAndDeps(
		client,
		questionService,
		nil,
		fallbackEnabled,
		runtime,
		configStore,
		nil,
	)
}

func NewServiceWithStoreAndDeps(
	client Client,
	questionService *question.Service,
	planService *plan.Service,
	fallbackEnabled bool,
	runtime RuntimeConfig,
	configStore ProviderConfigStore,
	agentStore AgentChatStore,
) *Service {
	var promptStore PromptTemplateStore
	if s, ok := configStore.(PromptTemplateStore); ok {
		promptStore = s
	}
	runtime.Provider = strings.ToLower(strings.TrimSpace(runtime.Provider))
	service := &Service{
		client:          client,
		questionService: questionService,
		planService:     planService,
		fallbackEnabled: fallbackEnabled,
		runtime:         runtime,
		configStore:     configStore,
		agentStore:      agentStore,
		promptStore:     promptStore,
		promptRuntime:   NewPromptTemplateRuntime(),
	}
	service.bindPromptRuntimeLocked()
	return service
}

func (s *Service) SetAppControl(control AppControl) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.appControl = control
}

func (s *Service) bindPromptRuntimeLocked() {
	if aware, ok := s.client.(promptTemplateRuntimeAware); ok {
		aware.SetPromptTemplateRuntime(s.promptRuntime)
	}
}

func (s *Service) ProviderStatus() ProviderStatus {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.providerStatusLocked()
}

func (s *Service) DefaultAgentProviderConfig() (AgentProtocol, AgentProviderConfig, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.defaultAgentProviderConfigLocked()
}

func (s *Service) UpdateProviderConfig(req UpdateProviderConfigRequest) (ProviderStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	prevRuntime := s.runtime
	prevClient := s.client
	prevFallback := s.fallbackEnabled

	nextProvider := strings.ToLower(strings.TrimSpace(req.Provider))
	if nextProvider == "" {
		nextProvider = strings.ToLower(strings.TrimSpace(s.runtime.Provider))
	}
	if nextProvider == "" {
		nextProvider = strings.ToLower(strings.TrimSpace(s.client.ProviderName()))
	}
	if !isSupportedProvider(nextProvider) {
		return ProviderStatus{}, errs.BadRequest("provider must be one of: mock/openai/gemini/claude")
	}

	nextModel := strings.TrimSpace(req.Model)
	nextAPIKey := strings.TrimSpace(req.APIKey)
	nextOpenAIBaseURL := strings.TrimSpace(req.OpenAIBaseURL)
	if nextOpenAIBaseURL != "" {
		normalized, err := normalizeAbsoluteURL(nextOpenAIBaseURL)
		if err != nil {
			return ProviderStatus{}, err
		}
		nextOpenAIBaseURL = normalized
	}

	s.runtime.Provider = nextProvider
	switch nextProvider {
	case "openai":
		if nextOpenAIBaseURL != "" {
			s.runtime.OpenAIBaseURL = nextOpenAIBaseURL
		}
		if nextAPIKey != "" {
			s.runtime.OpenAIAPIKey = nextAPIKey
		}
		if nextModel != "" {
			s.runtime.OpenAIModel = nextModel
		}
	case "gemini":
		if nextAPIKey != "" {
			s.runtime.GeminiAPIKey = nextAPIKey
		}
		if nextModel != "" {
			s.runtime.GeminiModel = nextModel
		}
	case "claude":
		if nextAPIKey != "" {
			s.runtime.ClaudeAPIKey = nextAPIKey
		}
		if nextModel != "" {
			s.runtime.ClaudeModel = nextModel
		}
	}

	if err := s.applyProviderConfigLocked(nextProvider); err != nil {
		s.runtime = prevRuntime
		s.client = prevClient
		s.fallbackEnabled = prevFallback
		return ProviderStatus{}, err
	}
	if s.configStore != nil {
		if err := s.configStore.SaveProviderConfig(context.Background(), s.providerConfigSnapshotLocked()); err != nil {
			s.runtime = prevRuntime
			s.client = prevClient
			s.fallbackEnabled = prevFallback
			return ProviderStatus{}, errs.Internal(fmt.Sprintf("persist ai provider config: %v", err))
		}
	}
	return s.providerStatusLocked(), nil
}

func (s *Service) LoadPromptTemplates(ctx context.Context) error {
	if s.promptStore == nil {
		return nil
	}
	records, err := s.promptStore.LoadPromptTemplates(ctx)
	if err != nil {
		return errs.Internal(fmt.Sprintf("load ai prompt templates: %v", err))
	}
	s.promptRuntime.ReplaceAll(records)
	return nil
}

func (s *Service) ReloadPromptTemplates(ctx context.Context) ([]PromptTemplateConfig, error) {
	if err := s.LoadPromptTemplates(ctx); err != nil {
		return nil, err
	}
	return s.promptRuntime.List(), nil
}

func (s *Service) ListPromptTemplates() []PromptTemplateConfig {
	return s.promptRuntime.List()
}

func (s *Service) UpdatePromptTemplate(
	ctx context.Context,
	key string,
	req UpdatePromptTemplateRequest,
) (PromptTemplateConfig, error) {
	normalizedKey := normalizePromptKey(key)
	if !isSupportedPromptKey(normalizedKey) {
		return PromptTemplateConfig{}, errs.BadRequest("prompt key must be one of: " + supportedPromptKeysText())
	}
	if req.CustomPrompt == nil && req.OutputFormatPrompt == nil {
		return PromptTemplateConfig{}, errs.BadRequest("custom_prompt or output_format_prompt is required")
	}

	prevOverride, hadPrevOverride := s.promptRuntime.getOverride(normalizedKey)
	nextOverride := prevOverride
	if req.CustomPrompt != nil {
		nextOverride.CustomPrompt = strings.TrimSpace(*req.CustomPrompt)
	}
	if req.OutputFormatPrompt != nil {
		nextOverride.OutputFormatPrompt = strings.TrimSpace(*req.OutputFormatPrompt)
	}
	nextOverride.UpdatedAt = time.Now().UTC().Format(time.RFC3339Nano)

	cfg, ok := s.promptRuntime.setOverride(normalizedKey, nextOverride)
	if !ok {
		return PromptTemplateConfig{}, errs.BadRequest("prompt key must be one of: " + supportedPromptKeysText())
	}

	if s.promptStore != nil {
		if err := s.promptStore.SavePromptTemplate(ctx, PromptTemplateRecord{
			PromptKey:          normalizedKey,
			CustomPrompt:       cfg.CustomPrompt,
			OutputFormatPrompt: cfg.OutputFormatPrompt,
			UpdatedAt:          cfg.UpdatedAt,
		}); err != nil {
			if hadPrevOverride {
				s.promptRuntime.setOverride(normalizedKey, prevOverride)
			} else {
				s.promptRuntime.deleteOverride(normalizedKey)
			}
			return PromptTemplateConfig{}, errs.Internal(fmt.Sprintf("persist ai prompt template: %v", err))
		}
	}
	return cfg, nil
}

func (s *Service) providerConfigSnapshotLocked() ProviderConfigRecord {
	return ProviderConfigRecord{
		Provider:      strings.ToLower(strings.TrimSpace(s.runtime.Provider)),
		OpenAIBaseURL: strings.TrimSpace(s.runtime.OpenAIBaseURL),
		OpenAIAPIKey:  strings.TrimSpace(s.runtime.OpenAIAPIKey),
		OpenAIModel:   strings.TrimSpace(s.runtime.OpenAIModel),
		GeminiAPIKey:  strings.TrimSpace(s.runtime.GeminiAPIKey),
		GeminiModel:   strings.TrimSpace(s.runtime.GeminiModel),
		ClaudeAPIKey:  strings.TrimSpace(s.runtime.ClaudeAPIKey),
		ClaudeModel:   strings.TrimSpace(s.runtime.ClaudeModel),
	}
}

func (s *Service) providerStatusLocked() ProviderStatus {
	configuredProvider := strings.ToLower(strings.TrimSpace(s.runtime.Provider))
	hasAPIKey := false
	configuredModel := ""
	switch configuredProvider {
	case "openai":
		hasAPIKey = strings.TrimSpace(s.runtime.OpenAIAPIKey) != ""
		configuredModel = strings.TrimSpace(s.runtime.OpenAIModel)
	case "gemini":
		hasAPIKey = strings.TrimSpace(s.runtime.GeminiAPIKey) != ""
		configuredModel = strings.TrimSpace(s.runtime.GeminiModel)
	case "claude":
		hasAPIKey = strings.TrimSpace(s.runtime.ClaudeAPIKey) != ""
		configuredModel = strings.TrimSpace(s.runtime.ClaudeModel)
	case "mock":
		configuredModel = "mock-v1"
	}

	status := ProviderStatus{
		Provider:           s.client.ProviderName(),
		ConfiguredProvider: configuredProvider,
		Model:              s.client.ModelName(),
		ConfiguredModel:    configuredModel,
		Ready:              s.client.IsReady(),
		Fallback:           s.fallbackEnabled,
		HasAPIKey:          hasAPIKey,
	}
	if configuredProvider == "openai" {
		status.OpenAIBaseURL = strings.TrimSpace(s.runtime.OpenAIBaseURL)
	}
	return status
}

func (s *Service) defaultAgentProviderConfigLocked() (AgentProtocol, AgentProviderConfig, bool) {
	switch strings.ToLower(strings.TrimSpace(s.runtime.Provider)) {
	case "openai":
		cfg := AgentProviderConfig{
			BaseURL: strings.TrimSpace(s.runtime.OpenAIBaseURL),
			APIKey:  strings.TrimSpace(s.runtime.OpenAIAPIKey),
			Model:   strings.TrimSpace(s.runtime.OpenAIModel),
		}
		if cfg.APIKey == "" || cfg.Model == "" {
			return "", AgentProviderConfig{}, false
		}
		return AgentProtocolOpenAICompatible, cfg, true
	case "gemini":
		cfg := AgentProviderConfig{
			APIKey: strings.TrimSpace(s.runtime.GeminiAPIKey),
			Model:  strings.TrimSpace(s.runtime.GeminiModel),
		}
		if cfg.APIKey == "" || cfg.Model == "" {
			return "", AgentProviderConfig{}, false
		}
		return AgentProtocolGeminiNative, cfg, true
	case "claude":
		cfg := AgentProviderConfig{
			APIKey: strings.TrimSpace(s.runtime.ClaudeAPIKey),
			Model:  strings.TrimSpace(s.runtime.ClaudeModel),
		}
		if cfg.APIKey == "" || cfg.Model == "" {
			return "", AgentProviderConfig{}, false
		}
		return AgentProtocolClaudeNative, cfg, true
	default:
		return "", AgentProviderConfig{}, false
	}
}

func (s *Service) applyProviderConfigLocked(provider string) error {
	switch provider {
	case "mock":
		s.client = NewMockClient(s.runtime.MockLatency)
		s.fallbackEnabled = false
		s.bindPromptRuntimeLocked()
		return nil
	case "openai":
		client := NewOpenAIClient(OpenAIConfig{
			BaseURL: s.runtime.OpenAIBaseURL,
			APIKey:  s.runtime.OpenAIAPIKey,
			Model:   s.runtime.OpenAIModel,
			Timeout: s.runtime.AIHTTPTimeout,
		})
		if client.IsReady() {
			s.client = client
			s.fallbackEnabled = false
			s.bindPromptRuntimeLocked()
			return nil
		}
		if s.runtime.FallbackToMock {
			s.client = NewMockClient(s.runtime.MockLatency)
			s.fallbackEnabled = true
			s.bindPromptRuntimeLocked()
			return nil
		}
		return errs.BadRequest("openai provider is not ready, check api key/model")
	case "gemini":
		client := NewGeminiClient(GeminiConfig{
			APIKey:  s.runtime.GeminiAPIKey,
			Model:   s.runtime.GeminiModel,
			Timeout: s.runtime.AIHTTPTimeout,
		})
		if client.IsReady() {
			s.client = client
			s.fallbackEnabled = false
			s.bindPromptRuntimeLocked()
			return nil
		}
		if s.runtime.FallbackToMock {
			s.client = NewMockClient(s.runtime.MockLatency)
			s.fallbackEnabled = true
			s.bindPromptRuntimeLocked()
			return nil
		}
		return errs.BadRequest("gemini provider is not ready, check api key/model")
	case "claude":
		client := NewClaudeClient(ClaudeConfig{
			APIKey:  s.runtime.ClaudeAPIKey,
			Model:   s.runtime.ClaudeModel,
			Timeout: s.runtime.AIHTTPTimeout,
		})
		if client.IsReady() {
			s.client = client
			s.fallbackEnabled = false
			s.bindPromptRuntimeLocked()
			return nil
		}
		if s.runtime.FallbackToMock {
			s.client = NewMockClient(s.runtime.MockLatency)
			s.fallbackEnabled = true
			s.bindPromptRuntimeLocked()
			return nil
		}
		return errs.BadRequest("claude provider is not ready, check api key/model")
	default:
		return errs.BadRequest("provider must be one of: mock/openai/gemini/claude")
	}
}

func isSupportedProvider(provider string) bool {
	switch provider {
	case "mock", "openai", "gemini", "claude":
		return true
	default:
		return false
	}
}

func normalizeAbsoluteURL(raw string) (string, error) {
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return "", errs.BadRequest("openai_base_url must be a valid absolute URL")
	}
	return strings.TrimRight(strings.TrimSpace(raw), "/"), nil
}

func (s *Service) currentClient() Client {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.client
}

func (s *Service) Generate(ctx context.Context, req GenerateRequest, persist bool) ([]question.Question, error) {
	if strings.TrimSpace(req.Topic) == "" {
		return nil, errs.BadRequest("topic is required")
	}

	client := s.currentClient()
	items, err := client.GenerateQuestions(ctx, req)
	if err != nil {
		return nil, err
	}

	result := make([]question.Question, 0, len(items))
	for _, item := range items {
		if persist {
			q, createErr := s.questionService.Create(ctx, item)
			if createErr != nil {
				return nil, createErr
			}
			result = append(result, q)
			continue
		}
		q := question.Question{
			Title:        item.Title,
			Stem:         item.Stem,
			Type:         item.Type,
			Subject:      item.Subject,
			Source:       item.Source,
			Options:      item.Options,
			AnswerKey:    item.AnswerKey,
			Tags:         item.Tags,
			Difficulty:   item.Difficulty,
			MasteryLevel: item.MasteryLevel,
		}
		result = append(result, q)
	}

	return result, nil
}

func (s *Service) Grade(ctx context.Context, req GradeRequest) (GradeResult, error) {
	return s.currentClient().GradeAnswer(ctx, req)
}

func (s *Service) Learn(ctx context.Context, req LearnRequest) (LearnResult, error) {
	req.Mode = strings.TrimSpace(req.Mode)
	if req.Mode == "" {
		req.Mode = "long_term_learning"
	}
	req.Subject = strings.TrimSpace(req.Subject)
	if req.Subject == "" {
		req.Subject = "general"
	}
	req.Unit = strings.TrimSpace(req.Unit)
	req.CurrentStage = strings.TrimSpace(req.CurrentStage)
	req.CurrentStatus = strings.TrimSpace(req.CurrentStatus)
	req.FinalGoal = strings.TrimSpace(req.FinalGoal)
	req.StartDate = strings.TrimSpace(req.StartDate)
	req.EndDate = strings.TrimSpace(req.EndDate)
	req.Supplement = strings.TrimSpace(req.Supplement)
	req.UserID = strings.TrimSpace(req.UserID)
	req.ProfileSummary = strings.TrimSpace(req.ProfileSummary)
	if req.UserID == "" {
		req.UserID = "default"
	}
	req.Themes = normalizeStringList(req.Themes)
	req.Goals = normalizeStringList(req.Goals)
	if req.CurrentStatus == "" && req.CurrentStage != "" {
		req.CurrentStatus = req.CurrentStage
	}
	if req.CurrentStatus == "" {
		req.CurrentStatus = "pending"
	}
	if req.FinalGoal == "" && len(req.Goals) > 0 {
		req.FinalGoal = strings.Join(req.Goals, "; ")
	}
	if req.FinalGoal == "" {
		req.FinalGoal = "建立稳定学习节奏"
	}
	if len(req.Themes) == 0 {
		if req.Unit != "" {
			req.Themes = []string{req.Unit}
		} else {
			req.Themes = []string{req.Subject}
		}
	}
	now := time.Now().UTC()
	if req.StartDate == "" {
		req.StartDate = now.Format("2006-01-02")
	}
	if req.EndDate == "" {
		req.EndDate = now.AddDate(0, 3, 0).Format("2006-01-02")
	}

	return s.currentClient().BuildLearningPlan(ctx, req)
}

func (s *Service) OptimizeLearningPlan(ctx context.Context, req OptimizeLearnRequest) (OptimizeLearnResult, error) {
	req.Action = strings.ToLower(strings.TrimSpace(req.Action))
	if req.Action == "" {
		return OptimizeLearnResult{}, errs.BadRequest("action is required")
	}
	switch req.Action {
	case "postpone", "advance", "complete_early":
	default:
		return OptimizeLearnResult{}, errs.BadRequest("action must be one of: postpone/advance/complete_early")
	}
	req.Reason = strings.TrimSpace(req.Reason)
	req.Supplement = strings.TrimSpace(req.Supplement)
	if req.Action != "complete_early" && req.Days <= 0 {
		return OptimizeLearnResult{}, errs.BadRequest("days must be > 0 for postpone/advance")
	}
	return s.currentClient().OptimizeLearningPlan(ctx, req)
}

func (s *Service) Evaluate(ctx context.Context, req EvaluateRequest) (EvaluateResult, error) {
	if strings.TrimSpace(req.Mode) == "" {
		return EvaluateResult{}, errs.BadRequest("mode is required")
	}
	if req.Question.ID == "" && strings.TrimSpace(req.Context) == "" {
		return EvaluateResult{}, errs.BadRequest("question or context is required")
	}
	return s.currentClient().EvaluateLearning(ctx, req)
}

func (s *Service) Score(ctx context.Context, req ScoreRequest) (ScoreResult, error) {
	if strings.TrimSpace(req.Topic) == "" {
		return ScoreResult{}, errs.BadRequest("topic is required")
	}
	if req.Accuracy < 0 || req.Accuracy > 100 || req.Stability < 0 || req.Stability > 100 || req.Speed < 0 || req.Speed > 100 {
		return ScoreResult{}, errs.BadRequest("accuracy/stability/speed must be in [0, 100]")
	}

	res, err := s.currentClient().ScoreLearning(ctx, req)
	if err != nil {
		return ScoreResult{}, err
	}
	res.Score = math.Round(res.Score*10) / 10
	res.Grade = normalizeGrade(res.Score)
	if strings.TrimSpace(res.Grade) == "" {
		res.Grade = normalizeGrade(res.Score)
	}
	return res, nil
}

func normalizeGrade(score float64) string {
	switch {
	case score >= 90:
		return "A"
	case score >= 80:
		return "B"
	case score >= 70:
		return "C"
	case score >= 60:
		return "D"
	default:
		return "E"
	}
}

func normalizeStringList(items []string) []string {
	if len(items) == 0 {
		return []string{}
	}
	out := make([]string, 0, len(items))
	for _, item := range items {
		trimmed := strings.TrimSpace(item)
		if trimmed == "" {
			continue
		}
		out = append(out, trimmed)
	}
	return out
}

func (s *Service) SearchOnlineQuestions(ctx context.Context, topic, subject string, count int) ([]question.Question, error) {
	return s.Generate(ctx, GenerateRequest{
		Topic:      topic,
		Subject:    subject,
		Scope:      "network_search",
		Count:      count,
		Difficulty: 3,
	}, false)
}

func (s *Service) BuildRetestQuestions(ctx context.Context, subject, topic string, difficulty int) ([]question.Question, error) {
	items, err := s.Generate(ctx, GenerateRequest{
		Topic:      topic,
		Subject:    subject,
		Scope:      "retest",
		Count:      3,
		Difficulty: difficulty,
	}, false)
	if err != nil {
		return nil, fmt.Errorf("build retest questions: %w", err)
	}
	return items, nil
}
