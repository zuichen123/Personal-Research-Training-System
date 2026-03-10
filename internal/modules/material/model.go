package material

import "time"

type Material struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	Title       string    `json:"title"`
	FilePath    string    `json:"file_path"`
	FileType    string    `json:"file_type"`
	ContentText string    `json:"content_text"`
	Subject     string    `json:"subject"`
	Tags        []string  `json:"tags"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type CreateInput struct {
	UserID      string   `json:"user_id"`
	Title       string   `json:"title"`
	FilePath    string   `json:"file_path"`
	FileType    string   `json:"file_type"`
	ContentText string   `json:"content_text"`
	Subject     string   `json:"subject"`
	Tags        []string `json:"tags"`
}

type UpdateInput struct {
	Title   *string  `json:"title"`
	Subject *string  `json:"subject"`
	Tags    []string `json:"tags"`
}

type ListFilter struct {
	UserID  string
	Subject string
	FileType string
	Limit   int
	Offset  int
}
