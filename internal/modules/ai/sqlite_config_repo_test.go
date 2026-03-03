package ai

import (
	"context"
	"testing"

	sqlitestore "self-study-tool/internal/platform/storage/sqlite"
)

func TestSQLiteProviderConfigRepository_PromptTemplates(t *testing.T) {
	db, err := sqlitestore.Open("file::memory:?cache=shared")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()

	if err := sqlitestore.Migrate(context.Background(), db); err != nil {
		t.Fatalf("migrate sqlite: %v", err)
	}

	repo := NewSQLiteProviderConfigRepository(db)
	err = repo.SavePromptTemplate(context.Background(), PromptTemplateRecord{
		PromptKey:          PromptKeyGenerateQuestions,
		CustomPrompt:       "custom",
		OutputFormatPrompt: "output",
		UpdatedAt:          "2026-03-04T00:00:00Z",
	})
	if err != nil {
		t.Fatalf("save prompt template: %v", err)
	}

	items, err := repo.LoadPromptTemplates(context.Background())
	if err != nil {
		t.Fatalf("load prompt templates: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 prompt template row, got %d", len(items))
	}
	if items[0].PromptKey != PromptKeyGenerateQuestions {
		t.Fatalf("unexpected prompt key: %s", items[0].PromptKey)
	}
	if items[0].CustomPrompt != "custom" {
		t.Fatalf("unexpected custom prompt: %s", items[0].CustomPrompt)
	}
	if items[0].OutputFormatPrompt != "output" {
		t.Fatalf("unexpected output prompt: %s", items[0].OutputFormatPrompt)
	}
}
