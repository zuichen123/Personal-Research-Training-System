package ai

import (
	"context"
	"strings"
	"testing"
	"time"

	"self-study-tool/internal/modules/question"
)

type testConfigStore struct {
	last  ProviderConfigRecord
	saved bool
}

func (s *testConfigStore) LoadProviderConfig(context.Context) (ProviderConfigRecord, bool, error) {
	return ProviderConfigRecord{}, false, nil
}

func (s *testConfigStore) SaveProviderConfig(_ context.Context, cfg ProviderConfigRecord) error {
	s.last = cfg
	s.saved = true
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
