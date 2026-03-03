package ai

import "context"

type ProviderConfigRecord struct {
	Provider      string
	OpenAIBaseURL string
	OpenAIAPIKey  string
	OpenAIModel   string
	GeminiAPIKey  string
	GeminiModel   string
	ClaudeAPIKey  string
	ClaudeModel   string
}

type ProviderConfigStore interface {
	LoadProviderConfig(ctx context.Context) (ProviderConfigRecord, bool, error)
	SaveProviderConfig(ctx context.Context, cfg ProviderConfigRecord) error
}
