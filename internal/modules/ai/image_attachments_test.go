package ai

import "testing"

func TestNormalizeImageAttachments_Success(t *testing.T) {
	items, err := normalizeImageAttachments([]ImageAttachment{
		{
			Name:    "a.png",
			DataURL: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA",
		},
	})
	if err != nil {
		t.Fatalf("normalizeImageAttachments error: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected one item, got %d", len(items))
	}
	if items[0].MimeType != "image/png" {
		t.Fatalf("unexpected mime type: %s", items[0].MimeType)
	}
}

func TestNormalizeImageAttachments_AudioSuccess(t *testing.T) {
	items, err := normalizeImageAttachments([]ImageAttachment{
		{
			Name:    "speech.wav",
			DataURL: "data:audio/wav;base64,UklGRhQAAABXQVZF",
		},
	})
	if err != nil {
		t.Fatalf("normalizeImageAttachments error: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected one item, got %d", len(items))
	}
	if items[0].MimeType != "audio/wav" {
		t.Fatalf("unexpected mime type: %s", items[0].MimeType)
	}
}

func TestNormalizeImageAttachments_RejectsInvalidDataURL(t *testing.T) {
	_, err := normalizeImageAttachments([]ImageAttachment{
		{
			Name:    "a.png",
			DataURL: "invalid-data",
		},
	})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestNormalizeImageAttachments_RejectsUnsupportedMimeType(t *testing.T) {
	_, err := normalizeImageAttachments([]ImageAttachment{
		{
			Name:    "a.txt",
			DataURL: "data:text/plain;base64,SGVsbG8=",
		},
	})
	if err == nil {
		t.Fatal("expected error")
	}
}
