package ai

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	"self-study-tool/internal/modules/question"
	sqlitestore "self-study-tool/internal/platform/storage/sqlite"
)

func TestService_CompressSessionMessages_ManualSuccess(t *testing.T) {
	ctx := context.Background()
	svc, repo := newCompressTestService(t)
	agentID, sessionID := seedAgentSessionWithMessages(
		t,
		ctx,
		repo,
		AgentProtocolMock,
		AgentProviderConfig{Model: "mock"},
		AgentProviderConfig{},
		35,
	)

	result, err := svc.CompressSessionMessages(ctx, sessionID, CompressSessionRequest{
		Trigger: "manual",
	})
	if err != nil {
		t.Fatalf("CompressSessionMessages() error = %v", err)
	}
	if result.Status != "compressed" {
		t.Fatalf("expected compressed status, got %s", result.Status)
	}
	if result.SummarizedCount <= 0 {
		t.Fatalf("expected summarized_count > 0, got %d", result.SummarizedCount)
	}

	session, err := repo.GetSessionByID(ctx, sessionID)
	if err != nil {
		t.Fatalf("GetSessionByID() error = %v", err)
	}
	if session.AgentID != agentID {
		t.Fatalf("unexpected agent id %s", session.AgentID)
	}
	if session.ContextSummaryMessageCount != 15 {
		t.Fatalf("expected context summary count 15, got %d", session.ContextSummaryMessageCount)
	}
	if session.ContextSummaryText == "" {
		t.Fatal("expected non-empty context summary")
	}

	totalMessages, err := repo.CountMessages(ctx, sessionID)
	if err != nil {
		t.Fatalf("CountMessages() error = %v", err)
	}
	if totalMessages != 35 {
		t.Fatalf("expected original messages retained, got %d", totalMessages)
	}
}

func TestService_CompressSessionMessages_AutoSkipWhenThresholdNotMet(t *testing.T) {
	ctx := context.Background()
	svc, repo := newCompressTestService(t)
	_, sessionID := seedAgentSessionWithMessages(
		t,
		ctx,
		repo,
		AgentProtocolMock,
		AgentProviderConfig{Model: "mock"},
		AgentProviderConfig{},
		25,
	)

	result, err := svc.CompressSessionMessages(ctx, sessionID, CompressSessionRequest{
		Trigger: "auto",
	})
	if err != nil {
		t.Fatalf("CompressSessionMessages() error = %v", err)
	}
	if result.Status != "skipped" {
		t.Fatalf("expected skipped status, got %s", result.Status)
	}

	session, err := repo.GetSessionByID(ctx, sessionID)
	if err != nil {
		t.Fatalf("GetSessionByID() error = %v", err)
	}
	if session.ContextSummaryMessageCount != 0 {
		t.Fatalf("expected summary count 0, got %d", session.ContextSummaryMessageCount)
	}
}

func TestService_CompressSessionMessages_AutoSkipOnCooldown(t *testing.T) {
	ctx := context.Background()
	svc, repo := newCompressTestService(t)
	_, sessionID := seedAgentSessionWithMessages(
		t,
		ctx,
		repo,
		AgentProtocolMock,
		AgentProviderConfig{Model: "mock"},
		AgentProviderConfig{},
		60,
	)
	now := time.Now().UTC().Format(time.RFC3339Nano)
	err := repo.UpdateSessionSummary(
		ctx,
		sessionID,
		"existing summary",
		map[string]any{
			"last_auto_compress_at": now,
		},
		now,
		5,
	)
	if err != nil {
		t.Fatalf("UpdateSessionSummary() error = %v", err)
	}

	result, err := svc.CompressSessionMessages(ctx, sessionID, CompressSessionRequest{
		Trigger: "auto",
	})
	if err != nil {
		t.Fatalf("CompressSessionMessages() error = %v", err)
	}
	if result.Status != "skipped" {
		t.Fatalf("expected skipped status on cooldown, got %s", result.Status)
	}
}

func newCompressTestService(t *testing.T) (*Service, *SQLiteAgentRepository) {
	t.Helper()

	dbPath := filepath.Join(t.TempDir(), "compress_test.db")
	db, err := sqlitestore.Open(dbPath)
	if err != nil {
		t.Fatalf("sqlite open error: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if err := sqlitestore.Migrate(context.Background(), db); err != nil {
		t.Fatalf("sqlite migrate error: %v", err)
	}

	repo := NewSQLiteAgentRepository(db)
	svc := NewServiceWithStoreAndDeps(
		NewMockClient(0),
		question.NewService(question.NewMemoryRepository()),
		nil,
		false,
		RuntimeConfig{
			Provider:      "mock",
			MockLatency:   0,
			AIHTTPTimeout: 5 * time.Second,
		},
		nil,
		repo,
		nil,
	)
	return svc, repo
}

func seedAgentSessionWithMessages(
	t *testing.T,
	ctx context.Context,
	repo *SQLiteAgentRepository,
	protocol AgentProtocol,
	primary AgentProviderConfig,
	fallback AgentProviderConfig,
	messageCount int,
) (string, string) {
	t.Helper()

	agentID := uuid.NewString()
	createdAt := time.Now().UTC().Add(-2 * time.Hour).Format(time.RFC3339Nano)
	agent := Agent{
		ID:                 agentID,
		Name:               "compress-test-agent",
		Protocol:           protocol,
		Primary:            primary,
		Fallback:           fallback,
		IntentCapabilities: []string{"chat", "generate_questions", "build_plan"},
		Enabled:            true,
		CreatedAt:          createdAt,
		UpdatedAt:          createdAt,
	}
	if _, err := repo.CreateAgent(ctx, agent); err != nil {
		t.Fatalf("CreateAgent() error = %v", err)
	}

	sessionID := uuid.NewString()
	session := AgentSession{
		ID:                      sessionID,
		AgentID:                 agentID,
		Title:                   "compress-session",
		ContextSummaryMeta:      map[string]any{},
		ContextSummaryUpdatedAt: "",
		CreatedAt:               createdAt,
		UpdatedAt:               createdAt,
	}
	if _, err := repo.CreateSession(ctx, session); err != nil {
		t.Fatalf("CreateSession() error = %v", err)
	}

	base := time.Now().UTC().Add(-90 * time.Minute)
	for i := 0; i < messageCount; i++ {
		role := "assistant"
		if i%2 == 0 {
			role = "user"
		}
		msg := AgentMessage{
			ID:        uuid.NewString(),
			SessionID: sessionID,
			Role:      role,
			Content:   "message-" + time.Now().UTC().Add(time.Duration(i)*time.Second).Format("15:04:05"),
			CreatedAt: base.Add(time.Duration(i) * time.Second).Format(time.RFC3339Nano),
		}
		if _, err := repo.CreateMessage(ctx, msg); err != nil {
			t.Fatalf("CreateMessage() error = %v", err)
		}
	}

	return agentID, sessionID
}
