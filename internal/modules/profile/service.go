package profile

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

func (s *Service) Get(ctx context.Context, userID string) (UserProfile, error) {
	return s.repo.GetByUserID(ctx, normalizeUserID(userID))
}

func (s *Service) Upsert(ctx context.Context, in UpsertInput) (UserProfile, error) {
	userID := normalizeUserID(in.UserID)
	academicStatus := strings.TrimSpace(in.AcademicStatus)
	if academicStatus == "" {
		return UserProfile{}, errs.BadRequest("academic_status is required")
	}
	if in.Age < 1 || in.Age > 120 {
		return UserProfile{}, errs.BadRequest("age must be in [1, 120]")
	}
	if in.DailyStudyMinutes < 0 || in.DailyStudyMinutes > 1440 {
		return UserProfile{}, errs.BadRequest("daily_study_minutes must be in [0, 1440]")
	}

	goals := normalizeStringList(in.Goals)
	if len(goals) == 0 {
		return UserProfile{}, errs.BadRequest("goals must contain at least one item")
	}

	goalTargetDate := strings.TrimSpace(in.GoalTargetDate)
	if goalTargetDate != "" {
		if _, err := time.Parse("2006-01-02", goalTargetDate); err != nil {
			return UserProfile{}, errs.BadRequest("goal_target_date must be in YYYY-MM-DD")
		}
	}

	now := time.Now().UTC()
	item, err := s.repo.GetByUserID(ctx, userID)
	if err != nil {
		if errs.FromError(err).Code != "not_found" {
			return UserProfile{}, err
		}
		item = UserProfile{
			UserID:    userID,
			CreatedAt: now,
		}
	}

	if item.CreatedAt.IsZero() {
		item.CreatedAt = now
	}
	item.Nickname = strings.TrimSpace(in.Nickname)
	item.Age = in.Age
	item.AcademicStatus = academicStatus
	item.Goals = goals
	item.GoalTargetDate = goalTargetDate
	item.DailyStudyMinutes = in.DailyStudyMinutes
	item.WeakSubjects = normalizeStringList(in.WeakSubjects)
	item.TargetDestination = strings.TrimSpace(in.TargetDestination)
	item.Notes = strings.TrimSpace(in.Notes)
	item.SubjectProfiles = in.SubjectProfiles
	item.OverallProfile = in.OverallProfile
	item.LifeProfile = in.LifeProfile
	item.UpdatedAt = now

	return s.repo.Upsert(ctx, item)
}

func normalizeUserID(v string) string {
	t := strings.TrimSpace(v)
	if t == "" {
		return "default"
	}
	return t
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
