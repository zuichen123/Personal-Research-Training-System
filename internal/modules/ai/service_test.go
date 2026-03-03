package ai

import (
	"strings"
	"testing"
	"time"

	"self-study-tool/internal/modules/question"
)

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
