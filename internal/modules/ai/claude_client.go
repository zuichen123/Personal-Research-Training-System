package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"prts/internal/shared/errs"
)

type ClaudeConfig struct {
	APIKey  string
	Model   string
	Timeout time.Duration
}

func NewClaudeClient(cfg ClaudeConfig) Client {
	ready := providerConfigReady(cfg.APIKey, cfg.Model)
	if !ready {
		return newRemoteLLMClient("claude", cfg.Model, false, nil)
	}
	httpClient := newProviderHTTPClient(cfg.Timeout)
	endpoint := "https://api.anthropic.com/v1/messages"

	invoker := func(ctx context.Context, input promptInvokeInput) (string, error) {
		contentBlocks := []map[string]any{
			{
				"type": "text",
				"text": promptWithJSONBackendInstruction(input.Prompt),
			},
		}
		attachments := decodeAndCategorizeMediaAttachments(input.Attachments)
		audioCount := countCategorizedMediaAttachments(attachments, mediaAttachmentAudio)
		for _, attachment := range attachments {
			if attachment.Category == mediaAttachmentAudio {
				continue
			}
			contentBlocks = append(contentBlocks, map[string]any{
				"type": "image",
				"source": map[string]any{
					"type":       "base64",
					"media_type": attachment.MimeType,
					"data":       attachment.Base64Data,
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
		req, err := newProviderJSONRequest(ctx, endpoint, payload)
		if err != nil {
			return "", err
		}
		req.Header.Set("x-api-key", cfg.APIKey)
		req.Header.Set("anthropic-version", "2023-06-01")

		respBody, err := doProviderJSONRequest(httpClient, req, "claude")
		if err != nil {
			return "", err
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
