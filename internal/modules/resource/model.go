package resource

import "time"

type Material struct {
	ID          string    `json:"id"`
	Filename    string    `json:"filename"`
	ContentType string    `json:"content_type"`
	SizeBytes   int64     `json:"size_bytes"`
	Category    string    `json:"category"`
	Tags        []string  `json:"tags"`
	QuestionID  string    `json:"question_id,omitempty"`
	UploadedAt  time.Time `json:"uploaded_at"`
	SHA256      string    `json:"sha256"`
	Data        []byte    `json:"-"`
}

type CreateInput struct {
	Filename    string
	ContentType string
	Category    string
	Tags        []string
	QuestionID  string
	Data        []byte
}
