package plan

import "time"

type PlanType string

type PlanSource string

const (
	YearPlan     PlanType = "year_plan"
	MonthGoal    PlanType = "month_goal"
	MonthPlan    PlanType = "month_plan"
	WeekPlan     PlanType = "week_plan"
	DayGoal      PlanType = "day_goal"
	DayPlan      PlanType = "day_plan"
	CurrentPhase PlanType = "current_phase"
)

const (
	SourceManual     PlanSource = "manual"
	SourceAILearning PlanSource = "ai_learning"
	SourceAIAgent    PlanSource = "ai_agent"
)

type Item struct {
	ID         string    `json:"id"`
	PlanType   PlanType  `json:"plan_type"`
	Title      string    `json:"title"`
	Content    string    `json:"content"`
	TargetDate string    `json:"target_date,omitempty"`
	Status     string    `json:"status"`
	Priority   int       `json:"priority"`
	Source     PlanSource `json:"source"`
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
	Source     PlanSource `json:"source"`
}

type UpdateInput struct {
	PlanType   PlanType `json:"plan_type"`
	Title      string   `json:"title"`
	Content    string   `json:"content"`
	TargetDate string   `json:"target_date"`
	Status     string   `json:"status"`
	Priority   int      `json:"priority"`
	Source     PlanSource `json:"source"`
}
