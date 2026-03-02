package pomodoro

import "time"

type SessionStatus string

const (
	Running   SessionStatus = "running"
	Completed SessionStatus = "completed"
	Canceled  SessionStatus = "canceled"
)

type Session struct {
	ID              string        `json:"id"`
	TaskTitle       string        `json:"task_title"`
	PlanID          string        `json:"plan_id,omitempty"`
	DurationMinutes int           `json:"duration_minutes"`
	BreakMinutes    int           `json:"break_minutes"`
	Status          SessionStatus `json:"status"`
	StartedAt       time.Time     `json:"started_at"`
	EndedAt         *time.Time    `json:"ended_at,omitempty"`
}

type StartInput struct {
	TaskTitle       string `json:"task_title"`
	PlanID          string `json:"plan_id"`
	DurationMinutes int    `json:"duration_minutes"`
	BreakMinutes    int    `json:"break_minutes"`
}

type EndInput struct {
	Status SessionStatus `json:"status"`
}
