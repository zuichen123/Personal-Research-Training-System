package question

import "time"

type QuestionType string

const (
	SingleChoice QuestionType = "single_choice"
	MultiChoice  QuestionType = "multi_choice"
	ShortAnswer  QuestionType = "short_answer"
)

type Option struct {
	Key   string `json:"key"`
	Text  string `json:"text"`
	Score int    `json:"score,omitempty"`
}

type Question struct {
	ID         string       `json:"id"`
	Title      string       `json:"title"`
	Stem       string       `json:"stem"`
	Type       QuestionType `json:"type"`
	Options    []Option     `json:"options,omitempty"`
	AnswerKey  []string     `json:"answer_key,omitempty"`
	Tags       []string     `json:"tags,omitempty"`
	Difficulty int          `json:"difficulty"`
	CreatedAt  time.Time    `json:"created_at"`
	UpdatedAt  time.Time    `json:"updated_at"`
}

type CreateInput struct {
	Title      string       `json:"title"`
	Stem       string       `json:"stem"`
	Type       QuestionType `json:"type"`
	Options    []Option     `json:"options"`
	AnswerKey  []string     `json:"answer_key"`
	Tags       []string     `json:"tags"`
	Difficulty int          `json:"difficulty"`
}

type UpdateInput struct {
	Title      string       `json:"title"`
	Stem       string       `json:"stem"`
	Type       QuestionType `json:"type"`
	Options    []Option     `json:"options"`
	AnswerKey  []string     `json:"answer_key"`
	Tags       []string     `json:"tags"`
	Difficulty int          `json:"difficulty"`
}
