package practice

import "time"

type Attempt struct {
	ID          string    `json:"id"`
	QuestionID  string    `json:"question_id"`
	UserAnswer  []string  `json:"user_answer"`
	Score       float64   `json:"score"`
	Correct     bool      `json:"correct"`
	Feedback    string    `json:"feedback"`
	SubmittedAt time.Time `json:"submitted_at"`
}

type SubmitInput struct {
	QuestionID string   `json:"question_id"`
	UserAnswer []string `json:"user_answer"`
}
