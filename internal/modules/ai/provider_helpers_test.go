package ai

import (
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (fn roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return fn(req)
}

func TestNewProviderHTTPClient_UsesDefaultTimeout(t *testing.T) {
	client := newProviderHTTPClient(0)
	if client.Timeout != defaultProviderTimeout {
		t.Fatalf("expected default timeout %s, got %s", defaultProviderTimeout, client.Timeout)
	}
}

func TestNewProviderHTTPClient_UsesExplicitTimeout(t *testing.T) {
	timeout := 5 * time.Second
	client := newProviderHTTPClient(timeout)
	if client.Timeout != timeout {
		t.Fatalf("expected timeout %s, got %s", timeout, client.Timeout)
	}
}

func TestPromptWithJSONBackendInstruction(t *testing.T) {
	got := promptWithJSONBackendInstruction("  hello  ")
	want := jsonBackendSystemPrompt + "\nhello"
	if got != want {
		t.Fatalf("unexpected prompt: %q", got)
	}
}

func TestDecodeMediaAttachments_IgnoresInvalidDataURL(t *testing.T) {
	items := decodeMediaAttachments([]ImageAttachment{
		{Name: "bad", DataURL: "invalid"},
		{Name: "good", DataURL: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA"},
	})
	if len(items) != 1 {
		t.Fatalf("expected 1 decoded attachment, got %d", len(items))
	}
	if items[0].MimeType != "image/png" {
		t.Fatalf("unexpected mime type: %s", items[0].MimeType)
	}
}

func TestDoProviderJSONRequest_Success(t *testing.T) {
	client := &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusOK,
			Body:       io.NopCloser(strings.NewReader(`{"ok":true}`)),
			Header:     make(http.Header),
		}, nil
	})}

	req, err := http.NewRequest(http.MethodGet, "https://example.test", nil)
	if err != nil {
		t.Fatalf("NewRequest error: %v", err)
	}

	body, err := doProviderJSONRequest(client, req, "demo")
	if err != nil {
		t.Fatalf("doProviderJSONRequest error: %v", err)
	}
	if string(body) != `{"ok":true}` {
		t.Fatalf("unexpected body: %s", string(body))
	}
}

func TestDoProviderJSONRequest_Non2xx(t *testing.T) {
	client := &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusBadGateway,
			Body:       io.NopCloser(strings.NewReader("boom")),
			Header:     make(http.Header),
		}, nil
	})}

	req, err := http.NewRequest(http.MethodGet, "https://example.test", nil)
	if err != nil {
		t.Fatalf("NewRequest error: %v", err)
	}

	_, err = doProviderJSONRequest(client, req, "demo")
	if err == nil {
		t.Fatal("expected error")
	}
	if !strings.Contains(err.Error(), "demo status 502: boom") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestProviderConfigReady(t *testing.T) {
	if providerConfigReady("", "model") {
		t.Fatal("expected empty api key to be not ready")
	}
	if providerConfigReady("key", "") {
		t.Fatal("expected empty model to be not ready")
	}
	if !providerConfigReady(" key ", " model ") {
		t.Fatal("expected trimmed values to be ready")
	}
}

func TestNewProviderJSONRequest(t *testing.T) {
	req, err := newProviderJSONRequest(t.Context(), "https://example.test", map[string]any{
		"topic": "math",
		"count": 3,
	})
	if err != nil {
		t.Fatalf("newProviderJSONRequest error: %v", err)
	}
	if req.Method != http.MethodPost {
		t.Fatalf("unexpected method: %s", req.Method)
	}
	if got := req.Header.Get("Content-Type"); got != "application/json" {
		t.Fatalf("unexpected content type: %s", got)
	}
	body, err := io.ReadAll(req.Body)
	if err != nil {
		t.Fatalf("ReadAll error: %v", err)
	}
	if string(body) != `{"count":3,"topic":"math"}` {
		t.Fatalf("unexpected body: %s", string(body))
	}
}

func TestDecodeAndCategorizeMediaAttachments(t *testing.T) {
	items := decodeAndCategorizeMediaAttachments([]ImageAttachment{
		{Name: "img", DataURL: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA"},
		{Name: "audio", DataURL: "data:audio/mpeg;base64,SUQzAwAAAAAA"},
	})
	if len(items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(items))
	}
	if items[0].Category != mediaAttachmentImage {
		t.Fatalf("expected first item to be image, got %s", items[0].Category)
	}
	if items[1].Category != mediaAttachmentAudio {
		t.Fatalf("expected second item to be audio, got %s", items[1].Category)
	}
	if count := countCategorizedMediaAttachments(items, mediaAttachmentAudio); count != 1 {
		t.Fatalf("expected audio count 1, got %d", count)
	}
}

func TestCategorizeMediaAttachment_Other(t *testing.T) {
	if got := categorizeMediaAttachment("text/plain"); got != mediaAttachmentOther {
		t.Fatalf("expected other category, got %s", got)
	}
}
