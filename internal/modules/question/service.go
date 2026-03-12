package question

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"prts/internal/shared/errs"
)

type Service struct {
	repo              Repository
	difficultyService *DifficultyService
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) SetDifficultyService(ds *DifficultyService) {
	s.difficultyService = ds
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
		Type:         normalizeQuestionType(in.Type),
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
	oldItem.Type = normalizeQuestionType(in.Type)
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

func (s *Service) AssessDifficulty(ctx context.Context, id string) error {
	if s.difficultyService == nil {
		return errs.Internal("difficulty service not initialized")
	}
	q, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return err
	}
	level, err := s.difficultyService.AssessDifficulty(ctx, q.Stem, q.Subject)
	if err != nil {
		return err
	}
	q.Difficulty = level
	q.UpdatedAt = time.Now().UTC()
	_, err = s.repo.Update(ctx, q)
	return err
}

func validateInput(title, stem string, qType QuestionType, answerKey []string) error {
	if strings.TrimSpace(title) == "" {
		return errs.BadRequest("title is required")
	}
	if strings.TrimSpace(stem) == "" {
		return errs.BadRequest("stem is required")
	}
	normalizedType := normalizeQuestionType(qType)
	if normalizedType == "" {
		return errs.BadRequest("question type is required")
	}
	if !isValidQuestionType(normalizedType) {
		return errs.BadRequest("question type must be one of: single_choice/multi_choice/short_answer")
	}
	if len(answerKey) == 0 {
		return errs.BadRequest("answer_key is required")
	}
	return nil
}

func normalizeQuestionType(qType QuestionType) QuestionType {
	return QuestionType(strings.TrimSpace(string(qType)))
}

func isValidQuestionType(qType QuestionType) bool {
	switch qType {
	case SingleChoice, MultiChoice, ShortAnswer:
		return true
	default:
		return false
	}
}

func normalizeDifficulty(v int) int {
	if v < 1 {
		return 1
	}
	if v > 10 {
		return 10
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
