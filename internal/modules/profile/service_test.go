package profile

import (
	"context"
	"testing"
	"time"

	"self-study-tool/internal/shared/errs"
)

type memoryRepository struct {
	items map[string]UserProfile
}

func newMemoryRepository() *memoryRepository {
	return &memoryRepository{
		items: map[string]UserProfile{
			"default": {
				UserID:            "default",
				Nickname:          "",
				Age:               0,
				AcademicStatus:    "",
				Goals:             []string{},
				GoalTargetDate:    "",
				DailyStudyMinutes: 0,
				WeakSubjects:      []string{},
				TargetDestination: "",
				Notes:             "",
				CreatedAt:         time.Now().UTC(),
				UpdatedAt:         time.Now().UTC(),
			},
		},
	}
}

func (r *memoryRepository) GetByUserID(_ context.Context, userID string) (UserProfile, error) {
	item, ok := r.items[userID]
	if !ok {
		return UserProfile{}, errs.NotFound("user profile not found")
	}
	return item, nil
}

func (r *memoryRepository) Upsert(_ context.Context, item UserProfile) (UserProfile, error) {
	r.items[item.UserID] = item
	return item, nil
}

func TestServiceUpsertRejectsInvalidInput(t *testing.T) {
	svc := NewService(newMemoryRepository())
	cases := []UpsertInput{
		{
			UserID:            "default",
			Age:               0,
			AcademicStatus:    "高中",
			Goals:             []string{"完成章节复习"},
			DailyStudyMinutes: 60,
		},
		{
			UserID:            "default",
			Age:               18,
			AcademicStatus:    "",
			Goals:             []string{"完成章节复习"},
			DailyStudyMinutes: 60,
		},
		{
			UserID:            "default",
			Age:               18,
			AcademicStatus:    "高中",
			Goals:             []string{},
			DailyStudyMinutes: 60,
		},
		{
			UserID:            "default",
			Age:               18,
			AcademicStatus:    "高中",
			Goals:             []string{"完成章节复习"},
			GoalTargetDate:    "2026/03/01",
			DailyStudyMinutes: 60,
		},
	}

	for _, tc := range cases {
		if _, err := svc.Upsert(context.Background(), tc); err == nil {
			t.Fatalf("expected validation error for %#v", tc)
		}
	}
}

func TestServiceUpsertAndGetDefaultProfile(t *testing.T) {
	svc := NewService(newMemoryRepository())
	updated, err := svc.Upsert(context.Background(), UpsertInput{
		UserID:            "",
		Nickname:          "UserA",
		Age:               17,
		AcademicStatus:    "grade12",
		Goals:             []string{"exam prep", "math improvement"},
		GoalTargetDate:    "2026-06-07",
		DailyStudyMinutes: 180,
		WeakSubjects:      []string{"math"},
		TargetDestination: "target university",
		Notes:             "daily review",
	})
	if err != nil {
		t.Fatalf("upsert profile error: %v", err)
	}
	if updated.UserID != "default" {
		t.Fatalf("unexpected user_id: %s", updated.UserID)
	}
	if len(updated.Goals) != 2 {
		t.Fatalf("expected 2 goals, got %d", len(updated.Goals))
	}

	got, err := svc.Get(context.Background(), "default")
	if err != nil {
		t.Fatalf("get profile error: %v", err)
	}
	if got.Nickname != "UserA" {
		t.Fatalf("unexpected nickname: %s", got.Nickname)
	}
}

func TestServiceSupportsOtherUserID(t *testing.T) {
	svc := NewService(newMemoryRepository())
	_, err := svc.Upsert(context.Background(), UpsertInput{
		UserID:            "other_user",
		Nickname:          "UserB",
		Age:               21,
		AcademicStatus:    "undergraduate",
		Goals:             []string{"prepare exam"},
		GoalTargetDate:    "",
		DailyStudyMinutes: 120,
		WeakSubjects:      []string{"english"},
		TargetDestination: "graduate exam",
		Notes:             "",
	})
	if err != nil {
		t.Fatalf("upsert other user profile error: %v", err)
	}

	defaultProfile, err := svc.Get(context.Background(), "default")
	if err != nil {
		t.Fatalf("get default profile error: %v", err)
	}
	otherProfile, err := svc.Get(context.Background(), "other_user")
	if err != nil {
		t.Fatalf("get other profile error: %v", err)
	}

	if defaultProfile.UserID == otherProfile.UserID {
		t.Fatal("expected isolated profile records by user_id")
	}
}
