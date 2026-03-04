package bootstrap

import (
	"context"
	"testing"
	"time"

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
