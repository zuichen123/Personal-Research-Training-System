package ai

import "testing"

func TestSameManageAppIntent_ByID(t *testing.T) {
	left := IntentResult{
		Action:     "manage_app",
		Confidence: 0.9,
		Params: map[string]any{
			"module":    "plan",
			"operation": "delete",
			"id":        "p-1",
		},
	}
	right := IntentResult{
		Action:     "manage_app",
		Confidence: 0.9,
		Params: map[string]any{
			"module":    "plan",
			"operation": "delete",
			"plan_id":   "p-1",
		},
	}
	if !sameManageAppIntent(left, right) {
		t.Fatal("expected intents to be considered the same by id")
	}
}

func TestSameManageAppIntent_BySelectors(t *testing.T) {
	left := IntentResult{
		Action: "manage_app",
		Params: map[string]any{
			"module":      "plan",
			"operation":   "delete_all",
			"status":      "pending",
			"target_date": "2026-03-10",
		},
	}
	right := IntentResult{
		Action: "manage_app",
		Params: map[string]any{
			"module":      "plan",
			"operation":   "delete_all",
			"status":      "pending",
			"target_date": "2026-03-10",
		},
	}
	if !sameManageAppIntent(left, right) {
		t.Fatal("expected intents to be considered the same by selectors")
	}
}

func TestSameManageAppIntent_DifferentOperation(t *testing.T) {
	left := IntentResult{
		Action: "manage_app",
		Params: map[string]any{
			"module":    "plan",
			"operation": "list",
		},
	}
	right := IntentResult{
		Action: "manage_app",
		Params: map[string]any{
			"module":    "plan",
			"operation": "delete_all",
		},
	}
	if sameManageAppIntent(left, right) {
		t.Fatal("expected intents with different operation to differ")
	}
}
