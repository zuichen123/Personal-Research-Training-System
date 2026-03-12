package plan

import (
	"context"
	"strings"
	"time"

	"prts/internal/shared/errs"

	"github.com/google/uuid"
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
		Source:     normalizeSource(in.Source),
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
	item.Source = normalizeSource(in.Source)
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
	normalizedType := normalizeType(planType)
	if normalizedType == "" {
		return errs.BadRequest("plan_type is required")
	}
	if !isValidPlanType(normalizedType) {
		return errs.BadRequest("plan_type must be one of: year_plan/month_goal/month_plan/week_plan/day_goal/day_plan/current_phase")
	}
	return nil
}

func normalizeType(planType PlanType) PlanType {
	return PlanType(strings.TrimSpace(string(planType)))
}

func isValidPlanType(planType PlanType) bool {
	switch planType {
	case YearPlan, MonthGoal, MonthPlan, WeekPlan, DayGoal, DayPlan, CurrentPhase:
		return true
	default:
		return false
	}
}

func normalizeStatus(v string) string {
	t := strings.TrimSpace(v)
	if t == "" {
		return string(StatusPending)
	}
	switch PlanStatus(t) {
	case StatusPending, StatusInProgress, StatusCompleted, StatusArchived:
		return t
	default:
		return string(StatusPending)
	}
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

func normalizeSource(v PlanSource) PlanSource {
	source := PlanSource(strings.TrimSpace(string(v)))
	if source == "" {
		return SourceManual
	}
	switch source {
	case SourceManual, SourceAILearning, SourceAIAgent:
		return source
	default:
		return SourceManual
	}
}
