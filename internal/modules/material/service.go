package material

import (
	"context"
	"strings"
	"time"

	"self-study-tool/internal/shared/errs"
)

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, in CreateInput) (Material, error) {
	userID := strings.TrimSpace(in.UserID)
	if userID == "" {
		userID = "default"
	}
	title := strings.TrimSpace(in.Title)
	if title == "" {
		return Material{}, errs.BadRequest("title is required")
	}
	filePath := strings.TrimSpace(in.FilePath)
	if filePath == "" {
		return Material{}, errs.BadRequest("file_path is required")
	}
	fileType := strings.TrimSpace(in.FileType)
	if fileType == "" {
		return Material{}, errs.BadRequest("file_type is required")
	}

	now := time.Now().UTC()
	item := Material{
		UserID:      userID,
		Title:       title,
		FilePath:    filePath,
		FileType:    fileType,
		ContentText: strings.TrimSpace(in.ContentText),
		Subject:     strings.TrimSpace(in.Subject),
		Tags:        normalizeStringList(in.Tags),
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	return s.repo.Create(ctx, item)
}

func (s *Service) GetByID(ctx context.Context, id string) (Material, error) {
	return s.repo.GetByID(ctx, id)
}

func (s *Service) List(ctx context.Context, filter ListFilter) ([]Material, error) {
	if filter.Limit <= 0 {
		filter.Limit = 50
	}
	return s.repo.List(ctx, filter)
}

func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (Material, error) {
	item, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return Material{}, err
	}
	if in.Title != nil {
		item.Title = strings.TrimSpace(*in.Title)
	}
	if in.Subject != nil {
		item.Subject = strings.TrimSpace(*in.Subject)
	}
	if in.Tags != nil {
		item.Tags = normalizeStringList(in.Tags)
	}
	item.UpdatedAt = time.Now().UTC()
	return s.repo.Update(ctx, id, item)
}

func (s *Service) Delete(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}

func normalizeStringList(items []string) []string {
	if len(items) == 0 {
		return []string{}
	}
	result := make([]string, 0, len(items))
	for _, item := range items {
		t := strings.TrimSpace(item)
		if t == "" {
			continue
		}
		result = append(result, t)
	}
	return result
}
