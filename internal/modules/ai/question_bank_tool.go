package ai

import (
	"context"
	"fmt"
	"strings"

	"prts/internal/modules/question"
)

type QuestionBankQueryResult struct {
	Questions []QuestionSummary `json:"questions"`
	Count     int               `json:"count"`
}

type QuestionSummary struct {
	ID         string   `json:"id"`
	Title      string   `json:"title"`
	Subject    string   `json:"subject"`
	Chapter    string   `json:"chapter"`
	Type       string   `json:"type"`
	Difficulty int      `json:"difficulty"`
	Tags       []string `json:"tags"`
	Source     string   `json:"source"`
}

func (s *Service) QueryQuestionBank(ctx context.Context, subject, chapter string, minDifficulty, maxDifficulty, limit int) (QuestionBankQueryResult, error) {
	if s.questionService == nil {
		return QuestionBankQueryResult{}, fmt.Errorf("question service not available")
	}

	if limit <= 0 || limit > 50 {
		limit = 20
	}
	if minDifficulty < 1 {
		minDifficulty = 1
	}
	if maxDifficulty > 10 {
		maxDifficulty = 10
	}

	items, err := s.questionService.List(ctx)
	if err != nil {
		return QuestionBankQueryResult{}, err
	}

	subject = strings.TrimSpace(subject)
	chapter = strings.TrimSpace(chapter)

	filtered := make([]question.Question, 0)
	for _, item := range items {
		if subject != "" && !strings.EqualFold(item.Subject, subject) {
			continue
		}
		if chapter != "" && !strings.EqualFold(item.Chapter, chapter) {
			continue
		}
		if item.Difficulty < minDifficulty || item.Difficulty > maxDifficulty {
			continue
		}
		filtered = append(filtered, item)
		if len(filtered) >= limit {
			break
		}
	}

	summaries := make([]QuestionSummary, 0, len(filtered))
	for _, item := range filtered {
		summaries = append(summaries, QuestionSummary{
			ID:         item.ID,
			Title:      item.Title,
			Subject:    item.Subject,
			Chapter:    item.Chapter,
			Type:       string(item.Type),
			Difficulty: item.Difficulty,
			Tags:       item.Tags,
			Source:     string(item.Source),
		})
	}

	return QuestionBankQueryResult{
		Questions: summaries,
		Count:     len(summaries),
	}, nil
}
