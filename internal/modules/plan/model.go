package plan

import "time"

type PlanType string

const (
	YearPlan     PlanType = "year_plan"
	MonthGoal    PlanType = "month_goal"
	MonthPlan    PlanType = "month_plan"
	WeekPlan     PlanType = "week_plan"
	DayGoal      PlanType = "day_goal"
	DayPlan      PlanType = "day_plan"
	CurrentPhase PlanType = "current_phase"
)

type Item struct {
	ID         string    `json:"id"`
	PlanType   PlanType  `json:"plan_type"`
	Title      string    `json:"title"`
	Content    string    `json:"content"`
	TargetDate string    `json:"target_date,omitempty"`
	Status     string    `json:"status"`
	Priority   int       `json:"priority"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type CreateInput struct {
	PlanType   PlanType `json:"plan_type"`
	Title      string   `json:"title"`
	Content    string   `json:"content"`
	TargetDate string   `json:"target_date"`
	Status     string   `json:"status"`
	Priority   int      `json:"priority"`
}

type UpdateInput struct {
	PlanType   PlanType `json:"plan_type"`
	Title      string   `json:"title"`
	Content    string   `json:"content"`
	TargetDate string   `json:"target_date"`
	Status     string   `json:"status"`
	Priority   int      `json:"priority"`
}
