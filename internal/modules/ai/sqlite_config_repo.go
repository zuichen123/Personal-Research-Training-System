package ai

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"self-study-tool/internal/shared/errs"
)

type SQLiteProviderConfigRepository struct {
	db *sql.DB
}

func NewSQLiteProviderConfigRepository(db *sql.DB) *SQLiteProviderConfigRepository {
	return &SQLiteProviderConfigRepository{db: db}
}

func (r *SQLiteProviderConfigRepository) LoadProviderConfig(ctx context.Context) (ProviderConfigRecord, bool, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT provider, openai_base_url, openai_api_key, openai_model, gemini_api_key, gemini_model, claude_api_key, claude_model
		FROM ai_provider_config
		WHERE id = 1
	`)

	var out ProviderConfigRecord
	if err := row.Scan(
		&out.Provider,
		&out.OpenAIBaseURL,
		&out.OpenAIAPIKey,
		&out.OpenAIModel,
		&out.GeminiAPIKey,
		&out.GeminiModel,
		&out.ClaudeAPIKey,
		&out.ClaudeModel,
	); err != nil {
		if err == sql.ErrNoRows {
			return ProviderConfigRecord{}, false, nil
		}
		return ProviderConfigRecord{}, false, errs.Internal(fmt.Sprintf("failed to load ai provider config: %v", err))
	}
	out.Provider = strings.ToLower(strings.TrimSpace(out.Provider))
	return out, true, nil
}

func (r *SQLiteProviderConfigRepository) SaveProviderConfig(ctx context.Context, cfg ProviderConfigRecord) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO ai_provider_config (
			id, provider, openai_base_url, openai_api_key, openai_model, gemini_api_key, gemini_model, claude_api_key, claude_model, updated_at
		) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			provider = excluded.provider,
			openai_base_url = excluded.openai_base_url,
			openai_api_key = excluded.openai_api_key,
			openai_model = excluded.openai_model,
			gemini_api_key = excluded.gemini_api_key,
			gemini_model = excluded.gemini_model,
			claude_api_key = excluded.claude_api_key,
			claude_model = excluded.claude_model,
			updated_at = excluded.updated_at
	`,
		strings.ToLower(strings.TrimSpace(cfg.Provider)),
		strings.TrimSpace(cfg.OpenAIBaseURL),
		strings.TrimSpace(cfg.OpenAIAPIKey),
		strings.TrimSpace(cfg.OpenAIModel),
		strings.TrimSpace(cfg.GeminiAPIKey),
		strings.TrimSpace(cfg.GeminiModel),
		strings.TrimSpace(cfg.ClaudeAPIKey),
		strings.TrimSpace(cfg.ClaudeModel),
		time.Now().UTC().Format(time.RFC3339Nano),
	)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to save ai provider config: %v", err))
	}
	return nil
}

func (r *SQLiteProviderConfigRepository) LoadPromptTemplates(ctx context.Context) ([]PromptTemplateRecord, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT prompt_key, custom_prompt, output_format_prompt, updated_at
		FROM ai_prompt_templates
	`)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to load ai prompt templates: %v", err))
	}
	defer rows.Close()

	out := make([]PromptTemplateRecord, 0, len(promptTemplatePresetList))
	for rows.Next() {
		var item PromptTemplateRecord
		if err := rows.Scan(
			&item.PromptKey,
			&item.CustomPrompt,
			&item.OutputFormatPrompt,
			&item.UpdatedAt,
		); err != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan ai prompt templates: %v", err))
		}
		item.PromptKey = normalizePromptKey(item.PromptKey)
		out = append(out, item)
	}
	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to read ai prompt templates: %v", err))
	}
	return out, nil
}

func (r *SQLiteProviderConfigRepository) SavePromptTemplate(ctx context.Context, cfg PromptTemplateRecord) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO ai_prompt_templates (prompt_key, custom_prompt, output_format_prompt, updated_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(prompt_key) DO UPDATE SET
			custom_prompt = excluded.custom_prompt,
			output_format_prompt = excluded.output_format_prompt,
			updated_at = excluded.updated_at
	`,
		normalizePromptKey(cfg.PromptKey),
		strings.TrimSpace(cfg.CustomPrompt),
		strings.TrimSpace(cfg.OutputFormatPrompt),
		strings.TrimSpace(cfg.UpdatedAt),
	)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to save ai prompt template: %v", err))
	}
	return nil
}
