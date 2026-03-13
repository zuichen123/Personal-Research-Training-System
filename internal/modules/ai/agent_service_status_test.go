package ai

import (
	"context"
	"testing"

	"prts/internal/shared/errs"
)

func TestComputeAgentStatus_Empty(t *testing.T) {
	status := computeAgentStatus("agent1", 0, []AgentMessage{})
	if status.AgentID != "agent1" {
		t.Errorf("expected agent1, got %s", status.AgentID)
	}
	if status.MessageCount != 0 {
		t.Errorf("expected 0 messages, got %d", status.MessageCount)
	}
}

func TestComputeAgentStatus_Accuracy(t *testing.T) {
	messages := []AgentMessage{
		{Role: "assistant", Content: `{"correct":true}`, CreatedAt: "2026-03-13T01:00:00Z"},
		{Role: "assistant", Content: `{"correct":false}`, CreatedAt: "2026-03-13T01:01:00Z"},
		{Role: "assistant", Content: `{"correct": true}`, CreatedAt: "2026-03-13T01:02:00Z"},
	}
	status := computeAgentStatus("agent1", 1, messages)
	expected := 2.0 / 3.0
	if status.StudentAccuracy != expected {
		t.Errorf("expected accuracy %.2f, got %.2f", expected, status.StudentAccuracy)
	}
}

func TestComputeAgentStatus_Mistakes(t *testing.T) {
	messages := []AgentMessage{
		{Role: "assistant", Content: "mistake: forgot to check discriminant", CreatedAt: "2026-03-13T01:00:00Z"},
		{Role: "assistant", Content: "error: sign error in formula", CreatedAt: "2026-03-13T01:01:00Z"},
	}
	status := computeAgentStatus("agent1", 1, messages)
	if len(status.CommonMistakes) == 0 {
		t.Error("expected mistakes to be extracted")
	}
}

func TestGetAgentStatus_NoAgent(t *testing.T) {
	store := &mockAgentStore{agents: map[string]Agent{}}
	svc := &Service{agentStore: store}
	_, err := svc.GetAgentStatus(context.Background(), "nonexistent", "")
	if err == nil {
		t.Error("expected error for nonexistent agent")
	}
}

type mockAgentStore struct {
	agents   map[string]Agent
	sessions int
	messages []AgentMessage
}

func (m *mockAgentStore) GetAgentByID(ctx context.Context, id string) (Agent, error) {
	if a, ok := m.agents[id]; ok {
		return a, nil
	}
	return Agent{}, errs.NotFound("agent not found")
}

func (m *mockAgentStore) GetActiveSessionsCount(ctx context.Context, agentID string) (int, error) {
	return m.sessions, nil
}

func (m *mockAgentStore) GetRecentMessages(ctx context.Context, agentID string, limit int) ([]AgentMessage, error) {
	return m.messages, nil
}

func (m *mockAgentStore) ListAgents(ctx context.Context) ([]Agent, error)                     { return nil, nil }
func (m *mockAgentStore) CreateAgent(ctx context.Context, item Agent) (Agent, error)          { return Agent{}, nil }
func (m *mockAgentStore) UpdateAgent(ctx context.Context, item Agent) (Agent, error)          { return Agent{}, nil }
func (m *mockAgentStore) DeleteAgent(ctx context.Context, id string) error                    { return nil }
func (m *mockAgentStore) ListSessions(ctx context.Context, agentID string, limit int, cursor string) ([]AgentSession, error) {
	return nil, nil
}
func (m *mockAgentStore) CreateSession(ctx context.Context, item AgentSession) (AgentSession, error) {
	return AgentSession{}, nil
}
func (m *mockAgentStore) GetSessionByID(ctx context.Context, sessionID string) (AgentSession, error) {
	return AgentSession{}, nil
}
func (m *mockAgentStore) DeleteSession(ctx context.Context, sessionID string) error { return nil }
func (m *mockAgentStore) ListMessages(ctx context.Context, sessionID string, limit int, beforeID string) ([]AgentMessage, error) {
	return nil, nil
}
func (m *mockAgentStore) ListMessagesByOffset(ctx context.Context, sessionID string, offset int, limit int) ([]AgentMessage, error) {
	return nil, nil
}
func (m *mockAgentStore) CountMessages(ctx context.Context, sessionID string) (int, error) { return 0, nil }
func (m *mockAgentStore) GetMessageByID(ctx context.Context, messageID string) (AgentMessage, error) {
	return AgentMessage{}, nil
}
func (m *mockAgentStore) CreateMessage(ctx context.Context, item AgentMessage) (AgentMessage, error) {
	return AgentMessage{}, nil
}
func (m *mockAgentStore) UpdateSessionSummary(ctx context.Context, sessionID string, summaryText string, summaryMeta map[string]any, summaryUpdatedAt string, summaryMessageCount int) error {
	return nil
}
func (m *mockAgentStore) ListArtifacts(ctx context.Context, sessionID, status string) ([]AgentArtifact, error) {
	return nil, nil
}
func (m *mockAgentStore) GetArtifactByID(ctx context.Context, artifactID string) (AgentArtifact, error) {
	return AgentArtifact{}, nil
}
func (m *mockAgentStore) CreateArtifact(ctx context.Context, item AgentArtifact) (AgentArtifact, error) {
	return AgentArtifact{}, nil
}
func (m *mockAgentStore) UpdateArtifactImportStatus(ctx context.Context, artifactID, status, importedAt string) error {
	return nil
}
