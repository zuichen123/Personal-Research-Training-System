package ai

import (
	"context"
	"fmt"
	"strings"
	"time"

	"self-study-tool/internal/modules/question"
)

type MockClient struct {
	latency time.Duration
}

func NewMockClient(latency time.Duration) *MockClient {
	return &MockClient{latency: latency}
}

func (m *MockClient) GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error) {
	if req.Count <= 0 {
		req.Count = 3
	}
	if req.Count > 20 {
		req.Count = 20
	}
	if req.Difficulty < 1 {
		req.Difficulty = 2
	}

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(m.latency):
	}

	result := make([]question.CreateInput, 0, req.Count)
	for i := 1; i <= req.Count; i++ {
		result = append(result, question.CreateInput{
			Title:      fmt.Sprintf("%s 练习题 #%d", req.Topic, i),
			Stem:       fmt.Sprintf("请简要回答：%s 的关键知识点是什么？(第 %d 题)", req.Topic, i),
			Type:       question.ShortAnswer,
			AnswerKey:  []string{"核心概念", "应用场景"},
			Difficulty: req.Difficulty,
			Tags:       []string{req.Topic, "ai_generated"},
		})
	}
	return result, nil
}

func (m *MockClient) GradeAnswer(ctx context.Context, req GradeRequest) (GradeResult, error) {
	select {
	case <-ctx.Done():
		return GradeResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	if len(req.Question.AnswerKey) == 0 {
		return GradeResult{
			Score:    0,
			Correct:  false,
			Feedback: "题目未配置答案，无法批阅",
		}, nil
	}

	normalizedAnswer := strings.ToLower(strings.Join(req.UserAnswer, " "))
	hits := 0
	for _, expected := range req.Question.AnswerKey {
		if strings.Contains(normalizedAnswer, strings.ToLower(strings.TrimSpace(expected))) {
			hits++
		}
	}

	score := float64(hits) / float64(len(req.Question.AnswerKey)) * 100
	correct := score >= 60

	result := GradeResult{
		Score:         score,
		Correct:       correct,
		Feedback:      fmt.Sprintf("命中关键点 %d/%d", hits, len(req.Question.AnswerKey)),
		ModelMetadata: "provider=mock",
	}
	if !correct {
		result.WrongReason = "关键知识点覆盖不足"
	}

	return result, nil
}
