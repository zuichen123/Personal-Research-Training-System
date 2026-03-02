package question

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

func (s *Service) Create(ctx context.Context, in CreateInput) (Question, error) {
	if err := validateInput(in.Title, in.Stem, in.Type, in.AnswerKey); err != nil {
		return Question{}, err
	}

	now := time.Now().UTC()
	item := Question{
		ID:           uuid.NewString(),
		Title:        strings.TrimSpace(in.Title),
		Stem:         strings.TrimSpace(in.Stem),
		Type:         in.Type,
		Subject:      normalizeSubject(in.Subject),
		Source:       normalizeSource(in.Source),
		Options:      in.Options,
		AnswerKey:    in.AnswerKey,
		Tags:         in.Tags,
		Difficulty:   normalizeDifficulty(in.Difficulty),
		MasteryLevel: normalizeMastery(in.MasteryLevel),
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	return s.repo.Create(ctx, item)
}

func (s *Service) List(ctx context.Context) ([]Question, error) {
	return s.repo.List(ctx)
}

func (s *Service) GetByID(ctx context.Context, id string) (Question, error) {
	if strings.TrimSpace(id) == "" {
		return Question{}, errs.BadRequest("question id is required")
	}
	return s.repo.GetByID(ctx, id)
}

func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (Question, error) {
	if strings.TrimSpace(id) == "" {
		return Question{}, errs.BadRequest("question id is required")
	}
	if err := validateInput(in.Title, in.Stem, in.Type, in.AnswerKey); err != nil {
		return Question{}, err
	}

	oldItem, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return Question{}, err
	}

	oldItem.Title = strings.TrimSpace(in.Title)
	oldItem.Stem = strings.TrimSpace(in.Stem)
	oldItem.Type = in.Type
	oldItem.Subject = normalizeSubject(in.Subject)
	oldItem.Source = normalizeSource(in.Source)
	oldItem.Options = in.Options
	oldItem.AnswerKey = in.AnswerKey
	oldItem.Tags = in.Tags
	oldItem.Difficulty = normalizeDifficulty(in.Difficulty)
	oldItem.MasteryLevel = normalizeMastery(in.MasteryLevel)
	oldItem.UpdatedAt = time.Now().UTC()

	return s.repo.Update(ctx, oldItem)
}

func (s *Service) Delete(ctx context.Context, id string) error {
	if strings.TrimSpace(id) == "" {
		return errs.BadRequest("question id is required")
	}
	return s.repo.Delete(ctx, id)
}

func validateInput(title, stem string, qType QuestionType, answerKey []string) error {
	if strings.TrimSpace(title) == "" {
		return errs.BadRequest("title is required")
	}
	if strings.TrimSpace(stem) == "" {
		return errs.BadRequest("stem is required")
	}
	if qType == "" {
		return errs.BadRequest("question type is required")
	}
	if len(answerKey) == 0 {
		return errs.BadRequest("answer_key is required")
	}
	return nil
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

func normalizeSubject(v string) string {
	t := strings.TrimSpace(v)
	if t == "" {
		return "general"
	}
	return t
}

func normalizeSource(v QuestionSource) QuestionSource {
	switch v {
	case SourceWrongBook, SourcePastExam, SourcePaper, SourceUnitTest, SourceAIGenerated:
		return v
	default:
		return SourceUnitTest
	}
}
