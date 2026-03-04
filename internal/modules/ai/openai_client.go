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

type OpenAIConfig struct {
	BaseURL string
	APIKey  string
	Model   string
	Timeout time.Duration
}

func NewOpenAIClient(cfg OpenAIConfig) Client {
	ready := strings.TrimSpace(cfg.APIKey) != "" && strings.TrimSpace(cfg.Model) != ""
	if !ready {
		return newRemoteLLMClient("openai", cfg.Model, false, nil)
	}
	baseURL := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	if baseURL == "" {
		baseURL = "https://api.openai.com/v1"
	}
	httpClient := &http.Client{Timeout: cfg.Timeout}
	if cfg.Timeout <= 0 {
		httpClient.Timeout = 20 * time.Second
	}
	endpoint := baseURL + "/chat/completions"

	invoker := func(ctx context.Context, input promptInvokeInput) (string, error) {
		userContent := []map[string]any{
			{
				"type": "text",
				"text": input.Prompt,
			},
		}
		skippedAudio := 0
		for _, attachment := range input.Attachments {
			mimeType, base64Data, err := parseBase64DataURL(attachment.DataURL)
			if err != nil {
				continue
			}
			switch {
			case strings.HasPrefix(mimeType, "image/"):
				userContent = append(userContent, map[string]any{
					"type": "image_url",
					"image_url": map[string]any{
						"url": attachment.DataURL,
					},
				})
			case strings.HasPrefix(mimeType, "audio/"):
				format := openAIAudioFormat(mimeType)
				if format == "" {
					skippedAudio++
					continue
				}
				userContent = append(userContent, map[string]any{
					"type": "input_audio",
					"input_audio": map[string]any{
						"format": format,
						"data":   base64Data,
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
					"content": "You are a JSON API backend. Return strictly valid JSON and nothing else.",
				},
				{
					"role":    "user",
					"content": userContent,
				},
			},
			"temperature": 0.2,
		}
		body, _ := json.Marshal(payload)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
		if err != nil {
			return "", err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+cfg.APIKey)

		resp, err := httpClient.Do(req)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()
		respBody, _ := io.ReadAll(resp.Body)
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			return "", errs.Internal(fmt.Sprintf("openai status %d: %s", resp.StatusCode, string(respBody)))
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
