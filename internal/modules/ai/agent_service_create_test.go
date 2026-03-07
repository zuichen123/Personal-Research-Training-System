package ai

import (
	"context"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"self-study-tool/internal/modules/question"
	sqlitestore "self-study-tool/internal/platform/storage/sqlite"
)

func TestService_CreateAgent_ManualCreateUsesConfiguredProviderDefaults(t *testing.T) {
	ctx := context.Background()
	svc, repo := newCreateAgentTestService(
		t,
		RuntimeConfig{
			Provider:      "openai",
			OpenAIBaseURL: "https://api.openai.com/v1",
			OpenAIAPIKey:  "runtime-openai-key",
			OpenAIModel:   "gpt-4.1-mini",
			AIHTTPTimeout: 5 * time.Second,
		},
	)

	created, err := svc.CreateAgent(ctx, UpsertAgentRequest{
		Name: "manual-agent",
	})
	if err != nil {
		t.Fatalf("CreateAgent() error = %v", err)
	}
	if created.Protocol != AgentProtocolOpenAICompatible {
		t.Fatalf("expected protocol=%s, got %s", AgentProtocolOpenAICompatible, created.Protocol)
	}
	// API keys are redacted in API responses.
	if created.Primary.APIKey != "" {
		t.Fatalf("expected redacted api key in response, got %q", created.Primary.APIKey)
	}

	stored, err := repo.GetAgentByID(ctx, created.ID)
	if err != nil {
		t.Fatalf("GetAgentByID() error = %v", err)
	}
	if stored.Protocol != AgentProtocolOpenAICompatible {
		t.Fatalf("expected stored protocol=%s, got %s", AgentProtocolOpenAICompatible, stored.Protocol)
	}
	if stored.Primary.APIKey != "runtime-openai-key" {
		t.Fatalf("expected stored api key from configured provider, got %q", stored.Primary.APIKey)
	}
	if stored.Primary.Model != "gpt-4.1-mini" {
		t.Fatalf("expected stored model from configured provider, got %q", stored.Primary.Model)
	}
	if !containsCapability(stored.IntentCapabilities, "manage_app") {
		t.Fatalf("expected default capabilities to include manage_app, got %v", stored.IntentCapabilities)
	}
}

func newCreateAgentTestService(t *testing.T, runtime RuntimeConfig) (*Service, *SQLiteAgentRepository) {
	t.Helper()

	dbPath := filepath.Join(t.TempDir(), "create_agent_test.db")
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
		runtime,
		nil,
		repo,
	)
	return svc, repo
}

func containsCapability(items []string, target string) bool {
	for _, item := range items {
		if strings.EqualFold(strings.TrimSpace(item), strings.TrimSpace(target)) {
			return true
		}
	}
	return false
}
