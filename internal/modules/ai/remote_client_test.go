package ai

import "testing"

func TestRemoteLLMClientEnsureReady(t *testing.T) {
	client := &remoteLLMClient{ready: false}
	if err := client.ensureReady(); err == nil {
		t.Fatal("expected not-ready error")
	}

	client.ready = true
	if err := client.ensureReady(); err != nil {
		t.Fatalf("expected ready client, got %v", err)
	}
}

func TestNormalizePercentageScore(t *testing.T) {
	tests := []struct {
		name string
		in   float64
		want float64
	}{
		{name: "negative", in: -3.2, want: 0},
		{name: "over max", in: 140.8, want: 100},
		{name: "round one decimal", in: 88.88, want: 88.9},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := normalizePercentageScore(tc.in); got != tc.want {
				t.Fatalf("normalizePercentageScore(%v)=%v, want %v", tc.in, got, tc.want)
			}
		})
	}
}

func TestBuildChatUserInput(t *testing.T) {
	req := ChatRequest{
		SystemPrompt: "  system rules  ",
		Messages: []ChatMessage{
			{Role: "", Content: " first "},
			{Role: "assistant", Content: " second "},
			{Role: "user", Content: "   "},
		},
	}
	got := buildChatUserInput(req)
	want := `system: system rules
user: first
assistant: second`
	if got != want {
		t.Fatalf("buildChatUserInput()=%q, want %q", got, want)
	}
}

func TestBuildChatUserInput_DefaultFallback(t *testing.T) {
	if got := buildChatUserInput(ChatRequest{}); got != "user: hello" {
		t.Fatalf("expected fallback user input, got %q", got)
	}
}

func TestResolveChatModeConfig(t *testing.T) {
	tests := []struct {
		name       string
		mode       string
		promptKey  string
		operation  string
		normalized string
	}{
		{name: "default", mode: "", promptKey: PromptKeyAgentChat, operation: "agent_chat", normalized: ""},
		{name: "detect intent", mode: " detect_intent ", promptKey: PromptKeyDetectIntent, operation: "detect_intent", normalized: PromptKeyDetectIntent},
		{name: "compress", mode: "compress_session", promptKey: PromptKeyCompressSession, operation: "compress_session", normalized: PromptKeyCompressSession},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := resolveChatModeConfig(tc.mode)
			if got.promptKey != tc.promptKey || got.operation != tc.operation || got.mode != tc.normalized {
				t.Fatalf("resolveChatModeConfig(%q)=%+v", tc.mode, got)
			}
		})
	}
}
