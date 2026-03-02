package ai

import (
	"context"
	"fmt"
	"math"
	"strings"

	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/shared/errs"
)

type Service struct {
	client          Client
	questionService *question.Service
	fallbackEnabled bool
}

func NewService(client Client, questionService *question.Service, fallbackEnabled bool) *Service {
	return &Service{
		client:          client,
		questionService: questionService,
		fallbackEnabled: fallbackEnabled,
	}
}

func (s *Service) ProviderStatus() ProviderStatus {
	return ProviderStatus{
		Provider: s.client.ProviderName(),
		Model:    s.client.ModelName(),
		Ready:    s.client.IsReady(),
		Fallback: s.fallbackEnabled,
	}
}

func (s *Service) Generate(ctx context.Context, req GenerateRequest, persist bool) ([]question.Question, error) {
	if strings.TrimSpace(req.Topic) == "" {
		return nil, errs.BadRequest("topic is required")
	}

	items, err := s.client.GenerateQuestions(ctx, req)
	if err != nil {
		return nil, err
	}

	result := make([]question.Question, 0, len(items))
	for _, item := range items {
		if persist {
			q, createErr := s.questionService.Create(ctx, item)
			if createErr != nil {
				return nil, createErr
			}
			result = append(result, q)
			continue
		}
		q := question.Question{
			Title:        item.Title,
			Stem:         item.Stem,
			Type:         item.Type,
			Subject:      item.Subject,
			Source:       item.Source,
			Options:      item.Options,
			AnswerKey:    item.AnswerKey,
			Tags:         item.Tags,
			Difficulty:   item.Difficulty,
			MasteryLevel: item.MasteryLevel,
		}
		result = append(result, q)
	}

	return result, nil
}

func (s *Service) Grade(ctx context.Context, req GradeRequest) (GradeResult, error) {
	return s.client.GradeAnswer(ctx, req)
}

func (s *Service) Learn(ctx context.Context, req LearnRequest) (LearnResult, error) {
	if strings.TrimSpace(req.Mode) == "" {
		return LearnResult{}, errs.BadRequest("mode is required")
	}
	if strings.TrimSpace(req.Subject) == "" {
		return LearnResult{}, errs.BadRequest("subject is required")
	}
	return s.client.BuildLearningPlan(ctx, req)
}

func (s *Service) Evaluate(ctx context.Context, req EvaluateRequest) (EvaluateResult, error) {
	if strings.TrimSpace(req.Mode) == "" {
		return EvaluateResult{}, errs.BadRequest("mode is required")
	}
	if req.Question.ID == "" && strings.TrimSpace(req.Context) == "" {
		return EvaluateResult{}, errs.BadRequest("question or context is required")
	}
	return s.client.EvaluateLearning(ctx, req)
}

func (s *Service) Score(ctx context.Context, req ScoreRequest) (ScoreResult, error) {
	if strings.TrimSpace(req.Topic) == "" {
		return ScoreResult{}, errs.BadRequest("topic is required")
	}
	if req.Accuracy < 0 || req.Accuracy > 100 || req.Stability < 0 || req.Stability > 100 || req.Speed < 0 || req.Speed > 100 {
		return ScoreResult{}, errs.BadRequest("accuracy/stability/speed must be in [0, 100]")
	}

	res, err := s.client.ScoreLearning(ctx, req)
	if err != nil {
		return ScoreResult{}, err
	}
	res.Score = math.Round(res.Score*10) / 10
	res.Grade = normalizeGrade(res.Score)
	if strings.TrimSpace(res.Grade) == "" {
		res.Grade = normalizeGrade(res.Score)
	}
	return res, nil
}

func normalizeGrade(score float64) string {
	switch {
	case score >= 90:
		return "A"
	case score >= 80:
		return "B"
	case score >= 70:
		return "C"
	case score >= 60:
		return "D"
	default:
		return "E"
	}
}

func (s *Service) SearchOnlineQuestions(ctx context.Context, topic, subject string, count int) ([]question.Question, error) {
	return s.Generate(ctx, GenerateRequest{
		Topic:      topic,
		Subject:    subject,
		Scope:      "network_search",
		Count:      count,
		Difficulty: 3,
	}, false)
}

func (s *Service) BuildRetestQuestions(ctx context.Context, subject, topic string, difficulty int) ([]question.Question, error) {
	items, err := s.Generate(ctx, GenerateRequest{
		Topic:      topic,
		Subject:    subject,
		Scope:      "retest",
		Count:      3,
		Difficulty: difficulty,
	}, false)
	if err != nil {
		return nil, fmt.Errorf("build retest questions: %w", err)
	}
	return items, nil
}
