package plan

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"self-study-tool/internal/shared/errs"
)

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, in CreateInput) (Item, error) {
	if err := validateInput(in.PlanType, in.Title); err != nil {
		return Item{}, err
	}

	now := time.Now().UTC()
	item := Item{
		ID:         uuid.NewString(),
		PlanType:   normalizeType(in.PlanType),
		Title:      strings.TrimSpace(in.Title),
		Content:    strings.TrimSpace(in.Content),
		TargetDate: strings.TrimSpace(in.TargetDate),
		Status:     normalizeStatus(in.Status),
		Priority:   normalizePriority(in.Priority),
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	return s.repo.Create(ctx, item)
}

func (s *Service) GetByID(ctx context.Context, id string) (Item, error) {
	if strings.TrimSpace(id) == "" {
		return Item{}, errs.BadRequest("plan id is required")
	}
	return s.repo.GetByID(ctx, id)
}

func (s *Service) List(ctx context.Context, planType string) ([]Item, error) {
	return s.repo.List(ctx, strings.TrimSpace(planType))
}

func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (Item, error) {
	if strings.TrimSpace(id) == "" {
		return Item{}, errs.BadRequest("plan id is required")
	}
	if err := validateInput(in.PlanType, in.Title); err != nil {
		return Item{}, err
	}

	item, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return Item{}, err
	}

	item.PlanType = normalizeType(in.PlanType)
	item.Title = strings.TrimSpace(in.Title)
	item.Content = strings.TrimSpace(in.Content)
	item.TargetDate = strings.TrimSpace(in.TargetDate)
	item.Status = normalizeStatus(in.Status)
	item.Priority = normalizePriority(in.Priority)
	item.UpdatedAt = time.Now().UTC()

	return s.repo.Update(ctx, item)
}

func (s *Service) Delete(ctx context.Context, id string) error {
	if strings.TrimSpace(id) == "" {
		return errs.BadRequest("plan id is required")
	}
	return s.repo.Delete(ctx, id)
}

func validateInput(planType PlanType, title string) error {
	if strings.TrimSpace(title) == "" {
		return errs.BadRequest("title is required")
	}
	if normalizeType(planType) == "" {
		return errs.BadRequest("plan_type is required")
	}
	return nil
}

func normalizeType(planType PlanType) PlanType {
	switch planType {
	case MonthGoal, MonthPlan, DayGoal, DayPlan, CurrentPhase:
		return planType
	default:
		return DayPlan
	}
}

func normalizeStatus(v string) string {
	t := strings.TrimSpace(v)
	if t == "" {
		return "pending"
	}
	return t
}

func normalizePriority(v int) int {
	if v < 1 {
		return 1
	}
	if v > 5 {
		return 5
	}
	return v
}
