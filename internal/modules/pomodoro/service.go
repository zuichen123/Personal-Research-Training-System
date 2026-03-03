package pomodoro

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

func (s *Service) Start(ctx context.Context, in StartInput) (Session, error) {
	if strings.TrimSpace(in.TaskTitle) == "" {
		return Session{}, errs.BadRequest("task_title is required")
	}
	running, err := s.repo.List(ctx, string(Running))
	if err != nil {
		return Session{}, err
	}
	if len(running) > 0 {
		return Session{}, errs.Conflict("another running session already exists")
	}

	now := time.Now().UTC()
	item := Session{
		ID:              uuid.NewString(),
		TaskTitle:       strings.TrimSpace(in.TaskTitle),
		PlanID:          strings.TrimSpace(in.PlanID),
		DurationMinutes: normalizeDuration(in.DurationMinutes),
		BreakMinutes:    normalizeBreak(in.BreakMinutes),
		Status:          Running,
		StartedAt:       now,
	}

	return s.repo.Create(ctx, item)
}

func (s *Service) End(ctx context.Context, id string, in EndInput) (Session, error) {
	if strings.TrimSpace(id) == "" {
		return Session{}, errs.BadRequest("session id is required")
	}

	item, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return Session{}, err
	}

	if item.Status != Running {
		return Session{}, errs.Conflict("session is already ended")
	}

	status := normalizeEndStatus(in.Status)
	now := time.Now().UTC()
	item.Status = status
	item.EndedAt = &now

	return s.repo.Update(ctx, item)
}

func (s *Service) List(ctx context.Context, status string) ([]Session, error) {
	return s.repo.List(ctx, strings.TrimSpace(status))
}

func (s *Service) Delete(ctx context.Context, id string) error {
	if strings.TrimSpace(id) == "" {
		return errs.BadRequest("session id is required")
	}
	return s.repo.Delete(ctx, id)
}

func normalizeDuration(v int) int {
	if v <= 0 {
		return 25
	}
	if v > 120 {
		return 120
	}
	return v
}

func normalizeBreak(v int) int {
	if v < 0 {
		return 5
	}
	if v > 30 {
		return 30
	}
	if v == 0 {
		return 5
	}
	return v
}

func normalizeEndStatus(v SessionStatus) SessionStatus {
	if v == Canceled {
		return Canceled
	}
	return Completed
}
