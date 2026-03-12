package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"time"

	"prts/internal/shared/errs"
)

type GeminiConfig struct {
	APIKey  string
	Model   string
	Timeout time.Duration
}

func NewGeminiClient(cfg GeminiConfig) Client {
	ready := providerConfigReady(cfg.APIKey, cfg.Model)
	if !ready {
		return newRemoteLLMClient("gemini", cfg.Model, false, nil)
	}
	httpClient := newProviderHTTPClient(cfg.Timeout)
	modelPath := url.PathEscape(cfg.Model)
	endpoint := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", modelPath, url.QueryEscape(cfg.APIKey))

	invoker := func(ctx context.Context, input promptInvokeInput) (string, error) {
		parts := []map[string]any{
			{
				"text": promptWithJSONBackendInstruction(input.Prompt),
			},
		}
		for _, attachment := range decodeMediaAttachments(input.Attachments) {
			parts = append(parts, map[string]any{
				"inline_data": map[string]any{
					"mime_type": attachment.MimeType,
					"data":      attachment.Base64Data,
				},
			})
		}
		payload := map[string]any{
			"contents": []map[string]any{
				{
					"parts": parts,
				},
			},
			"generationConfig": map[string]any{
				"temperature": 0.2,
			},
		}
		req, err := newProviderJSONRequest(ctx, endpoint, payload)
		if err != nil {
			return "", err
		}

		respBody, err := doProviderJSONRequest(httpClient, req, "gemini")
		if err != nil {
			return "", err
		}
		var parsed struct {
			Candidates []struct {
				Content struct {
					Parts []struct {
						Text string `json:"text"`
					} `json:"parts"`
				} `json:"content"`
			} `json:"candidates"`
		}
		if err := json.Unmarshal(respBody, &parsed); err != nil {
			return "", err
		}
		if len(parsed.Candidates) == 0 || len(parsed.Candidates[0].Content.Parts) == 0 {
			return "", errs.Internal("gemini empty candidates")
		}
		return parsed.Candidates[0].Content.Parts[0].Text, nil
	}

	return newRemoteLLMClient("gemini", cfg.Model, true, invoker)
}
