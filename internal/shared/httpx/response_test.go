package httpx

import (
	"net/http/httptest"
	"strings"
	"testing"
)

type decodePayload struct {
	Name string `json:"name"`
}

func TestDecodeJSON_ValidSingleDocument(t *testing.T) {
	req := httptest.NewRequest("POST", "/test", strings.NewReader(`{"name":"ok"}`))

	var payload decodePayload
	if err := DecodeJSON(req, &payload); err != nil {
		t.Fatalf("DecodeJSON() error = %v", err)
	}
	if payload.Name != "ok" {
		t.Fatalf("expected name=ok, got %s", payload.Name)
	}
}

func TestDecodeJSON_TrailingDocumentRejected(t *testing.T) {
	req := httptest.NewRequest(
		"POST",
		"/test",
		strings.NewReader(`{"name":"first"}{"name":"second"}`),
	)

	var payload decodePayload
	if err := DecodeJSON(req, &payload); err == nil {
		t.Fatal("expected decode error, got nil")
	}
}

func TestDecodeJSON_UnknownFieldRejected(t *testing.T) {
	req := httptest.NewRequest(
		"POST",
		"/test",
		strings.NewReader(`{"name":"ok","extra":"field"}`),
	)

	var payload decodePayload
	if err := DecodeJSON(req, &payload); err == nil {
		t.Fatal("expected decode error, got nil")
	}
}
