package question

import "time"

type QuestionType string

type QuestionSource string

const (
	SingleChoice QuestionType = "single_choice"
	MultiChoice  QuestionType = "multi_choice"
	ShortAnswer  QuestionType = "short_answer"
)

const (
	SourceWrongBook   QuestionSource = "wrong_book"
	SourcePastExam    QuestionSource = "past_exam"
	SourcePaper       QuestionSource = "paper"
	SourceUnitTest    QuestionSource = "unit_test"
	SourceAIGenerated QuestionSource = "ai_generated"
)

type Option struct {
	Key   string `json:"key"`
	Text  string `json:"text"`
	Score int    `json:"score,omitempty"`
}

type Question struct {
	ID           string         `json:"id"`
	Title        string         `json:"title"`
	Stem         string         `json:"stem"`
	Type         QuestionType   `json:"type"`
	Subject      string         `json:"subject"`
	Chapter      string         `json:"chapter,omitempty"`
	Source       QuestionSource `json:"source"`
	LessonID     string         `json:"lesson_id,omitempty"`
	Options      []Option       `json:"options,omitempty"`
	AnswerKey    []string       `json:"answer_key,omitempty"`
	Tags         []string       `json:"tags,omitempty"`
	Difficulty   int            `json:"difficulty"`
	MasteryLevel int            `json:"mastery_level"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
}

type CreateInput struct {
	Title        string         `json:"title"`
	Stem         string         `json:"stem"`
	Type         QuestionType   `json:"type"`
	Subject      string         `json:"subject"`
	Chapter      string         `json:"chapter"`
	Source       QuestionSource `json:"source"`
	LessonID     string         `json:"lesson_id"`
	Options      []Option       `json:"options"`
	AnswerKey    []string       `json:"answer_key"`
	Tags         []string       `json:"tags"`
	Difficulty   int            `json:"difficulty"`
	MasteryLevel int            `json:"mastery_level"`
}

type UpdateInput struct {
	Title        string         `json:"title"`
	Stem         string         `json:"stem"`
	Type         QuestionType   `json:"type"`
	Subject      string         `json:"subject"`
	Chapter      string         `json:"chapter"`
	Source       QuestionSource `json:"source"`
	LessonID     string         `json:"lesson_id"`
	Options      []Option       `json:"options"`
	AnswerKey    []string       `json:"answer_key"`
	Tags         []string       `json:"tags"`
	Difficulty   int            `json:"difficulty"`
	MasteryLevel int            `json:"mastery_level"`
}
