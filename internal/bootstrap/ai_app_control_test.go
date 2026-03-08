package bootstrap

import (
	"context"
	"strings"
	"testing"
	"time"

	"self-study-tool/internal/modules/ai"
	"self-study-tool/internal/modules/plan"
	"self-study-tool/internal/shared/errs"
)

type testPlanRepo struct {
	items map[string]plan.Item
}

func newTestPlanRepo(items []plan.Item) *testPlanRepo {
	store := make(map[string]plan.Item, len(items))
	for _, item := range items {
		store[item.ID] = item
	}
	return &testPlanRepo{items: store}
}

func (r *testPlanRepo) Create(_ context.Context, item plan.Item) (plan.Item, error) {
	r.items[item.ID] = item
	return item, nil
}

func (r *testPlanRepo) GetByID(_ context.Context, id string) (plan.Item, error) {
	item, ok := r.items[id]
	if !ok {
		return plan.Item{}, errs.NotFound("plan not found")
	}
	return item, nil
}

func (r *testPlanRepo) List(_ context.Context, planType string) ([]plan.Item, error) {
	items := make([]plan.Item, 0, len(r.items))
	for _, item := range r.items {
		if planType != "" && string(item.PlanType) != planType {
			continue
		}
		items = append(items, item)
	}
	return items, nil
}

func (r *testPlanRepo) Update(_ context.Context, item plan.Item) (plan.Item, error) {
	if _, ok := r.items[item.ID]; !ok {
		return plan.Item{}, errs.NotFound("plan not found")
	}
	r.items[item.ID] = item
	return item, nil
}

func (r *testPlanRepo) Delete(_ context.Context, id string) error {
	if _, ok := r.items[id]; !ok {
		return errs.NotFound("plan not found")
	}
	delete(r.items, id)
	return nil
}

func TestResolvePlanID_ByTitleAndDate(t *testing.T) {
	repo := newTestPlanRepo([]plan.Item{
		{
			ID:         "p-1",
			PlanType:   plan.DayPlan,
			Title:      "Math Review",
			Content:    "chapter 1",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-2",
			PlanType:   plan.DayPlan,
			Title:      "Math Review",
			Content:    "chapter 2",
			TargetDate: "2026-03-11",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
	})
	control := &aiAppControl{planService: plan.NewService(repo)}

	id, candidates, err := control.resolvePlanID(context.Background(), map[string]any{
		"title":       "Math Review",
		"target_date": "2026-03-10",
	})
	if err != nil {
		t.Fatalf("resolvePlanID() error = %v", err)
	}
	if id != "p-1" {
		t.Fatalf("expected p-1, got %s", id)
	}
	if len(candidates) != 1 {
		t.Fatalf("expected 1 candidate, got %d", len(candidates))
	}
}

func TestResolvePlanID_UsesPlanTypeAlias(t *testing.T) {
	repo := newTestPlanRepo([]plan.Item{
		{
			ID:         "p-day",
			PlanType:   plan.DayPlan,
			Title:      "Math Review",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-week",
			PlanType:   plan.WeekPlan,
			Title:      "Math Review",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   2,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
	})
	control := &aiAppControl{planService: plan.NewService(repo)}

	id, candidates, err := control.resolvePlanID(context.Background(), map[string]any{
		"title": "Math Review",
		"type":  "weekly",
	})
	if err != nil {
		t.Fatalf("resolvePlanID() error = %v", err)
	}
	if id != "p-week" {
		t.Fatalf("expected p-week, got %s", id)
	}
	if len(candidates) != 1 {
		t.Fatalf("expected 1 candidate, got %d", len(candidates))
	}
}

func TestExecutePlanDelete_ResolvesWithoutID(t *testing.T) {
	repo := newTestPlanRepo([]plan.Item{
		{
			ID:         "p-keep",
			PlanType:   plan.DayPlan,
			Title:      "English",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   2,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-del",
			PlanType:   plan.DayPlan,
			Title:      "Math Review",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
	})
	control := &aiAppControl{planService: plan.NewService(repo)}

	result, err := control.executePlan(context.Background(), "delete", map[string]any{
		"title":       "Math Review",
		"target_date": "2026-03-10",
	})
	if err != nil {
		t.Fatalf("executePlan(delete) error = %v", err)
	}
	if result.Summary != "Deleted plan p-del." {
		t.Fatalf("unexpected summary: %s", result.Summary)
	}
	if _, exists := repo.items["p-del"]; exists {
		t.Fatal("expected p-del to be deleted")
	}
}

func TestExecutePlanDelete_Ambiguous(t *testing.T) {
	repo := newTestPlanRepo([]plan.Item{
		{
			ID:         "p-1",
			PlanType:   plan.DayPlan,
			Title:      "Math Review",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-2",
			PlanType:   plan.DayPlan,
			Title:      "Math Review",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   4,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
	})
	control := &aiAppControl{planService: plan.NewService(repo)}

	_, err := control.executePlan(context.Background(), "delete", map[string]any{
		"title": "Math Review",
	})
	if err == nil {
		t.Fatal("expected ambiguity error, got nil")
	}
	if errs.FromError(err).Code != "bad_request" {
		t.Fatalf("expected bad request, got %v", err)
	}
}

func TestExecutePlanDeleteAll_ByOperation(t *testing.T) {
	repo := newTestPlanRepo([]plan.Item{
		{
			ID:         "p-1",
			PlanType:   plan.DayPlan,
			Title:      "Math",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-2",
			PlanType:   plan.WeekPlan,
			Title:      "English",
			TargetDate: "2026-03-11",
			Status:     string(plan.StatusInProgress),
			Priority:   2,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
	})
	control := &aiAppControl{planService: plan.NewService(repo)}

	result, err := control.executePlan(context.Background(), "delete_all", map[string]any{})
	if err != nil {
		t.Fatalf("executePlan(delete_all) error = %v", err)
	}
	if result.Summary == "" {
		t.Fatal("expected non-empty summary")
	}
	if len(repo.items) != 0 {
		t.Fatalf("expected all plans deleted, remaining=%d", len(repo.items))
	}
	if asInt(result.Data["deleted_count"], 0) != 2 {
		t.Fatalf("expected deleted_count=2, got %v", result.Data["deleted_count"])
	}
}

func TestExecutePlanDelete_WithAllFlagAndFilter(t *testing.T) {
	repo := newTestPlanRepo([]plan.Item{
		{
			ID:         "p-1",
			PlanType:   plan.DayPlan,
			Title:      "Math",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-2",
			PlanType:   plan.DayPlan,
			Title:      "English",
			TargetDate: "2026-03-11",
			Status:     string(plan.StatusCompleted),
			Priority:   2,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-3",
			PlanType:   plan.DayPlan,
			Title:      "Physics",
			TargetDate: "2026-03-12",
			Status:     string(plan.StatusPending),
			Priority:   4,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
	})
	control := &aiAppControl{planService: plan.NewService(repo)}

	_, err := control.executePlan(context.Background(), "delete", map[string]any{
		"all":    true,
		"status": "pending",
	})
	if err != nil {
		t.Fatalf("executePlan(delete with all=true) error = %v", err)
	}
	if _, exists := repo.items["p-2"]; !exists {
		t.Fatal("expected non-matching plan p-2 to remain")
	}
	if _, exists := repo.items["p-1"]; exists {
		t.Fatal("expected matching plan p-1 deleted")
	}
	if _, exists := repo.items["p-3"]; exists {
		t.Fatal("expected matching plan p-3 deleted")
	}
}

func TestExecutePlanDelete_WithPlanTypeAliasFilter(t *testing.T) {
	repo := newTestPlanRepo([]plan.Item{
		{
			ID:         "p-day",
			PlanType:   plan.DayPlan,
			Title:      "Daily Math",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   3,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
		{
			ID:         "p-week",
			PlanType:   plan.WeekPlan,
			Title:      "Weekly Math",
			TargetDate: "2026-03-10",
			Status:     string(plan.StatusPending),
			Priority:   2,
			Source:     plan.SourceManual,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
		},
	})
	control := &aiAppControl{planService: plan.NewService(repo)}

	result, err := control.executePlan(context.Background(), "delete", map[string]any{
		"all":  true,
		"type": "weekly",
	})
	if err != nil {
		t.Fatalf("executePlan(delete with type alias) error = %v", err)
	}
	if asInt(result.Data["deleted_count"], 0) != 1 {
		t.Fatalf("expected deleted_count=1, got %v", result.Data["deleted_count"])
	}
	if _, exists := repo.items["p-day"]; !exists {
		t.Fatal("expected day plan to remain")
	}
	if _, exists := repo.items["p-week"]; exists {
		t.Fatal("expected week plan to be deleted")
	}
}

func TestApplyCreateAgentDefaults_UsesDefaultNameWithoutForcingMock(t *testing.T) {
	req := buildUpsertAgentRequest(map[string]any{})
	got := applyCreateAgentDefaults(req, map[string]any{}, createAgentProviderDefaults{})

	if got.Name != "new-agent" {
		t.Fatalf("expected default name new-agent, got %q", got.Name)
	}
	if strings.TrimSpace(string(got.Protocol)) != "" {
		t.Fatalf("expected protocol to remain empty, got %s", got.Protocol)
	}
}

func TestApplyCreateAgentDefaults_KeepConfiguredProvider(t *testing.T) {
	params := map[string]any{
		"name":     "math-agent",
		"protocol": "openai_compatible",
		"primary": map[string]any{
			"api_key": "sk-test",
			"model":   "gpt-4o-mini",
		},
	}
	req := buildUpsertAgentRequest(params)
	got := applyCreateAgentDefaults(req, params, createAgentProviderDefaults{})

	if got.Name != "math-agent" {
		t.Fatalf("expected name=math-agent, got %q", got.Name)
	}
	if got.Protocol != ai.AgentProtocolOpenAICompatible {
		t.Fatalf("expected protocol=%s, got %s", ai.AgentProtocolOpenAICompatible, got.Protocol)
	}
}

func TestApplyCreateAgentDefaults_UseGlobalProviderDefaultsWhenPrimaryMissing(t *testing.T) {
	params := map[string]any{
		"name": "math-agent",
	}
	req := buildUpsertAgentRequest(params)
	got := applyCreateAgentDefaults(req, params, createAgentProviderDefaults{
		Protocol: ai.AgentProtocolGeminiNative,
		Primary: ai.AgentProviderConfig{
			APIKey: "gemini-key",
			Model:  "gemini-2.0-flash",
		},
		Ready: true,
	})

	if got.Protocol != ai.AgentProtocolGeminiNative {
		t.Fatalf("expected protocol=%s, got %s", ai.AgentProtocolGeminiNative, got.Protocol)
	}
	if got.Primary.APIKey != "gemini-key" {
		t.Fatalf("expected default api key to be applied, got %q", got.Primary.APIKey)
	}
	if got.Primary.Model != "gemini-2.0-flash" {
		t.Fatalf("expected default model to be applied, got %q", got.Primary.Model)
	}
}

func TestApplyCreateAgentDefaults_OverrideMismatchedProtocolWhenPrimaryMissing(t *testing.T) {
	params := map[string]any{
		"name":     "math-agent",
		"protocol": "openai_compatible",
		"primary": map[string]any{
			"model": "gpt-4o-mini",
		},
	}
	req := buildUpsertAgentRequest(params)
	got := applyCreateAgentDefaults(req, params, createAgentProviderDefaults{
		Protocol: ai.AgentProtocolGeminiNative,
		Primary: ai.AgentProviderConfig{
			APIKey: "gemini-key",
			Model:  "gemini-2.0-flash",
		},
		Ready: true,
	})

	if got.Protocol != ai.AgentProtocolGeminiNative {
		t.Fatalf("expected protocol=%s, got %s", ai.AgentProtocolGeminiNative, got.Protocol)
	}
	if got.Primary.APIKey != "gemini-key" {
		t.Fatalf("expected default api key to be applied, got %q", got.Primary.APIKey)
	}
	if got.Primary.Model != "gemini-2.0-flash" {
		t.Fatalf("expected default model to replace mismatched value, got %q", got.Primary.Model)
	}
}

func TestResolveAgentID_DirectAlias(t *testing.T) {
	control := &aiAppControl{}
	id, err := control.resolveAgentID(context.Background(), "delete", map[string]any{
		"agent_id": "agent-001",
	})
	if err != nil {
		t.Fatalf("resolveAgentID() error = %v", err)
	}
	if id != "agent-001" {
		t.Fatalf("expected agent-001, got %s", id)
	}
}

func TestResolveAgentID_DirectAliasCamelCase(t *testing.T) {
	control := &aiAppControl{}
	id, err := control.resolveAgentID(context.Background(), "delete", map[string]any{
		"agentId": "agent-002",
	})
	if err != nil {
		t.Fatalf("resolveAgentID() error = %v", err)
	}
	if id != "agent-002" {
		t.Fatalf("expected agent-002, got %s", id)
	}
}

func TestResolveAgentIDFromItems_ByName(t *testing.T) {
	items := []ai.Agent{
		{ID: "a-1", Name: "Math Tutor", Protocol: ai.AgentProtocolMock, Enabled: true},
		{ID: "a-2", Name: "English Tutor", Protocol: ai.AgentProtocolMock, Enabled: true},
	}
	id, candidates := resolveAgentIDFromItems(map[string]any{"name": "Math Tutor"}, items)
	if id != "a-1" {
		t.Fatalf("expected a-1, got %s", id)
	}
	if len(candidates) != 1 {
		t.Fatalf("expected 1 candidate, got %d", len(candidates))
	}
}

func TestResolveAgentIDFromItems_AmbiguousKeyword(t *testing.T) {
	items := []ai.Agent{
		{ID: "a-1", Name: "Math Tutor Alpha", Protocol: ai.AgentProtocolMock, Enabled: true},
		{ID: "a-2", Name: "Math Tutor Beta", Protocol: ai.AgentProtocolMock, Enabled: true},
		{ID: "a-3", Name: "English Tutor", Protocol: ai.AgentProtocolMock, Enabled: true},
	}
	id, candidates := resolveAgentIDFromItems(map[string]any{"keyword": "math tutor"}, items)
	if id != "" {
		t.Fatalf("expected empty id for ambiguous keyword, got %s", id)
	}
	if len(candidates) != 2 {
		t.Fatalf("expected 2 candidates, got %d", len(candidates))
	}
}

func TestExecutePlanCreate_InferDayPlanTypeWhenMissing(t *testing.T) {
	repo := newTestPlanRepo(nil)
	control := &aiAppControl{planService: plan.NewService(repo)}

	result, err := control.executePlan(context.Background(), "create", map[string]any{
		"title":       "复习函数",
		"content":     "完成 5 道题",
		"target_date": "2026-03-08",
		"status":      "pending",
	})
	if err != nil {
		t.Fatalf("executePlan(create) error = %v", err)
	}
	itemAny, ok := result.Data["item"]
	if !ok {
		t.Fatalf("expected item in result data, got: %+v", result.Data)
	}
	item, ok := itemAny.(plan.Item)
	if !ok {
		t.Fatalf("expected plan.Item, got %T", itemAny)
	}
	if item.PlanType != plan.DayPlan {
		t.Fatalf("expected inferred plan_type=%s, got %s", plan.DayPlan, item.PlanType)
	}
}

func TestNormalizePlanTypeAlias(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want plan.PlanType
	}{
		{name: "empty", in: "", want: ""},
		{name: "week alias", in: "weekly", want: plan.WeekPlan},
		{name: "day alias", in: "day", want: plan.DayPlan},
		{name: "month goal", in: "month_goal", want: plan.MonthGoal},
		{name: "unknown passthrough", in: "custom_type", want: plan.PlanType("custom_type")},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := normalizePlanTypeAlias(tc.in)
			if got != tc.want {
				t.Fatalf("normalizePlanTypeAlias(%q)=%q, want %q", tc.in, got, tc.want)
			}
		})
	}
}
