package resource

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"

	"github.com/google/uuid"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/shared/errs"
)

type Service struct {
	repo            Repository
	questionService *question.Service
}

func NewService(repo Repository, questionService *question.Service) *Service {
	return &Service{repo: repo, questionService: questionService}
}

func (s *Service) Create(ctx context.Context, in CreateInput) (Material, error) {
	if strings.TrimSpace(in.Filename) == "" {
		return Material{}, errs.BadRequest("filename is required")
	}
	if len(in.Data) == 0 {
		return Material{}, errs.BadRequest("file data is required")
	}

	contentType := strings.TrimSpace(in.ContentType)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	questionID := strings.TrimSpace(in.QuestionID)
	if questionID != "" {
		if _, err := s.questionService.GetByID(ctx, questionID); err != nil {
			return Material{}, err
		}
	}

	category := strings.TrimSpace(in.Category)
	if category == "" {
		category = "general"
	}

	hash := sha256.Sum256(in.Data)
	item := Material{
		ID:          uuid.NewString(),
		Filename:    strings.TrimSpace(in.Filename),
		ContentType: contentType,
		SizeBytes:   int64(len(in.Data)),
		Category:    category,
		Tags:        in.Tags,
		QuestionID:  questionID,
		UploadedAt:  time.Now().UTC(),
		SHA256:      hex.EncodeToString(hash[:]),
		Data:        in.Data,
	}

	return s.repo.Create(ctx, item)
}

func (s *Service) GetByID(ctx context.Context, id string) (Material, error) {
	if strings.TrimSpace(id) == "" {
		return Material{}, errs.BadRequest("resource id is required")
	}
	return s.repo.GetByID(ctx, id)
}

func (s *Service) List(ctx context.Context, questionID string) ([]Material, error) {
	if strings.TrimSpace(questionID) != "" {
		if _, err := s.questionService.GetByID(ctx, questionID); err != nil {
			return nil, err
		}
	}
	return s.repo.List(ctx, strings.TrimSpace(questionID))
}

func (s *Service) Delete(ctx context.Context, id string) error {
	if strings.TrimSpace(id) == "" {
		return errs.BadRequest("resource id is required")
	}
	return s.repo.Delete(ctx, strings.TrimSpace(id))
}
