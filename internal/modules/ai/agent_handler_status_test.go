package ai

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"prts/internal/shared/errs"
)

func TestGetAgent_Success(t *testing.T) {
	store := &mockAgentStore{
		agents: map[string]Agent{
			"agent1": {
				ID:                 "agent1",
				Name:               "Test Agent",
				Protocol:           AgentProtocolClaudeNative,
				Primary:            AgentProviderConfig{Model: "claude-3-sonnet"},
				Enabled:            true,
				IntentCapabilities: []string{"chat"},
				CreatedAt:          "2026-03-13T00:00:00Z",
				UpdatedAt:          "2026-03-13T00:00:00Z",
			},
		},
	}
	svc := &Service{agentStore: store}
	handler := NewHandler(svc)

	r := chi.NewRouter()
	r.Get("/agents/{id}", handler.getAgent)

	req := httptest.NewRequest("GET", "/agents/agent1", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var agent Agent
	if err := json.NewDecoder(w.Body).Decode(&agent); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if agent.ID != "agent1" {
		t.Errorf("expected agent1, got %s", agent.ID)
	}
}

func TestGetAgent_NotFound(t *testing.T) {
	store := &mockAgentStoreWithError{}
	svc := &Service{agentStore: store}
	handler := NewHandler(svc)

	r := chi.NewRouter()
	r.Get("/agents/{id}", handler.getAgent)

	req := httptest.NewRequest("GET", "/agents/nonexistent", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestGetAgentStatus_Success(t *testing.T) {
	store := &mockAgentStore{
		agents: map[string]Agent{
			"agent1": {
				ID:                 "agent1",
				Name:               "Test Agent",
				Protocol:           AgentProtocolClaudeNative,
				Primary:            AgentProviderConfig{Model: "claude-3-sonnet"},
				Enabled:            true,
				IntentCapabilities: []string{"chat"},
				CreatedAt:          "2026-03-13T00:00:00Z",
				UpdatedAt:          "2026-03-13T00:00:00Z",
			},
		},
		sessions: 2,
		messages: []AgentMessage{
			{Role: "user", Content: "test", CreatedAt: "2026-03-13T01:00:00Z"},
		},
	}
	svc := &Service{agentStore: store}
	handler := NewHandler(svc)

	r := chi.NewRouter()
	r.Get("/agents/{id}/status", handler.getAgentStatus)

	req := httptest.NewRequest("GET", "/agents/agent1/status", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var status AgentStatus
	if err := json.NewDecoder(w.Body).Decode(&status); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if status.AgentID != "agent1" {
		t.Errorf("expected agent1, got %s", status.AgentID)
	}
	if status.ActiveSessions != 2 {
		t.Errorf("expected 2 sessions, got %d", status.ActiveSessions)
	}
}

func TestGetAgentStatus_NoSessions(t *testing.T) {
	store := &mockAgentStore{
		agents: map[string]Agent{
			"agent1": {ID: "agent1", Name: "Test Agent"},
		},
		sessions: 0,
	}
	svc := &Service{agentStore: store}
	handler := NewHandler(svc)

	r := chi.NewRouter()
	r.Get("/agents/{id}/status", handler.getAgentStatus)

	req := httptest.NewRequest("GET", "/agents/agent1/status", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

type mockAgentStoreWithError struct{}

func (m *mockAgentStoreWithError) GetAgentByID(ctx context.Context, id string) (Agent, error) {
	return Agent{}, errs.NotFound("agent not found")
}
func (m *mockAgentStoreWithError) GetActiveSessionsCount(ctx context.Context, agentID string) (int, error) {
	return 0, nil
}
func (m *mockAgentStoreWithError) GetRecentMessages(ctx context.Context, agentID string, limit int) ([]AgentMessage, error) {
	return nil, nil
}
func (m *mockAgentStoreWithError) ListAgents(ctx context.Context) ([]Agent, error) { return nil, nil }
func (m *mockAgentStoreWithError) CreateAgent(ctx context.Context, item Agent) (Agent, error) {
	return Agent{}, nil
}
func (m *mockAgentStoreWithError) UpdateAgent(ctx context.Context, item Agent) (Agent, error) {
	return Agent{}, nil
}
func (m *mockAgentStoreWithError) DeleteAgent(ctx context.Context, id string) error { return nil }
func (m *mockAgentStoreWithError) ListSessions(ctx context.Context, agentID string, limit int, cursor string) ([]AgentSession, error) {
	return nil, nil
}
func (m *mockAgentStoreWithError) CreateSession(ctx context.Context, item AgentSession) (AgentSession, error) {
	return AgentSession{}, nil
}
func (m *mockAgentStoreWithError) GetSessionByID(ctx context.Context, sessionID string) (AgentSession, error) {
	return AgentSession{}, nil
}
func (m *mockAgentStoreWithError) DeleteSession(ctx context.Context, sessionID string) error { return nil }
func (m *mockAgentStoreWithError) ListMessages(ctx context.Context, sessionID string, limit int, beforeID string) ([]AgentMessage, error) {
	return nil, nil
}
func (m *mockAgentStoreWithError) ListMessagesByOffset(ctx context.Context, sessionID string, offset int, limit int) ([]AgentMessage, error) {
	return nil, nil
}
func (m *mockAgentStoreWithError) CountMessages(ctx context.Context, sessionID string) (int, error) {
	return 0, nil
}
func (m *mockAgentStoreWithError) GetMessageByID(ctx context.Context, messageID string) (AgentMessage, error) {
	return AgentMessage{}, nil
}
func (m *mockAgentStoreWithError) CreateMessage(ctx context.Context, item AgentMessage) (AgentMessage, error) {
	return AgentMessage{}, nil
}
func (m *mockAgentStoreWithError) UpdateSessionSummary(ctx context.Context, sessionID string, summaryText string, summaryMeta map[string]any, summaryUpdatedAt string, summaryMessageCount int) error {
	return nil
}
func (m *mockAgentStoreWithError) ListArtifacts(ctx context.Context, sessionID, status string) ([]AgentArtifact, error) {
	return nil, nil
}
func (m *mockAgentStoreWithError) GetArtifactByID(ctx context.Context, artifactID string) (AgentArtifact, error) {
	return AgentArtifact{}, nil
}
func (m *mockAgentStoreWithError) CreateArtifact(ctx context.Context, item AgentArtifact) (AgentArtifact, error) {
	return AgentArtifact{}, nil
}
func (m *mockAgentStoreWithError) UpdateArtifactImportStatus(ctx context.Context, artifactID, status, importedAt string) error {
	return nil
}
