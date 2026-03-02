package ai

import (
	"context"
	"strings"

	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/shared/errs"
)

type Service struct {
	client          Client
	questionService *question.Service
}

func NewService(client Client, questionService *question.Service) *Service {
	return &Service{client: client, questionService: questionService}
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
			Title:      item.Title,
			Stem:       item.Stem,
			Type:       item.Type,
			Options:    item.Options,
			AnswerKey:  item.AnswerKey,
			Tags:       item.Tags,
			Difficulty: item.Difficulty,
		}
		result = append(result, q)
	}

	return result, nil
}

func (s *Service) Grade(ctx context.Context, req GradeRequest) (GradeResult, error) {
	return s.client.GradeAnswer(ctx, req)
}
