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

	"prts/internal/shared/errs"
)

const (
	jsonBackendSystemPrompt = "You are a JSON API backend. Return strictly valid JSON and nothing else."
	defaultProviderTimeout  = 20 * time.Second
)

type decodedMediaAttachment struct {
	Raw        ImageAttachment
	MimeType   string
	Base64Data string
}

type mediaAttachmentCategory string

const (
	mediaAttachmentImage mediaAttachmentCategory = "image"
	mediaAttachmentAudio mediaAttachmentCategory = "audio"
	mediaAttachmentOther mediaAttachmentCategory = "other"
)

type categorizedMediaAttachment struct {
	decodedMediaAttachment
	Category mediaAttachmentCategory
}

func newProviderHTTPClient(timeout time.Duration) *http.Client {
	if timeout <= 0 {
		timeout = defaultProviderTimeout
	}
	return &http.Client{Timeout: timeout}
}

func promptWithJSONBackendInstruction(prompt string) string {
	trimmed := strings.TrimSpace(prompt)
	if trimmed == "" {
		return jsonBackendSystemPrompt
	}
	return jsonBackendSystemPrompt + "\n" + trimmed
}

func providerConfigReady(apiKey, model string) bool {
	return strings.TrimSpace(apiKey) != "" && strings.TrimSpace(model) != ""
}

func newProviderJSONRequest(ctx context.Context, endpoint string, payload any) (*http.Request, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	return req, nil
}

func doProviderJSONRequest(httpClient *http.Client, req *http.Request, provider string) ([]byte, error) {
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, errs.Internal(fmt.Sprintf("%s status %d: %s", provider, resp.StatusCode, string(respBody)))
	}
	return respBody, nil
}

func categorizeMediaAttachment(mimeType string) mediaAttachmentCategory {
	switch {
	case strings.HasPrefix(mimeType, "image/"):
		return mediaAttachmentImage
	case strings.HasPrefix(mimeType, "audio/"):
		return mediaAttachmentAudio
	default:
		return mediaAttachmentOther
	}
}

func decodeAndCategorizeMediaAttachments(items []ImageAttachment) []categorizedMediaAttachment {
	decoded := decodeMediaAttachments(items)
	if len(decoded) == 0 {
		return nil
	}
	out := make([]categorizedMediaAttachment, 0, len(decoded))
	for _, item := range decoded {
		out = append(out, categorizedMediaAttachment{
			decodedMediaAttachment: item,
			Category:               categorizeMediaAttachment(item.MimeType),
		})
	}
	return out
}

func countCategorizedMediaAttachments(items []categorizedMediaAttachment, category mediaAttachmentCategory) int {
	count := 0
	for _, item := range items {
		if item.Category == category {
			count++
		}
	}
	return count
}

func decodeMediaAttachments(items []ImageAttachment) []decodedMediaAttachment {
	if len(items) == 0 {
		return nil
	}
	out := make([]decodedMediaAttachment, 0, len(items))
	for _, item := range items {
		mimeType, base64Data, err := parseBase64DataURL(item.DataURL)
		if err != nil {
			continue
		}
		out = append(out, decodedMediaAttachment{
			Raw:        item,
			MimeType:   mimeType,
			Base64Data: base64Data,
		})
	}
	return out
}
