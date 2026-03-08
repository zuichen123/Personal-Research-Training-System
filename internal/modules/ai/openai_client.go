package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"self-study-tool/internal/shared/errs"
)

type OpenAIConfig struct {
	BaseURL string
	APIKey  string
	Model   string
	Timeout time.Duration
}

func NewOpenAIClient(cfg OpenAIConfig) Client {
	ready := providerConfigReady(cfg.APIKey, cfg.Model)
	if !ready {
		return newRemoteLLMClient("openai", cfg.Model, false, nil)
	}
	baseURL := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	if baseURL == "" {
		baseURL = "https://api.openai.com/v1"
	}
	httpClient := newProviderHTTPClient(cfg.Timeout)
	endpoint := baseURL + "/chat/completions"

	invoker := func(ctx context.Context, input promptInvokeInput) (string, error) {
		userContent := []map[string]any{
			{
				"type": "text",
				"text": input.Prompt,
			},
		}
		skippedAudio := 0
		for _, attachment := range decodeAndCategorizeMediaAttachments(input.Attachments) {
			switch attachment.Category {
			case mediaAttachmentImage:
				userContent = append(userContent, map[string]any{
					"type": "image_url",
					"image_url": map[string]any{
						"url": attachment.Raw.DataURL,
					},
				})
			case mediaAttachmentAudio:
				format := openAIAudioFormat(attachment.MimeType)
				if format == "" {
					skippedAudio++
					continue
				}
				userContent = append(userContent, map[string]any{
					"type": "input_audio",
					"input_audio": map[string]any{
						"format": format,
						"data":   attachment.Base64Data,
					},
				})
			}
		}
		if skippedAudio > 0 {
			userContent = append(userContent, map[string]any{
				"type": "text",
				"text": fmt.Sprintf("Skipped %d audio attachment(s) because the current OpenAI endpoint only supports wav/mp3 input_audio.", skippedAudio),
			})
		}
		payload := map[string]any{
			"model": cfg.Model,
			"messages": []map[string]any{
				{
					"role":    "system",
					"content": jsonBackendSystemPrompt,
				},
				{
					"role":    "user",
					"content": userContent,
				},
			},
			"temperature": 0.2,
		}
		req, err := newProviderJSONRequest(ctx, endpoint, payload)
		if err != nil {
			return "", err
		}
		req.Header.Set("Authorization", "Bearer "+cfg.APIKey)

		respBody, err := doProviderJSONRequest(httpClient, req, "openai")
		if err != nil {
			return "", err
		}

		var parsed struct {
			Choices []struct {
				Message struct {
					Content string `json:"content"`
				} `json:"message"`
			} `json:"choices"`
		}
		if err := json.Unmarshal(respBody, &parsed); err != nil {
			return "", err
		}
		if len(parsed.Choices) == 0 {
			return "", errs.Internal("openai empty choices")
		}
		return parsed.Choices[0].Message.Content, nil
	}

	return newRemoteLLMClient("openai", cfg.Model, true, invoker)
}

func openAIAudioFormat(mimeType string) string {
	switch strings.ToLower(strings.TrimSpace(mimeType)) {
	case "audio/wav", "audio/x-wav":
		return "wav"
	case "audio/mpeg", "audio/mp3":
		return "mp3"
	default:
		return ""
	}
}
