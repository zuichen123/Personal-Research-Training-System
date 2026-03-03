package plan

import (
	"context"
	"testing"
	"time"

	"self-study-tool/internal/shared/errs"
)

type testRepo struct {
	items map[string]Item
}

func newTestRepo() *testRepo {
	return &testRepo{items: make(map[string]Item)}
}

func (r *testRepo) Create(_ context.Context, item Item) (Item, error) {
	r.items[item.ID] = item
	return item, nil
}

func (r *testRepo) GetByID(_ context.Context, id string) (Item, error) {
	item, ok := r.items[id]
	if !ok {
		return Item{}, errs.NotFound("plan not found")
	}
	return item, nil
}

func (r *testRepo) List(_ context.Context, _ string) ([]Item, error) {
	out := make([]Item, 0, len(r.items))
	for _, item := range r.items {
		out = append(out, item)
	}
	return out, nil
}

func (r *testRepo) Update(_ context.Context, item Item) (Item, error) {
	if _, ok := r.items[item.ID]; !ok {
		return Item{}, errs.NotFound("plan not found")
	}
	item.UpdatedAt = time.Now().UTC()
	r.items[item.ID] = item
	return item, nil
}

func (r *testRepo) Delete(_ context.Context, id string) error {
	if _, ok := r.items[id]; !ok {
		return errs.NotFound("plan not found")
	}
	delete(r.items, id)
	return nil
}

func TestService_CreateValidation_MissingPlanType(t *testing.T) {
	svc := NewService(newTestRepo())

	_, err := svc.Create(context.Background(), CreateInput{
		Title: "plan",
	})
	if err == nil {
		t.Fatal("expected validation error, got nil")
	}
}

func TestService_CreateValidation_InvalidPlanType(t *testing.T) {
	svc := NewService(newTestRepo())

	_, err := svc.Create(context.Background(), CreateInput{
		PlanType: PlanType("foo"),
		Title:    "plan",
	})
	if err == nil {
		t.Fatal("expected validation error, got nil")
	}
}

func TestService_CreateValidation_ValidPlanType(t *testing.T) {
	svc := NewService(newTestRepo())

	item, err := svc.Create(context.Background(), CreateInput{
		PlanType: DayPlan,
		Title:    "plan",
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if item.PlanType != DayPlan {
		t.Fatalf("expected plan type %s, got %s", DayPlan, item.PlanType)
	}
}
