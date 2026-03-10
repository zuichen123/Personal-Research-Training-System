package practice

import "time"

type Attempt struct {
	ID               string    `json:"id"`
	QuestionID       string    `json:"question_id"`
	UserAnswer       []string  `json:"user_answer"`
	ElapsedSeconds   int       `json:"elapsed_seconds"`
	Score            float64   `json:"score"`
	Correct          bool      `json:"correct"`
	Feedback         string    `json:"feedback"`
	ErrorAnalysis    string    `json:"error_analysis,omitempty"`
	Suggestions      []string  `json:"suggestions,omitempty"`
	DetailedSolution string    `json:"detailed_solution,omitempty"`
	SubmittedAt      time.Time `json:"submitted_at"`
}

type SubmitInput struct {
	QuestionID     string   `json:"question_id"`
	UserAnswer     []string `json:"user_answer"`
	ElapsedSeconds int      `json:"elapsed_seconds"`
}
