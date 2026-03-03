package profile

import "time"

type UserProfile struct {
	UserID            string    `json:"user_id"`
	Nickname          string    `json:"nickname"`
	Age               int       `json:"age"`
	AcademicStatus    string    `json:"academic_status"`
	Goals             []string  `json:"goals"`
	GoalTargetDate    string    `json:"goal_target_date,omitempty"`
	DailyStudyMinutes int       `json:"daily_study_minutes"`
	WeakSubjects      []string  `json:"weak_subjects"`
	TargetDestination string    `json:"target_destination"`
	Notes             string    `json:"notes"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

type UpsertInput struct {
	UserID            string   `json:"user_id"`
	Nickname          string   `json:"nickname"`
	Age               int      `json:"age"`
	AcademicStatus    string   `json:"academic_status"`
	Goals             []string `json:"goals"`
	GoalTargetDate    string   `json:"goal_target_date"`
	DailyStudyMinutes int      `json:"daily_study_minutes"`
	WeakSubjects      []string `json:"weak_subjects"`
	TargetDestination string   `json:"target_destination"`
	Notes             string   `json:"notes"`
}
