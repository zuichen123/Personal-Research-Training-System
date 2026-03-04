package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"self-study-tool/internal/shared/errs"
)

type GeminiConfig struct {
	APIKey  string
	Model   string
	Timeout time.Duration
}

func NewGeminiClient(cfg GeminiConfig) Client {
	ready := strings.TrimSpace(cfg.APIKey) != "" && strings.TrimSpace(cfg.Model) != ""
	if !ready {
		return newRemoteLLMClient("gemini", cfg.Model, false, nil)
	}
	httpClient := &http.Client{Timeout: cfg.Timeout}
	if cfg.Timeout <= 0 {
		httpClient.Timeout = 20 * time.Second
	}
	modelPath := url.PathEscape(cfg.Model)
	endpoint := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", modelPath, url.QueryEscape(cfg.APIKey))

	invoker := func(ctx context.Context, input promptInvokeInput) (string, error) {
		parts := []map[string]any{
			{
				"text": "You are a JSON API backend. Return strictly valid JSON and nothing else.\n" + input.Prompt,
			},
		}
		for _, attachment := range input.Attachments {
			mimeType, base64Data, err := parseBase64DataURL(attachment.DataURL)
			if err != nil {
				continue
			}
			parts = append(parts, map[string]any{
				"inline_data": map[string]any{
					"mime_type": mimeType,
					"data":      base64Data,
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
		body, _ := json.Marshal(payload)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
		if err != nil {
			return "", err
		}
		req.Header.Set("Content-Type", "application/json")

		resp, err := httpClient.Do(req)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()
		respBody, _ := io.ReadAll(resp.Body)
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			return "", errs.Internal(fmt.Sprintf("gemini status %d: %s", resp.StatusCode, string(respBody)))
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
