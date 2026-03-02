package ai

import (
	"context"

	"self-study-tool/internal/modules/question"
)

type GenerateRequest struct {
	Topic      string `json:"topic"`
	Count      int    `json:"count"`
	Difficulty int    `json:"difficulty"`
}

type GradeRequest struct {
	Question   question.Question `json:"question"`
	UserAnswer []string          `json:"user_answer"`
}

type GradeResult struct {
	Score         float64 `json:"score"`
	Correct       bool    `json:"correct"`
	Feedback      string  `json:"feedback"`
	WrongReason   string  `json:"wrong_reason,omitempty"`
	ModelMetadata string  `json:"model_metadata,omitempty"`
}

type Client interface {
	GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error)
	GradeAnswer(ctx context.Context, req GradeRequest) (GradeResult, error)
}
