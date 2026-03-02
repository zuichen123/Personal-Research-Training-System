package ai

import (
	"context"
	"fmt"
	"math"
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
	if req.Subject == "" {
		req.Subject = "general"
	}

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(m.latency):
	}

	result := make([]question.CreateInput, 0, req.Count)
	for i := 1; i <= req.Count; i++ {
		tags := []string{req.Topic, "ai_generated"}
		if req.Scope != "" {
			tags = append(tags, req.Scope)
		}

		result = append(result, question.CreateInput{
			Title:        fmt.Sprintf("%s Practice #%d", req.Topic, i),
			Stem:         fmt.Sprintf("Briefly explain the key points of %s (Q%d)", req.Topic, i),
			Type:         question.ShortAnswer,
			Subject:      req.Subject,
			Source:       question.SourceAIGenerated,
			AnswerKey:    []string{"core concept", "application scenario"},
			Difficulty:   req.Difficulty,
			MasteryLevel: 0,
			Tags:         tags,
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
			Feedback: "question has no answer key configured",
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
		Feedback:      fmt.Sprintf("hit key points %d/%d", hits, len(req.Question.AnswerKey)),
		ModelMetadata: "provider=mock",
	}
	if !correct {
		result.WrongReason = "insufficient key-point coverage"
	}

	return result, nil
}

func (m *MockClient) BuildLearningPlan(ctx context.Context, req LearnRequest) (LearnResult, error) {
	select {
	case <-ctx.Done():
		return LearnResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	unit := strings.TrimSpace(req.Unit)
	if unit == "" {
		unit = "general unit"
	}

	outline := []string{
		"Read core concepts and definitions",
		"Summarize key formulas and examples",
		"Complete 3 targeted exercises",
	}
	if strings.Contains(strings.ToLower(req.Mode), "review") {
		outline = []string{
			"Revisit wrong answers and weak points",
			"Redo prior exercises without notes",
			"Write a concise memory card summary",
		}
	}

	checklist := []string{
		"Can explain key concepts in your own words",
		"Can solve standard problem types",
		"Can identify common pitfalls",
	}

	return LearnResult{
		Mode:            req.Mode,
		Subject:         req.Subject,
		Unit:            unit,
		StudyOutline:    outline,
		ReviewChecklist: checklist,
		StageSuggestion: "Current stage: reinforce weak points then start mixed practice",
	}, nil
}

func (m *MockClient) EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error) {
	select {
	case <-ctx.Done():
		return EvaluateResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	grade, _ := m.GradeAnswer(ctx, GradeRequest{
		Question:   req.Question,
		UserAnswer: req.UserAnswer,
	})

	retest := []question.CreateInput{}
	if !grade.Correct {
		retest = append(retest, question.CreateInput{
			Title:        "Retest: key point reconstruction",
			Stem:         "List the missing key points and explain with one example",
			Type:         question.ShortAnswer,
			Subject:      req.Question.Subject,
			Source:       question.SourceWrongBook,
			AnswerKey:    req.Question.AnswerKey,
			Difficulty:   req.Question.Difficulty,
			MasteryLevel: 0,
			Tags:         []string{"retest", "ai_review"},
		})
	}

	return EvaluateResult{
		Score:                    grade.Score,
		SingleEvaluation:         fmt.Sprintf("Single-question evaluation: %s", grade.Feedback),
		ComprehensiveEvaluation:  "Comprehensive evaluation: topic coverage is improving but still uneven",
		SingleExplanation:        "Single explanation: focus on key concept + condition + application",
		ComprehensiveExplanation: "Comprehensive explanation: connect concepts across this unit before mixed tests",
		KnowledgeSupplements: []string{
			"Add one contrasting example for each key concept",
			"Build a small mistake-to-concept map",
		},
		RetestQuestions: retest,
	}, nil
}

func (m *MockClient) ScoreLearning(ctx context.Context, req ScoreRequest) (ScoreResult, error) {
	select {
	case <-ctx.Done():
		return ScoreResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	score := req.Accuracy*0.5 + req.Stability*0.3 + req.Speed*0.2
	score = math.Round(score*10) / 10

	advice := []string{
		"Prioritize weak knowledge nodes from mistakes",
		"Schedule one comprehensive review session every 3 days",
	}
	if score >= 85 {
		advice = []string{
			"Increase mixed-difficulty exercises",
			"Shift focus from accuracy to speed and consistency",
		}
	}

	return ScoreResult{
		Score:  score,
		Grade:  "",
		Advice: advice,
	}, nil
}
