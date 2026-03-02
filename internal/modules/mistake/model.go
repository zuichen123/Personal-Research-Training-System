package mistake

import "time"

type Record struct {
	ID         string    `json:"id"`
	QuestionID string    `json:"question_id"`
	UserAnswer []string  `json:"user_answer"`
	Feedback   string    `json:"feedback"`
	Reason     string    `json:"reason"`
	CreatedAt  time.Time `json:"created_at"`
}

type CreateInput struct {
	QuestionID string   `json:"question_id"`
	UserAnswer []string `json:"user_answer"`
	Feedback   string   `json:"feedback"`
	Reason     string   `json:"reason"`
}
