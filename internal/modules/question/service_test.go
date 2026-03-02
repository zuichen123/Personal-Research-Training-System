package question

import (
	"context"
	"testing"
)

func TestService_CreateAndGet(t *testing.T) {
	repo := NewMemoryRepository()
	svc := NewService(repo)

	created, err := svc.Create(context.Background(), CreateInput{
		Title:      "Binary Search",
		Stem:       "Explain the time complexity of binary search",
		Type:       ShortAnswer,
		AnswerKey:  []string{"logn"},
		Difficulty: 3,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	got, err := svc.GetByID(context.Background(), created.ID)
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if got.ID != created.ID {
		t.Fatalf("expected id %s, got %s", created.ID, got.ID)
	}
}

func TestService_CreateValidation(t *testing.T) {
	repo := NewMemoryRepository()
	svc := NewService(repo)

	_, err := svc.Create(context.Background(), CreateInput{})
	if err == nil {
		t.Fatal("expected validation error, got nil")
	}
}
