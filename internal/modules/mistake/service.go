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
		ID:         uuid.NewString(),
		QuestionID: strings.TrimSpace(in.QuestionID),
		UserAnswer: in.UserAnswer,
		Feedback:   strings.TrimSpace(in.Feedback),
		Reason:     strings.TrimSpace(in.Reason),
		CreatedAt:  time.Now().UTC(),
	}

	return s.repo.Create(ctx, item)
}

func (s *Service) List(ctx context.Context, questionID string) ([]Record, error) {
	if strings.TrimSpace(questionID) == "" {
		return s.repo.List(ctx)
	}
	return s.repo.ListByQuestionID(ctx, questionID)
}
