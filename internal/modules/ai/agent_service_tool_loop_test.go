package ai

import (
	"strings"
	"testing"
)

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

func TestSupportedToolActionsFromCapabilities(t *testing.T) {
	got := supportedToolActionsFromCapabilities([]string{
		"chat",
		"manage_app",
		"build_plan",
		"generate_questions",
		"unknown_capability",
	})
	want := []string{"generate_questions", "build_plan", "manage_app"}
	if len(got) != len(want) {
		t.Fatalf("unexpected length: got=%v want=%v", got, want)
	}
	for idx := range want {
		if got[idx] != want[idx] {
			t.Fatalf("unexpected order/value: got=%v want=%v", got, want)
		}
	}
}

func TestBuildAgentToolPromptPatch_InsertsToolInstructionsByCapabilities(t *testing.T) {
	patch := buildAgentToolPromptPatch(
		Agent{IntentCapabilities: []string{"chat", "build_plan", "manage_app"}},
		PromptRuntimePatch{},
	)
	text := strings.TrimSpace(patch.SegmentUpdates[promptSegmentToolInstructions])
	if text == "" {
		t.Fatal("expected tool instructions to be injected")
	}
	if !strings.Contains(text, "build_plan") || !strings.Contains(text, "manage_app") {
		t.Fatalf("expected injected instructions to mention enabled tools, got: %s", text)
	}
	if strings.Contains(text, "generate_questions") {
		t.Fatalf("did not expect disabled tool in instructions, got: %s", text)
	}
}

func TestBuildAgentToolPromptPatch_RespectsExistingOverride(t *testing.T) {
	base := PromptRuntimePatch{
		SegmentUpdates: map[string]string{
			promptSegmentToolInstructions: "custom override",
		},
	}
	patch := buildAgentToolPromptPatch(
		Agent{IntentCapabilities: []string{"generate_questions", "build_plan", "manage_app"}},
		base,
	)
	if patch.SegmentUpdates[promptSegmentToolInstructions] != "custom override" {
		t.Fatalf("expected existing tool instructions to remain, got: %q", patch.SegmentUpdates[promptSegmentToolInstructions])
	}
}

func TestBuildToolResultChatMessage_IncludesDataPreview(t *testing.T) {
	msg := buildToolResultChatMessage(
		1,
		IntentResult{
			Action: "manage_app",
			Params: map[string]any{
				"module":    "question",
				"operation": "list",
			},
		},
		actionExecutionResult{
			Content: "fetched 2 questions",
			ToolData: map[string]any{
				"module":    "question",
				"operation": "list",
				"data": map[string]any{
					"items": []map[string]any{
						{"id": "q-1", "title": "Hash Table Basics"},
						{"id": "q-2", "title": "Binary Search Tree"},
					},
				},
			},
		},
	)

	text := strings.TrimSpace(msg.Content)
	if !strings.Contains(text, "data_preview=") {
		t.Fatalf("expected tool message with data preview, got: %s", text)
	}
	if !strings.Contains(text, "Hash Table Basics") {
		t.Fatalf("expected preview to include item details, got: %s", text)
	}
}

func TestToolDataPreview_EmptyMap(t *testing.T) {
	if got := toolDataPreview(map[string]any{}); got != "" {
		t.Fatalf("expected empty preview for empty map, got: %q", got)
	}
}

func TestIsDebugGetPromptCommand(t *testing.T) {
	if !isDebugGetPromptCommand("DEBUG-GET-PTROMPT") {
		t.Fatal("expected typo command variant to be supported")
	}
	if !isDebugGetPromptCommand("debug-get-prompt") {
		t.Fatal("expected corrected command variant to be supported")
	}
	if !isDebugGetPromptCommand("DEBUG") {
		t.Fatal("expected short debug command variant to be supported")
	}
	if isDebugGetPromptCommand("DEBUG-GET-XXX") {
		t.Fatal("did not expect unrelated debug command")
	}
}

func TestBuildDebugPromptDump_IncludesRequiredSections(t *testing.T) {
	svc := NewService(
		NewMockClient(0),
		newQuestionServiceForTest(),
		false,
		RuntimeConfig{Provider: "mock"},
	)
	text := svc.buildDebugPromptDump(
		Agent{
			ID:           "agent-1",
			Name:         "debug-agent",
			Protocol:     AgentProtocolMock,
			SystemPrompt: "you are a debug tutor",
		},
		PromptRuntimePatch{
			SegmentUpdates: map[string]string{
				promptSegmentCurrentSchedule: "lesson context",
			},
		},
		"DEBUG-GET-PTROMPT",
	)
	if !strings.Contains(text, "## system_prompt") {
		t.Fatalf("expected system prompt section, got: %s", text)
	}
	if !strings.Contains(text, "## detect_intent_prompt_effective") {
		t.Fatalf("expected detect_intent section, got: %s", text)
	}
	if !strings.Contains(text, "## agent_chat_prompt_effective") {
		t.Fatalf("expected agent_chat section, got: %s", text)
	}
}
