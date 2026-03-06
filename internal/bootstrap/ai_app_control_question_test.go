package bootstrap

import (
	"context"
	"testing"
	"time"

	"self-study-tool/internal/modules/practice"
	"self-study-tool/internal/modules/question"
)

func TestExecuteQuestionList_DefaultCompact(t *testing.T) {
	control := newQuestionControlFixture(t)

	result, err := control.executeQuestion(context.Background(), "list", map[string]any{})
	if err != nil {
		t.Fatalf("executeQuestion(list) error = %v", err)
	}

	items, ok := result.Data["items"].([]map[string]any)
	if !ok {
		t.Fatalf("expected []map[string]any items, got %T", result.Data["items"])
	}
	if len(items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(items))
	}

	item := mustFindQuestionItem(t, items, "q-1")
	if _, exists := item["stem"]; exists {
		t.Fatal("default list should not include stem")
	}
	if _, exists := item["answer_key"]; exists {
		t.Fatal("default list should not include answer_key")
	}
	if _, exists := item["options"]; exists {
		t.Fatal("default list should not include options")
	}
	if _, exists := item["title"]; !exists {
		t.Fatal("default list should include basic question fields")
	}
}

func TestExecuteQuestionList_IncludeContentAndUserAnswers(t *testing.T) {
	control := newQuestionControlFixture(t)

	result, err := control.executeQuestion(context.Background(), "list", map[string]any{
		"question_id":   "q-1",
		"include":       "content,user_answer",
		"attempt_limit": 1,
	})
	if err != nil {
		t.Fatalf("executeQuestion(list include content/user_answer) error = %v", err)
	}

	items, ok := result.Data["items"].([]map[string]any)
	if !ok {
		t.Fatalf("expected []map[string]any items, got %T", result.Data["items"])
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(items))
	}
	item := items[0]

	stem := item["stem"].(string)
	if stem == "" {
		t.Fatal("expected stem to be included")
	}
	if _, exists := item["answer_key"]; exists {
		t.Fatal("answer_key should still be omitted unless requested")
	}

	answers, ok := item["recent_user_answers"].([]map[string]any)
	if !ok {
		t.Fatalf("expected recent_user_answers []map[string]any, got %T", item["recent_user_answers"])
	}
	if len(answers) != 1 {
		t.Fatalf("expected 1 recent user answer, got %d", len(answers))
	}
	if item["attempt_count"] != 2 {
		t.Fatalf("expected attempt_count=2, got %v", item["attempt_count"])
	}
}

func TestExecuteQuestionGet_FullIncludeAndContentLimit(t *testing.T) {
	control := newQuestionControlFixture(t)

	result, err := control.executeQuestion(context.Background(), "get", map[string]any{
		"id":                "q-1",
		"include":           "content,answer_key,user_answer,attempts",
		"content_max_chars": 12,
	})
	if err != nil {
		t.Fatalf("executeQuestion(get include full) error = %v", err)
	}

	item, ok := result.Data["item"].(map[string]any)
	if !ok {
		t.Fatalf("expected map[string]any item, got %T", result.Data["item"])
	}

	stem, ok := item["stem"].(string)
	if !ok || stem == "" {
		t.Fatal("expected stem in get result")
	}
	if len([]rune(stem)) > 20 {
		t.Fatalf("expected stem to be truncated by content_max_chars, got %q", stem)
	}

	if _, ok := item["answer_key"]; !ok {
		t.Fatal("expected answer_key in get result")
	}
	attempts, ok := item["recent_attempts"].([]practice.Attempt)
	if !ok {
		t.Fatalf("expected recent_attempts []practice.Attempt, got %T", item["recent_attempts"])
	}
	if len(attempts) != 2 {
		t.Fatalf("expected 2 attempts, got %d", len(attempts))
	}
}

func newQuestionControlFixture(t *testing.T) *aiAppControl {
	t.Helper()

	ctx := context.Background()
	now := time.Date(2026, 3, 7, 8, 0, 0, 0, time.UTC)

	questionRepo := question.NewMemoryRepository()
	_, err := questionRepo.Create(ctx, question.Question{
		ID:           "q-1",
		Title:        "Algebra Basics",
		Stem:         "Solve equation x + 1 = 2 and explain your steps.",
		Type:         question.ShortAnswer,
		Subject:      "math",
		Source:       question.SourceUnitTest,
		Options:      []question.Option{},
		AnswerKey:    []string{"x=1"},
		Tags:         []string{"algebra", "equation"},
		Difficulty:   2,
		MasteryLevel: 0,
		CreatedAt:    now.Add(-2 * time.Hour),
		UpdatedAt:    now.Add(-1 * time.Hour),
	})
	if err != nil {
		t.Fatalf("seed question q-1 failed: %v", err)
	}
	_, err = questionRepo.Create(ctx, question.Question{
		ID:           "q-2",
		Title:        "Geometry Intro",
		Stem:         "Define an isosceles triangle.",
		Type:         question.ShortAnswer,
		Subject:      "math",
		Source:       question.SourceUnitTest,
		Options:      []question.Option{},
		AnswerKey:    []string{"two equal sides"},
		Tags:         []string{"geometry"},
		Difficulty:   1,
		MasteryLevel: 0,
		CreatedAt:    now.Add(-3 * time.Hour),
		UpdatedAt:    now.Add(-2 * time.Hour),
	})
	if err != nil {
		t.Fatalf("seed question q-2 failed: %v", err)
	}

	practiceRepo := practice.NewMemoryRepository()
	_, _ = practiceRepo.Create(ctx, practice.Attempt{
		ID:             "a-1",
		QuestionID:     "q-1",
		UserAnswer:     []string{"x=2"},
		ElapsedSeconds: 25,
		Score:          20,
		Correct:        false,
		Feedback:       "re-check arithmetic",
		SubmittedAt:    now.Add(-30 * time.Minute),
	})
	_, _ = practiceRepo.Create(ctx, practice.Attempt{
		ID:             "a-2",
		QuestionID:     "q-1",
		UserAnswer:     []string{"x=1"},
		ElapsedSeconds: 18,
		Score:          100,
		Correct:        true,
		Feedback:       "great",
		SubmittedAt:    now.Add(-10 * time.Minute),
	})

	return &aiAppControl{
		questionService: question.NewService(questionRepo),
		practiceService: practice.NewService(practiceRepo, nil, nil, nil),
	}
}

func mustFindQuestionItem(t *testing.T, items []map[string]any, id string) map[string]any {
	t.Helper()
	for _, item := range items {
		if item["id"] == id {
			return item
		}
	}
	t.Fatalf("question id=%s not found", id)
	return map[string]any{}
}
