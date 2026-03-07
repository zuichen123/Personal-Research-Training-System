package ai

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	sqlitestore "self-study-tool/internal/platform/storage/sqlite"
)

func TestSQLiteAgentRepository_SessionSummaryFields(t *testing.T) {
	ctx := context.Background()
	repo := newAgentRepoForTest(t)

	agentID := uuid.NewString()
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := repo.CreateAgent(ctx, Agent{
		ID:                 agentID,
		Name:               "repo-agent",
		Protocol:           AgentProtocolMock,
		Primary:            AgentProviderConfig{Model: "mock"},
		Fallback:           AgentProviderConfig{},
		IntentCapabilities: []string{"chat"},
		Enabled:            true,
		CreatedAt:          now,
		UpdatedAt:          now,
	})
	if err != nil {
		t.Fatalf("CreateAgent() error = %v", err)
	}

	sessionID := uuid.NewString()
	_, err = repo.CreateSession(ctx, AgentSession{
		ID:        sessionID,
		AgentID:   agentID,
		Title:     "repo-session",
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		t.Fatalf("CreateSession() error = %v", err)
	}

	updatedAt := time.Now().UTC().Format(time.RFC3339Nano)
	err = repo.UpdateSessionSummary(
		ctx,
		sessionID,
		"summary-content",
		map[string]any{"last_auto_compress_at": updatedAt},
		updatedAt,
		8,
	)
	if err != nil {
		t.Fatalf("UpdateSessionSummary() error = %v", err)
	}

	session, err := repo.GetSessionByID(ctx, sessionID)
	if err != nil {
		t.Fatalf("GetSessionByID() error = %v", err)
	}
	if session.ContextSummaryText != "summary-content" {
		t.Fatalf("unexpected summary text: %s", session.ContextSummaryText)
	}
	if session.ContextSummaryMessageCount != 8 {
		t.Fatalf("unexpected summary message count: %d", session.ContextSummaryMessageCount)
	}
	if session.ContextSummaryUpdatedAt == "" {
		t.Fatal("expected summary updated at")
	}

	sessions, err := repo.ListSessions(ctx, agentID, 20, "")
	if err != nil {
		t.Fatalf("ListSessions() error = %v", err)
	}
	if len(sessions) != 1 {
		t.Fatalf("expected 1 session, got %d", len(sessions))
	}
	if sessions[0].SummaryMessageCount != 8 {
		t.Fatalf("unexpected listed summary message count: %d", sessions[0].SummaryMessageCount)
	}
}

func TestSQLiteAgentRepository_ListMessagesByOffset(t *testing.T) {
	ctx := context.Background()
	repo := newAgentRepoForTest(t)

	agentID, sessionID := seedAgentSessionWithMessages(
		t,
		ctx,
		repo,
		AgentProtocolMock,
		AgentProviderConfig{Model: "mock"},
		AgentProviderConfig{},
		12,
	)
	if agentID == "" || sessionID == "" {
		t.Fatal("seed should return non-empty ids")
	}

	total, err := repo.CountMessages(ctx, sessionID)
	if err != nil {
		t.Fatalf("CountMessages() error = %v", err)
	}
	if total != 12 {
		t.Fatalf("unexpected count: %d", total)
	}

	items, err := repo.ListMessagesByOffset(ctx, sessionID, 2, 5)
	if err != nil {
		t.Fatalf("ListMessagesByOffset() error = %v", err)
	}
	if len(items) != 5 {
		t.Fatalf("expected 5 items, got %d", len(items))
	}
}

func TestSQLiteAgentRepository_ListMessages_NullJSONDoesNotCreatePending(t *testing.T) {
	ctx := context.Background()
	repo := newAgentRepoForTest(t)

	_, sessionID := seedAgentSessionWithMessages(
		t,
		ctx,
		repo,
		AgentProtocolMock,
		AgentProviderConfig{Model: "mock"},
		AgentProviderConfig{},
		1,
	)

	items, err := repo.ListMessages(ctx, sessionID, 10, "")
	if err != nil {
		t.Fatalf("ListMessages() error = %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 message, got %d", len(items))
	}

	if items[0].Intent != nil {
		t.Fatalf("expected intent to be nil for null intent_json, got %+v", *items[0].Intent)
	}
	if items[0].PendingConfirmation != nil {
		t.Fatalf(
			"expected pending confirmation to be nil for null pending_confirmation_json, got %+v",
			*items[0].PendingConfirmation,
		)
	}
}

func TestSQLiteAgentRepository_GetAgentByID_AppendsManageAppCapability(t *testing.T) {
	ctx := context.Background()
	repo := newAgentRepoForTest(t)

	agentID := uuid.NewString()
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := repo.CreateAgent(ctx, Agent{
		ID:                 agentID,
		Name:               "legacy-cap-agent",
		Protocol:           AgentProtocolMock,
		Primary:            AgentProviderConfig{Model: "mock"},
		Fallback:           AgentProviderConfig{},
		IntentCapabilities: []string{"chat", "generate_questions", "build_plan"},
		Enabled:            true,
		CreatedAt:          now,
		UpdatedAt:          now,
	})
	if err != nil {
		t.Fatalf("CreateAgent() error = %v", err)
	}

	item, err := repo.GetAgentByID(ctx, agentID)
	if err != nil {
		t.Fatalf("GetAgentByID() error = %v", err)
	}
	if !containsCapability(item.IntentCapabilities, "manage_app") {
		t.Fatalf("expected capabilities to include manage_app, got %v", item.IntentCapabilities)
	}
}

func newAgentRepoForTest(t *testing.T) *SQLiteAgentRepository {
	t.Helper()

	dbPath := filepath.Join(t.TempDir(), "repo_test.db")
	db, err := sqlitestore.Open(dbPath)
	if err != nil {
		t.Fatalf("sqlite open error: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if err := sqlitestore.Migrate(context.Background(), db); err != nil {
		t.Fatalf("sqlite migrate error: %v", err)
	}
	return NewSQLiteAgentRepository(db)
}
