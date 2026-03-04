package ai

import (
	"context"
	"strings"
	"testing"
	"time"

	"self-study-tool/internal/modules/question"
)

type testConfigStore struct {
	last          ProviderConfigRecord
	saved         bool
	promptRecords []PromptTemplateRecord
	savePromptErr error
}

func (s *testConfigStore) LoadProviderConfig(context.Context) (ProviderConfigRecord, bool, error) {
	return ProviderConfigRecord{}, false, nil
}

func (s *testConfigStore) SaveProviderConfig(_ context.Context, cfg ProviderConfigRecord) error {
	s.last = cfg
	s.saved = true
	return nil
}

func (s *testConfigStore) LoadPromptTemplates(context.Context) ([]PromptTemplateRecord, error) {
	out := make([]PromptTemplateRecord, 0, len(s.promptRecords))
	out = append(out, s.promptRecords...)
	return out, nil
}

func (s *testConfigStore) SavePromptTemplate(_ context.Context, cfg PromptTemplateRecord) error {
	if s.savePromptErr != nil {
		return s.savePromptErr
	}
	for i := range s.promptRecords {
		if s.promptRecords[i].PromptKey == cfg.PromptKey {
			s.promptRecords[i] = cfg
			return nil
		}
	}
	s.promptRecords = append(s.promptRecords, cfg)
	return nil
}

func newQuestionServiceForTest() *question.Service {
	return question.NewService(question.NewMemoryRepository())
}

func TestService_UpdateProviderConfig_RejectsInvalidURL(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "openai", FallbackToMock: true},
	)

	_, err := svc.UpdateProviderConfig(UpdateProviderConfigRequest{
		OpenAIBaseURL: "not-a-url",
	})
	if err == nil {
		t.Fatal("expected error for invalid URL")
	}
	if !strings.Contains(err.Error(), "openai_base_url") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestService_UpdateProviderConfig_RejectsInvalidProvider(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
	)

	_, err := svc.UpdateProviderConfig(UpdateProviderConfigRequest{
		Provider: "invalid_provider",
	})
	if err == nil {
		t.Fatal("expected error for invalid provider")
	}
	if !strings.Contains(err.Error(), "provider must be one of") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestService_UpdateProviderConfig_SwitchToOpenAIWithToken(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		true,
		RuntimeConfig{
			Provider:       "openai",
			FallbackToMock: true,
			MockLatency:    0,
			AIHTTPTimeout:  5 * time.Second,
			OpenAIBaseURL:  "https://api.openai.com/v1",
			OpenAIAPIKey:   "env-key",
			OpenAIModel:    "gpt-4o-mini",
		},
	)

	status, err := svc.UpdateProviderConfig(UpdateProviderConfigRequest{
		Provider:      "openai",
		APIKey:        "runtime-key",
		Model:         "gpt-4o-mini",
		OpenAIBaseURL: "https://example.com/v1/",
	})
	if err != nil {
		t.Fatalf("update config error: %v", err)
	}
	if status.Provider != "openai" {
		t.Fatalf("unexpected active provider: %s", status.Provider)
	}
	if status.ConfiguredProvider != "openai" {
		t.Fatalf("unexpected configured provider: %s", status.ConfiguredProvider)
	}
	if status.OpenAIBaseURL != "https://example.com/v1" {
		t.Fatalf("unexpected openai_base_url: %s", status.OpenAIBaseURL)
	}
	if status.Fallback {
		t.Fatal("expected fallback=false with valid runtime token")
	}
	if !status.HasAPIKey {
		t.Fatal("expected has_api_key=true")
	}
}

func TestService_UpdateProviderConfig_SwitchToGemini(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		true,
		RuntimeConfig{
			Provider:       "mock",
			FallbackToMock: true,
			MockLatency:    0,
			AIHTTPTimeout:  5 * time.Second,
			GeminiModel:    "gemini-1.5-flash",
		},
	)
	status, err := svc.UpdateProviderConfig(UpdateProviderConfigRequest{
		Provider: "gemini",
		APIKey:   "runtime-gemini-key",
		Model:    "gemini-2.0-flash",
	})
	if err != nil {
		t.Fatalf("switch to gemini error: %v", err)
	}
	if status.Provider != "gemini" {
		t.Fatalf("unexpected active provider: %s", status.Provider)
	}
	if status.ConfiguredProvider != "gemini" {
		t.Fatalf("unexpected configured provider: %s", status.ConfiguredProvider)
	}
	if !status.HasAPIKey {
		t.Fatal("expected has_api_key=true")
	}
	if status.Fallback {
		t.Fatal("expected fallback=false with runtime gemini token")
	}

}

func TestService_UpdateProviderConfig_ConfiguredModelWhenFallbackToMock(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		true,
		RuntimeConfig{
			Provider:       "mock",
			FallbackToMock: true,
			MockLatency:    0,
			AIHTTPTimeout:  5 * time.Second,
			OpenAIBaseURL:  "https://api.openai.com/v1",
			OpenAIModel:    "gpt-4o-mini",
		},
	)

	status, err := svc.UpdateProviderConfig(UpdateProviderConfigRequest{
		Provider: "openai",
		Model:    "gpt-4.1-mini",
	})
	if err != nil {
		t.Fatalf("switch to openai with fallback error: %v", err)
	}
	if status.ConfiguredProvider != "openai" {
		t.Fatalf("unexpected configured provider: %s", status.ConfiguredProvider)
	}
	if status.Provider != "mock" {
		t.Fatalf("unexpected active provider: %s", status.Provider)
	}
	if status.Model != "mock-v1" {
		t.Fatalf("unexpected active model: %s", status.Model)
	}
	if status.ConfiguredModel != "gpt-4.1-mini" {
		t.Fatalf("unexpected configured model: %s", status.ConfiguredModel)
	}
	if !status.Fallback {
		t.Fatal("expected fallback=true when openai is not ready")
	}
}

func TestService_UpdateProviderConfig_PersistsToStore(t *testing.T) {
	store := &testConfigStore{}
	svc := NewServiceWithStore(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{
			Provider:       "mock",
			FallbackToMock: true,
			MockLatency:    0,
			AIHTTPTimeout:  5 * time.Second,
			OpenAIBaseURL:  "https://api.openai.com/v1",
			OpenAIModel:    "gpt-4o-mini",
		},
		store,
	)

	_, err := svc.UpdateProviderConfig(UpdateProviderConfigRequest{
		Provider:      "openai",
		APIKey:        "runtime-openai-key",
		Model:         "gpt-4.1-mini",
		OpenAIBaseURL: "https://example.com/v1",
	})
	if err != nil {
		t.Fatalf("update config error: %v", err)
	}
	if !store.saved {
		t.Fatal("expected provider config to be persisted")
	}
	if store.last.Provider != "openai" {
		t.Fatalf("unexpected stored provider: %s", store.last.Provider)
	}
	if store.last.OpenAIBaseURL != "https://example.com/v1" {
		t.Fatalf("unexpected stored openai base url: %s", store.last.OpenAIBaseURL)
	}
	if store.last.OpenAIAPIKey != "runtime-openai-key" {
		t.Fatalf("unexpected stored openai api key: %s", store.last.OpenAIAPIKey)
	}
}

func TestService_OptimizeLearningPlan_RejectsInvalidAction(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
	)

	_, err := svc.OptimizeLearningPlan(context.Background(), OptimizeLearnRequest{
		Action: "invalid",
		Days:   2,
	})
	if err == nil {
		t.Fatal("expected error for invalid action")
	}
	if !strings.Contains(err.Error(), "action must be one of") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestService_OptimizeLearningPlan_PostponeRequiresDays(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
	)

	_, err := svc.OptimizeLearningPlan(context.Background(), OptimizeLearnRequest{
		Action: "postpone",
		Days:   0,
	})
	if err == nil {
		t.Fatal("expected error for missing days")
	}
	if !strings.Contains(err.Error(), "days must be > 0") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestService_OptimizeLearningPlan_Success(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
	)

	result, err := svc.OptimizeLearningPlan(context.Background(), OptimizeLearnRequest{
		Action: "postpone",
		Days:   3,
		Plan: LearnResult{
			PlanStartDate: "2026-03-01",
			PlanEndDate:   "2026-06-01",
		},
	})
	if err != nil {
		t.Fatalf("optimize learning plan error: %v", err)
	}
	if result.UpdatedPlan.PlanStartDate != "2026-03-04" {
		t.Fatalf("unexpected shifted start date: %s", result.UpdatedPlan.PlanStartDate)
	}
	if result.UpdatedPlan.PlanEndDate != "2026-06-04" {
		t.Fatalf("unexpected shifted end date: %s", result.UpdatedPlan.PlanEndDate)
	}
}

func TestService_LoadPromptTemplates_AppliesOverrides(t *testing.T) {
	store := &testConfigStore{
		promptRecords: []PromptTemplateRecord{
			{
				PromptKey:          PromptKeyGenerateQuestions,
				CustomPrompt:       "custom generate",
				OutputFormatPrompt: "custom output",
				UpdatedAt:          "2026-03-04T00:00:00Z",
			},
		},
	}
	svc := NewServiceWithStore(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
		store,
	)

	if err := svc.LoadPromptTemplates(context.Background()); err != nil {
		t.Fatalf("load prompt templates error: %v", err)
	}
	list := svc.ListPromptTemplates()
	if len(list) == 0 {
		t.Fatal("expected prompt template list")
	}
	var found *PromptTemplateConfig
	for i := range list {
		if list[i].Key == PromptKeyGenerateQuestions {
			found = &list[i]
			break
		}
	}
	if found == nil {
		t.Fatal("expected generate_questions prompt config")
	}
	if found.CustomPrompt != "custom generate" {
		t.Fatalf("unexpected custom prompt: %s", found.CustomPrompt)
	}
	if found.EffectivePrompt != "custom generate" {
		t.Fatalf("unexpected effective prompt: %s", found.EffectivePrompt)
	}
	if found.EffectiveOutputFormatPrompt != "custom output" {
		t.Fatalf("unexpected effective output prompt: %s", found.EffectiveOutputFormatPrompt)
	}
}

func TestService_UpdatePromptTemplate_PersistsAndHotUpdates(t *testing.T) {
	store := &testConfigStore{}
	svc := NewServiceWithStore(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
		store,
	)

	custom := "new custom prompt"
	output := "new output prompt"
	updated, err := svc.UpdatePromptTemplate(context.Background(), PromptKeyScoreLearning, UpdatePromptTemplateRequest{
		CustomPrompt:       &custom,
		OutputFormatPrompt: &output,
	})
	if err != nil {
		t.Fatalf("update prompt template error: %v", err)
	}
	if updated.EffectivePrompt != custom {
		t.Fatalf("unexpected effective prompt: %s", updated.EffectivePrompt)
	}
	if updated.EffectiveOutputFormatPrompt != output {
		t.Fatalf("unexpected effective output prompt: %s", updated.EffectiveOutputFormatPrompt)
	}
	if len(store.promptRecords) != 1 {
		t.Fatalf("expected one saved prompt record, got %d", len(store.promptRecords))
	}
	if store.promptRecords[0].PromptKey != PromptKeyScoreLearning {
		t.Fatalf("unexpected prompt key: %s", store.promptRecords[0].PromptKey)
	}
}

func TestService_UpdatePromptTemplate_RollsBackOnPersistError(t *testing.T) {
	store := &testConfigStore{
		savePromptErr: context.DeadlineExceeded,
	}
	svc := NewServiceWithStore(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
		store,
	)

	custom := "should fail"
	_, err := svc.UpdatePromptTemplate(context.Background(), PromptKeyGradeAnswer, UpdatePromptTemplateRequest{
		CustomPrompt: &custom,
	})
	if err == nil {
		t.Fatal("expected persist error")
	}

	cfg, ok := svc.promptRuntime.Get(PromptKeyGradeAnswer)
	if !ok {
		t.Fatal("expected grade prompt config")
	}
	if cfg.CustomPrompt != "" {
		t.Fatalf("expected rollback to no custom prompt, got: %s", cfg.CustomPrompt)
	}
}

func TestService_Learn_DefaultsAndFallbacks(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
	)

	result, err := svc.Learn(context.Background(), LearnRequest{
		Subject:      "math",
		Goals:        []string{"提升代数能力"},
		CurrentStage: "in_progress",
	})
	if err != nil {
		t.Fatalf("Learn() error = %v", err)
	}
	if result.CurrentStatus != "in_progress" {
		t.Fatalf("expected current_status=in_progress, got %s", result.CurrentStatus)
	}
	if strings.TrimSpace(result.FinalGoal) == "" {
		t.Fatal("expected final_goal fallback to be populated")
	}
	if strings.TrimSpace(result.PlanStartDate) == "" || strings.TrimSpace(result.PlanEndDate) == "" {
		t.Fatalf("expected non-empty plan dates, got start=%s end=%s", result.PlanStartDate, result.PlanEndDate)
	}
	if len(result.Themes) == 0 {
		t.Fatal("expected fallback themes")
	}
}

func TestService_Grade_MockContainsAnalysisFields(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
	)

	result, err := svc.Grade(context.Background(), GradeRequest{
		Question: question.Question{
			Title:     "函数题",
			Stem:      "解释单调递增",
			AnswerKey: []string{"单调", "区间"},
		},
		UserAnswer: []string{"只写了单调"},
	})
	if err != nil {
		t.Fatalf("Grade() error = %v", err)
	}
	if strings.TrimSpace(result.Analysis) == "" {
		t.Fatal("expected analysis field to be populated")
	}
	if strings.TrimSpace(result.Explanation) == "" {
		t.Fatal("expected explanation field to be populated")
	}
}
