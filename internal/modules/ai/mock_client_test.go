package ai

import (
	"context"
	"testing"
)

func TestMockClientChat_CompressSessionMode(t *testing.T) {
	client := NewMockClient(0)
	resp, err := client.Chat(context.Background(), ChatRequest{
		Mode:     " compress_session ",
		Messages: []ChatMessage{{Role: "user", Content: " summarize this dialog "}},
	})
	if err != nil {
		t.Fatalf("Chat() error = %v", err)
	}
	if resp.Content != "Mock summary: summarize this dialog" {
		t.Fatalf("unexpected summary content: %q", resp.Content)
	}
	if resp.Intent.Action != "none" {
		t.Fatalf("expected none action, got %s", resp.Intent.Action)
	}
}

func TestMockClientChat_DetectIntentMode(t *testing.T) {
	client := NewMockClient(0)
	resp, err := client.Chat(context.Background(), ChatRequest{
		Mode:     "detect_intent",
		Messages: []ChatMessage{{Role: "user", Content: "请帮我生成题目"}},
	})
	if err != nil {
		t.Fatalf("Chat() error = %v", err)
	}
	if resp.Intent.Action != "generate_questions" {
		t.Fatalf("expected generate_questions action, got %s", resp.Intent.Action)
	}
}
