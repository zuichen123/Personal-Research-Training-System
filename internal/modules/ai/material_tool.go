package ai

import (
	"context"
	"fmt"
	"strings"

	"prts/internal/modules/material"
)

type MaterialQueryResult struct {
	Materials []MaterialSummary `json:"materials"`
	Count     int               `json:"count"`
}

type MaterialSummary struct {
	ID          string   `json:"id"`
	Title       string   `json:"title"`
	Subject     string   `json:"subject"`
	FileType    string   `json:"file_type"`
	Tags        []string `json:"tags"`
	ContentSnippet string `json:"content_snippet"`
}

func (s *Service) QueryMaterials(ctx context.Context, subject, keyword string, limit int) (MaterialQueryResult, error) {
	if s.materialService == nil {
		return MaterialQueryResult{}, fmt.Errorf("material service not available")
	}

	if limit <= 0 || limit > 20 {
		limit = 10
	}

	filter := material.ListFilter{
		Subject: strings.TrimSpace(subject),
		Keyword: strings.TrimSpace(keyword),
		Limit:   limit,
	}

	items, err := s.materialService.List(ctx, filter)
	if err != nil {
		return MaterialQueryResult{}, err
	}

	summaries := make([]MaterialSummary, 0, len(items))
	for _, item := range items {
		snippet := item.ContentText
		if len(snippet) > 500 {
			snippet = snippet[:500] + "..."
		}
		summaries = append(summaries, MaterialSummary{
			ID:             item.ID,
			Title:          item.Title,
			Subject:        item.Subject,
			FileType:       item.FileType,
			Tags:           item.Tags,
			ContentSnippet: snippet,
		})
	}

	return MaterialQueryResult{
		Materials: summaries,
		Count:     len(summaries),
	}, nil
}

type materialServiceInterface interface {
	List(ctx context.Context, filter material.ListFilter) ([]material.Material, error)
	GetByID(ctx context.Context, id string) (material.Material, error)
}
