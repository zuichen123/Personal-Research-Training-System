package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
)

func TestHandler_CompressSessionMessages(t *testing.T) {
	ctx := context.Background()
	svc, repo := newCompressTestService(t)
	_, sessionID := seedAgentSessionWithMessages(
		t,
		ctx,
		repo,
		AgentProtocolMock,
		AgentProviderConfig{Model: "mock"},
		AgentProviderConfig{},
		34,
	)

	handler := NewHandler(svc)
	router := chi.NewRouter()
	handler.RegisterRoutes(router)

	payload, _ := json.Marshal(map[string]any{
		"trigger": "manual",
	})
	req := httptest.NewRequest(
		http.MethodPost,
		"/ai/sessions/"+sessionID+"/compress",
		bytes.NewReader(payload),
	)
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("unexpected status code: %d, body=%s", rr.Code, rr.Body.String())
	}

	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response error: %v", err)
	}
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("expected response data object, got %#v", body)
	}
	if status := data["status"]; status != "compressed" {
		t.Fatalf("expected compressed status, got %#v", status)
	}
}
