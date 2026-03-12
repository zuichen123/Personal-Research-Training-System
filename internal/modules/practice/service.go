package practice

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"prts/internal/modules/ai"
	"prts/internal/modules/mistake"
	"prts/internal/modules/question"
	"prts/internal/shared/errs"
)

type Service struct {
	repo            Repository
	questionService *question.Service
	aiService       *ai.Service
	mistakeService  *mistake.Service
	gradingService  *GradingService
	paperGenerator  *PaperGenerator
}

func NewService(repo Repository, questionService *question.Service, aiService *ai.Service, mistakeService *mistake.Service) *Service {
	return &Service{
		repo:            repo,
		questionService: questionService,
		aiService:       aiService,
		mistakeService:  mistakeService,
	}
}

func (s *Service) SetGradingService(gs *GradingService) {
	s.gradingService = gs
}

func (s *Service) SetPaperGenerator(pg *PaperGenerator) {
	s.paperGenerator = pg
}

func (s *Service) Submit(ctx context.Context, in SubmitInput) (Attempt, error) {
	if strings.TrimSpace(in.QuestionID) == "" {
		return Attempt{}, errs.BadRequest("question_id is required")
	}
	if len(in.UserAnswer) == 0 {
		return Attempt{}, errs.BadRequest("user_answer is required")
	}
	if in.ElapsedSeconds < 0 {
		return Attempt{}, errs.BadRequest("elapsed_seconds must be >= 0")
	}

	q, err := s.questionService.GetByID(ctx, in.QuestionID)
	if err != nil {
		return Attempt{}, err
	}

	var gradeResult *GradingResult
	if s.gradingService != nil {
		gradeResult, err = s.gradingService.GradeAnswer(ctx, q.Subject, q.Stem, strings.Join(q.AnswerKey, ","), strings.Join(in.UserAnswer, ","))
		if err != nil {
			return Attempt{}, err
		}
	} else {
		aiGradeResult, err := s.aiService.Grade(ctx, ai.GradeRequest{
			Question:   q,
			UserAnswer: in.UserAnswer,
		})
		if err != nil {
			return Attempt{}, err
		}
		gradeResult = &GradingResult{
			Score:     int(aiGradeResult.Score),
			IsCorrect: aiGradeResult.Correct,
			Feedback:  aiGradeResult.Feedback,
		}
	}

	attempt := Attempt{
		ID:               uuid.NewString(),
		QuestionID:       q.ID,
		UserAnswer:       in.UserAnswer,
		ElapsedSeconds:   in.ElapsedSeconds,
		Score:            float64(gradeResult.Score),
		Correct:          gradeResult.IsCorrect,
		Feedback:         gradeResult.Feedback,
		ErrorAnalysis:    gradeResult.ErrorAnalysis,
		Suggestions:      gradeResult.Suggestions,
		DetailedSolution: gradeResult.DetailedSolution,
		SubmittedAt:      time.Now().UTC(),
	}

	stored, err := s.repo.Create(ctx, attempt)
	if err != nil {
		return Attempt{}, err
	}

	if !gradeResult.IsCorrect {
		_, _ = s.mistakeService.Create(ctx, mistake.CreateInput{
			QuestionID:   q.ID,
			Subject:      q.Subject,
			Difficulty:   q.Difficulty,
			MasteryLevel: q.MasteryLevel,
			UserAnswer:   in.UserAnswer,
			Feedback:     gradeResult.Feedback,
			Reason:       gradeResult.ErrorAnalysis,
		})
	}

	return stored, nil
}

func (s *Service) GeneratePaper(ctx context.Context, req GeneratePaperRequest) ([]PaperQuestion, error) {
	if s.paperGenerator == nil {
		return nil, errs.Internal("paper generator not initialized")
	}
	questions, err := s.paperGenerator.GeneratePaper(ctx, req)
	if err != nil {
		return nil, err
	}
	if err := s.paperGenerator.ValidatePaper(questions, req); err != nil {
		return nil, errs.BadRequest("paper validation failed: " + err.Error())
	}
	return questions, nil
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

func (s *Service) DeleteAttempt(ctx context.Context, id string) error {
	if strings.TrimSpace(id) == "" {
		return errs.BadRequest("attempt id is required")
	}
	return s.repo.Delete(ctx, strings.TrimSpace(id))
}
