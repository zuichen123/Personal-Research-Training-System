package ai

import (
	"context"
	"fmt"

	"self-study-tool/internal/modules/profile"
)

type UserInfoResult struct {
	UserID            string                 `json:"user_id"`
	Nickname          string                 `json:"nickname"`
	Age               int                    `json:"age"`
	AcademicStatus    string                 `json:"academic_status"`
	Goals             []string               `json:"goals"`
	GoalTargetDate    string                 `json:"goal_target_date,omitempty"`
	DailyStudyMinutes int                    `json:"daily_study_minutes"`
	WeakSubjects      []string               `json:"weak_subjects"`
	TargetDestination string                 `json:"target_destination"`
	Notes             string                 `json:"notes"`
	SubjectProfiles   map[string]interface{} `json:"subject_profiles,omitempty"`
	OverallProfile    map[string]interface{} `json:"overall_profile,omitempty"`
	LifeProfile       map[string]interface{} `json:"life_profile,omitempty"`
}

func (s *Service) GetUserInfo(ctx context.Context, userID string) (UserInfoResult, error) {
	if s.profileService == nil {
		return UserInfoResult{}, fmt.Errorf("profile service not available")
	}

	item, err := s.profileService.Get(ctx, userID)
	if err != nil {
		return UserInfoResult{}, err
	}

	return UserInfoResult{
		UserID:            item.UserID,
		Nickname:          item.Nickname,
		Age:               item.Age,
		AcademicStatus:    item.AcademicStatus,
		Goals:             item.Goals,
		GoalTargetDate:    item.GoalTargetDate,
		DailyStudyMinutes: item.DailyStudyMinutes,
		WeakSubjects:      item.WeakSubjects,
		TargetDestination: item.TargetDestination,
		Notes:             item.Notes,
		SubjectProfiles:   item.SubjectProfiles,
		OverallProfile:    item.OverallProfile,
		LifeProfile:       item.LifeProfile,
	}, nil
}

type profileServiceInterface interface {
	Get(ctx context.Context, userID string) (profile.UserProfile, error)
	Upsert(ctx context.Context, in profile.UpsertInput) (profile.UserProfile, error)
}
