package ai

import (
	"strings"
	"testing"

	"self-study-tool/internal/modules/plan"
)

func TestRenderCurrentScheduleSegment_ThemeWithoutPlans(t *testing.T) {
	binding := ScheduleBinding{
		Mode:  scheduleBindingModeManual,
		Theme: "lesson context: math period 1",
	}

	got := renderCurrentScheduleSegment(binding, nil, "")
	if strings.TrimSpace(got) == "" {
		t.Fatalf("expected non-empty segment when theme exists")
	}
	if !strings.Contains(got, "theme=lesson context: math period 1") {
		t.Fatalf("expected theme in segment, got: %s", got)
	}
	if !strings.Contains(got, "no_matched_plans=true") {
		t.Fatalf("expected no_matched_plans marker, got: %s", got)
	}
}

func TestRenderCurrentScheduleSegment_AutoThemeOverridesManualTheme(t *testing.T) {
	binding := ScheduleBinding{
		Mode:  scheduleBindingModeAuto,
		Theme: "manual theme",
	}
	items := []plan.Item{
		{
			Title:      "review quadratic function",
			TargetDate: "2026-03-08",
			Status:     "pending",
			Priority:   3,
			Source:     plan.SourceAIAgent,
			Content:    "finish 10 exercises and summarize mistakes",
		},
	}

	got := renderCurrentScheduleSegment(binding, items, "auto theme")
	if !strings.Contains(got, "theme=auto theme") {
		t.Fatalf("expected auto theme in segment, got: %s", got)
	}
	if strings.Contains(got, "theme=manual theme") {
		t.Fatalf("did not expect manual theme when auto theme is present, got: %s", got)
	}
}
