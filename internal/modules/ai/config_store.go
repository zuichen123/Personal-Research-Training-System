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

type PromptTemplateRecord struct {
	PromptKey          string
	CustomPrompt       string
	OutputFormatPrompt string
	UpdatedAt          string
}

type ProviderConfigStore interface {
	LoadProviderConfig(ctx context.Context) (ProviderConfigRecord, bool, error)
	SaveProviderConfig(ctx context.Context, cfg ProviderConfigRecord) error
}

type PromptTemplateStore interface {
	LoadPromptTemplates(ctx context.Context) ([]PromptTemplateRecord, error)
	SavePromptTemplate(ctx context.Context, cfg PromptTemplateRecord) error
}
