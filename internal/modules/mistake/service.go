package mistake

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"self-study-tool/internal/shared/errs"
)

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, in CreateInput) (Record, error) {
	if strings.TrimSpace(in.QuestionID) == "" {
		return Record{}, errs.BadRequest("question_id is required")
	}

	item := Record{
		ID:           uuid.NewString(),
		QuestionID:   strings.TrimSpace(in.QuestionID),
		Subject:      normalizeSubject(in.Subject),
		Difficulty:   normalizeDifficulty(in.Difficulty),
		MasteryLevel: normalizeMastery(in.MasteryLevel),
		UserAnswer:   in.UserAnswer,
		Feedback:     strings.TrimSpace(in.Feedback),
		Reason:       strings.TrimSpace(in.Reason),
		CreatedAt:    time.Now().UTC(),
	}

	return s.repo.Create(ctx, item)
}

func (s *Service) List(ctx context.Context, questionID string) ([]Record, error) {
	if strings.TrimSpace(questionID) == "" {
		return s.repo.List(ctx)
	}
	return s.repo.ListByQuestionID(ctx, questionID)
}

func (s *Service) GetByID(ctx context.Context, id string) (Record, error) {
	if strings.TrimSpace(id) == "" {
		return Record{}, errs.BadRequest("mistake id is required")
	}
	return s.repo.GetByID(ctx, strings.TrimSpace(id))
}

func (s *Service) Delete(ctx context.Context, id string) error {
	if strings.TrimSpace(id) == "" {
		return errs.BadRequest("mistake id is required")
	}
	return s.repo.Delete(ctx, strings.TrimSpace(id))
}

func normalizeSubject(v string) string {
	t := strings.TrimSpace(v)
	if t == "" {
		return "general"
	}
	return t
}

func normalizeDifficulty(v int) int {
	if v < 1 {
		return 1
	}
	if v > 5 {
		return 5
	}
	return v
}

func normalizeMastery(v int) int {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}
