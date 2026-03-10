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

type UpdateUserProfileRequest struct {
	UserID            string                 `json:"user_id"`
	SubjectProfiles   map[string]interface{} `json:"subject_profiles,omitempty"`
	OverallProfile    map[string]interface{} `json:"overall_profile,omitempty"`
	LifeProfile       map[string]interface{} `json:"life_profile,omitempty"`
	WeakSubjects      []string               `json:"weak_subjects,omitempty"`
	Notes             string                 `json:"notes,omitempty"`
}

func (s *Service) UpdateUserProfile(ctx context.Context, req UpdateUserProfileRequest) (UserInfoResult, error) {
	if s.profileService == nil {
		return UserInfoResult{}, fmt.Errorf("profile service not available")
	}

	userID := req.UserID
	if userID == "" {
		userID = "default"
	}

	current, err := s.profileService.Get(ctx, userID)
	if err != nil {
		return UserInfoResult{}, err
	}

	input := profile.UpsertInput{
		UserID:            current.UserID,
		Nickname:          current.Nickname,
		Age:               current.Age,
		AcademicStatus:    current.AcademicStatus,
		Goals:             current.Goals,
		GoalTargetDate:    current.GoalTargetDate,
		DailyStudyMinutes: current.DailyStudyMinutes,
		WeakSubjects:      current.WeakSubjects,
		TargetDestination: current.TargetDestination,
		Notes:             current.Notes,
		SubjectProfiles:   current.SubjectProfiles,
		OverallProfile:    current.OverallProfile,
		LifeProfile:       current.LifeProfile,
	}

	if req.SubjectProfiles != nil {
		input.SubjectProfiles = req.SubjectProfiles
	}
	if req.OverallProfile != nil {
		input.OverallProfile = req.OverallProfile
	}
	if req.LifeProfile != nil {
		input.LifeProfile = req.LifeProfile
	}
	if req.WeakSubjects != nil {
		input.WeakSubjects = req.WeakSubjects
	}
	if req.Notes != "" {
		input.Notes = req.Notes
	}

	updated, err := s.profileService.Upsert(ctx, input)
	if err != nil {
		return UserInfoResult{}, err
	}

	return UserInfoResult{
		UserID:            updated.UserID,
		Nickname:          updated.Nickname,
		Age:               updated.Age,
		AcademicStatus:    updated.AcademicStatus,
		Goals:             updated.Goals,
		GoalTargetDate:    updated.GoalTargetDate,
		DailyStudyMinutes: updated.DailyStudyMinutes,
		WeakSubjects:      updated.WeakSubjects,
		TargetDestination: updated.TargetDestination,
		Notes:             updated.Notes,
		SubjectProfiles:   updated.SubjectProfiles,
		OverallProfile:    updated.OverallProfile,
		LifeProfile:       updated.LifeProfile,
	}, nil
}

type profileServiceInterface interface {
	Get(ctx context.Context, userID string) (profile.UserProfile, error)
	Upsert(ctx context.Context, in profile.UpsertInput) (profile.UserProfile, error)
}
