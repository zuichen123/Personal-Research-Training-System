package practice

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"self-study-tool/internal/modules/ai"
	"self-study-tool/internal/modules/mistake"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/shared/errs"
)

type Service struct {
	repo            Repository
	questionService *question.Service
	aiService       *ai.Service
	mistakeService  *mistake.Service
}

func NewService(repo Repository, questionService *question.Service, aiService *ai.Service, mistakeService *mistake.Service) *Service {
	return &Service{
		repo:            repo,
		questionService: questionService,
		aiService:       aiService,
		mistakeService:  mistakeService,
	}
}

func (s *Service) Submit(ctx context.Context, in SubmitInput) (Attempt, error) {
	if strings.TrimSpace(in.QuestionID) == "" {
		return Attempt{}, errs.BadRequest("question_id is required")
	}
	if len(in.UserAnswer) == 0 {
		return Attempt{}, errs.BadRequest("user_answer is required")
	}

	q, err := s.questionService.GetByID(ctx, in.QuestionID)
	if err != nil {
		return Attempt{}, err
	}

	gradeResult, err := s.aiService.Grade(ctx, ai.GradeRequest{
		Question:   q,
		UserAnswer: in.UserAnswer,
	})
	if err != nil {
		return Attempt{}, err
	}

	attempt := Attempt{
		ID:          uuid.NewString(),
		QuestionID:  q.ID,
		UserAnswer:  in.UserAnswer,
		Score:       gradeResult.Score,
		Correct:     gradeResult.Correct,
		Feedback:    gradeResult.Feedback,
		SubmittedAt: time.Now().UTC(),
	}

	stored, err := s.repo.Create(ctx, attempt)
	if err != nil {
		return Attempt{}, err
	}

	if !gradeResult.Correct {
		_, _ = s.mistakeService.Create(ctx, mistake.CreateInput{
			QuestionID:   q.ID,
			Subject:      q.Subject,
			Difficulty:   q.Difficulty,
			MasteryLevel: q.MasteryLevel,
			UserAnswer:   in.UserAnswer,
			Feedback:     gradeResult.Feedback,
			Reason:       gradeResult.WrongReason,
		})
	}

	return stored, nil
}

func (s *Service) ListAttempts(ctx context.Context) ([]Attempt, error) {
	return s.ListAttemptsByQuestionID(ctx, "")
}

func (s *Service) ListAttemptsByQuestionID(ctx context.Context, questionID string) ([]Attempt, error) {
	items, err := s.repo.List(ctx)
	if err != nil {
		return nil, err
	}
	questionID = strings.TrimSpace(questionID)
	if questionID == "" {
		return items, nil
	}
	filtered := make([]Attempt, 0, len(items))
	for _, item := range items {
		if item.QuestionID == questionID {
			filtered = append(filtered, item)
		}
	}
	return filtered, nil
}
