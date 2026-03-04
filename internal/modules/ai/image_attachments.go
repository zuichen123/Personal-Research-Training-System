package ai

import (
	"fmt"
	"strings"

	"self-study-tool/internal/shared/errs"
)

const maxMediaAttachments = 6

func normalizeImageAttachments(items []ImageAttachment) ([]ImageAttachment, error) {
	if len(items) == 0 {
		return nil, nil
	}
	if len(items) > maxMediaAttachments {
		return nil, errs.BadRequest(fmt.Sprintf("attachments exceeds limit: %d", maxMediaAttachments))
	}

	out := make([]ImageAttachment, 0, len(items))
	for _, item := range items {
		normalized := ImageAttachment{
			Name:     strings.TrimSpace(item.Name),
			Source:   strings.TrimSpace(item.Source),
			MimeType: strings.ToLower(strings.TrimSpace(item.MimeType)),
			DataURL:  strings.TrimSpace(item.DataURL),
		}
		if normalized.DataURL == "" {
			return nil, errs.BadRequest("attachments.data_url is required")
		}
		mimeType, _, err := parseBase64DataURL(normalized.DataURL)
		if err != nil {
			return nil, errs.BadRequest("attachments.data_url must be a valid base64 media data URL")
		}
		if normalized.MimeType == "" {
			normalized.MimeType = mimeType
		}
		if !isSupportedAttachmentMime(normalized.MimeType) {
			return nil, errs.BadRequest("attachments mime_type must be image/* or audio/*")
		}
		out = append(out, normalized)
	}
	return out, nil
}

func parseBase64DataURL(raw string) (mimeType, base64Data string, err error) {
	trimmed := strings.TrimSpace(raw)
	if !strings.HasPrefix(trimmed, "data:") {
		return "", "", fmt.Errorf("missing data: prefix")
	}
	parts := strings.SplitN(trimmed, ",", 2)
	if len(parts) != 2 {
		return "", "", fmt.Errorf("invalid data url payload")
	}
	meta := strings.TrimPrefix(parts[0], "data:")
	if !strings.Contains(strings.ToLower(meta), ";base64") {
		return "", "", fmt.Errorf("data url must be base64")
	}
	semi := strings.Index(meta, ";")
	if semi <= 0 {
		return "", "", fmt.Errorf("missing mime type")
	}
	mimeType = strings.ToLower(strings.TrimSpace(meta[:semi]))
	base64Data = strings.TrimSpace(parts[1])
	if mimeType == "" || base64Data == "" {
		return "", "", fmt.Errorf("empty mime type or payload")
	}
	if !isSupportedAttachmentMime(mimeType) {
		return "", "", fmt.Errorf("mime type must be image/* or audio/*")
	}
	return mimeType, base64Data, nil
}

func isSupportedAttachmentMime(mimeType string) bool {
	normalized := strings.ToLower(strings.TrimSpace(mimeType))
	return strings.HasPrefix(normalized, "image/") || strings.HasPrefix(normalized, "audio/")
}
