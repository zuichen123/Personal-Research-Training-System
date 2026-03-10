package profile

import "time"

type UserProfile struct {
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
	CreatedAt         time.Time              `json:"created_at"`
	UpdatedAt         time.Time              `json:"updated_at"`
}

type UpsertInput struct {
	UserID            string                 `json:"user_id"`
	Nickname          string                 `json:"nickname"`
	Age               int                    `json:"age"`
	AcademicStatus    string                 `json:"academic_status"`
	Goals             []string               `json:"goals"`
	GoalTargetDate    string                 `json:"goal_target_date"`
	DailyStudyMinutes int                    `json:"daily_study_minutes"`
	WeakSubjects      []string               `json:"weak_subjects"`
	TargetDestination string                 `json:"target_destination"`
	Notes             string                 `json:"notes"`
	SubjectProfiles   map[string]interface{} `json:"subject_profiles,omitempty"`
	OverallProfile    map[string]interface{} `json:"overall_profile,omitempty"`
	LifeProfile       map[string]interface{} `json:"life_profile,omitempty"`
}
