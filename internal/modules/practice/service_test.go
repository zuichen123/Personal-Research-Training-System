package practice

import (
	"context"
	"testing"
	"time"

	"self-study-tool/internal/modules/ai"
	"self-study-tool/internal/modules/mistake"
	"self-study-tool/internal/modules/question"
)

func TestService_SubmitWrongAnswerCreatesMistake(t *testing.T) {
	questionRepo := question.NewMemoryRepository()
	questionService := question.NewService(questionRepo)

	mistakeRepo := mistake.NewMemoryRepository()
	mistakeService := mistake.NewService(mistakeRepo)

	aiService := ai.NewService(ai.NewMockClient(0*time.Millisecond), questionService)
	practiceService := NewService(NewMemoryRepository(), questionService, aiService, mistakeService)

	q, err := questionService.Create(context.Background(), question.CreateInput{
		Title:      "Hash Table",
		Stem:       "What is the core value of hash table?",
		Type:       question.ShortAnswer,
		AnswerKey:  []string{"lookup", "time complexity"},
		Difficulty: 2,
	})
	if err != nil {
		t.Fatalf("create question error: %v", err)
	}

	attempt, err := practiceService.Submit(context.Background(), SubmitInput{
		QuestionID: q.ID,
		UserAnswer: []string{"not sure"},
	})
	if err != nil {
		t.Fatalf("submit error: %v", err)
	}
	if attempt.Correct {
		t.Fatal("expected incorrect attempt")
	}

	mistakes, err := mistakeService.List(context.Background(), q.ID)
	if err != nil {
		t.Fatalf("list mistakes error: %v", err)
	}
	if len(mistakes) != 1 {
		t.Fatalf("expected 1 mistake, got %d", len(mistakes))
	}
}
