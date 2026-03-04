package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"self-study-tool/internal/shared/errs"
)

type ClaudeConfig struct {
	APIKey  string
	Model   string
	Timeout time.Duration
}

func NewClaudeClient(cfg ClaudeConfig) Client {
	ready := strings.TrimSpace(cfg.APIKey) != "" && strings.TrimSpace(cfg.Model) != ""
	if !ready {
		return newRemoteLLMClient("claude", cfg.Model, false, nil)
	}
	httpClient := &http.Client{Timeout: cfg.Timeout}
	if cfg.Timeout <= 0 {
		httpClient.Timeout = 20 * time.Second
	}
	endpoint := "https://api.anthropic.com/v1/messages"

	invoker := func(ctx context.Context, input promptInvokeInput) (string, error) {
		contentBlocks := []map[string]any{
			{
				"type": "text",
				"text": "You are a JSON API backend. Return strictly valid JSON and nothing else.\n" + input.Prompt,
			},
		}
		audioCount := 0
		for _, attachment := range input.Attachments {
			mimeType, base64Data, err := parseBase64DataURL(attachment.DataURL)
			if err != nil {
				continue
			}
			if strings.HasPrefix(mimeType, "audio/") {
				audioCount++
				continue
			}
			contentBlocks = append(contentBlocks, map[string]any{
				"type": "image",
				"source": map[string]any{
					"type":       "base64",
					"media_type": mimeType,
					"data":       base64Data,
				},
			})
		}
		if audioCount > 0 {
			contentBlocks = append(contentBlocks, map[string]any{
				"type": "text",
				"text": fmt.Sprintf(
					"User attached %d audio file(s). This Claude integration currently sends image attachments only.",
					audioCount,
				),
			})
		}
		payload := map[string]any{
			"model":      cfg.Model,
			"max_tokens": 2048,
			"messages": []map[string]any{
				{
					"role":    "user",
					"content": contentBlocks,
				},
			},
		}
		body, _ := json.Marshal(payload)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
		if err != nil {
			return "", err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("x-api-key", cfg.APIKey)
		req.Header.Set("anthropic-version", "2023-06-01")

		resp, err := httpClient.Do(req)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()
		respBody, _ := io.ReadAll(resp.Body)
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			return "", errs.Internal(fmt.Sprintf("claude status %d: %s", resp.StatusCode, string(respBody)))
		}
		var parsed struct {
			Content []struct {
				Type string `json:"type"`
				Text string `json:"text"`
			} `json:"content"`
		}
		if err := json.Unmarshal(respBody, &parsed); err != nil {
			return "", err
		}
		for _, block := range parsed.Content {
			if strings.EqualFold(block.Type, "text") && strings.TrimSpace(block.Text) != "" {
				return block.Text, nil
			}
		}
		return "", errs.Internal("claude empty content")
	}

	return newRemoteLLMClient("claude", cfg.Model, true, invoker)
}
