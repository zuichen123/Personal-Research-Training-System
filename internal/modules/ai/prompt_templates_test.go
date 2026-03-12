package ai

import (
	"strings"
	"testing"
)

func TestPromptTemplateRuntime_Compose_UsesPresetWhenNoCustom(t *testing.T) {
	runtime := NewPromptTemplateRuntime()
	prompt := runtime.Compose(PromptKeyScoreLearning, "topic=math")

	if !strings.Contains(prompt, "## 人格设定") {
		t.Fatalf("expected segment header in composed text, got: %s", prompt)
	}
	if !strings.Contains(prompt, "学习数据科学分析师") {
		t.Fatalf("expected preset prompt in composed text, got: %s", prompt)
	}
	if !strings.Contains(prompt, "\"score\":0-100") {
		t.Fatalf("expected preset output prompt in composed text, got: %s", prompt)
	}
	if !strings.Contains(prompt, "## 用户输入") {
		t.Fatalf("expected user input section in composed text, got: %s", prompt)
	}
	if !strings.Contains(prompt, "topic=math") {
		t.Fatalf("expected user input in composed text, got: %s", prompt)
	}
}

func TestPromptTemplateRuntime_Compose_UsesCustomAndOutputOverride(t *testing.T) {
	runtime := NewPromptTemplateRuntime()
	_, ok := runtime.setOverride(PromptKeyScoreLearning, promptTemplateOverride{
		CustomPrompt:       "CUSTOM PROMPT",
		OutputFormatPrompt: "CUSTOM OUTPUT",
	})
	if !ok {
		t.Fatal("failed to set override")
	}

	prompt := runtime.Compose(PromptKeyScoreLearning, "topic=math")
	if !strings.Contains(prompt, "CUSTOM PROMPT") {
		t.Fatalf("expected custom prompt in composed text, got: %s", prompt)
	}
	if !strings.Contains(prompt, "CUSTOM OUTPUT") {
		t.Fatalf("expected custom output prompt in composed text, got: %s", prompt)
	}
	if strings.Contains(prompt, "learning score assistant") {
		t.Fatalf("preset prompt should be replaced by custom prompt, got: %s", prompt)
	}
}

func TestPromptTemplateRuntime_ReplaceAll(t *testing.T) {
	runtime := NewPromptTemplateRuntime()
	runtime.ReplaceAll([]PromptTemplateRecord{
		{
			PromptKey:            PromptKeyGradeAnswer,
			CustomPrompt:         "grade custom",
			OutputFormatPrompt:   "grade output",
			SegmentOverridesJSON: `{"rules":"always cite evidence","ai_memo":"remember weak points"}`,
			UpdatedAt:            "2026-03-04T00:00:00Z",
		},
	})

	cfg, ok := runtime.Get(PromptKeyGradeAnswer)
	if !ok {
		t.Fatal("expected known prompt key")
	}
	if cfg.CustomPrompt != "grade custom" {
		t.Fatalf("unexpected custom prompt: %s", cfg.CustomPrompt)
	}
	if cfg.OutputFormatPrompt != "grade output" {
		t.Fatalf("unexpected output format prompt: %s", cfg.OutputFormatPrompt)
	}
	if cfg.SegmentOverrides["rules"] != "always cite evidence" {
		t.Fatalf("unexpected rules segment override: %s", cfg.SegmentOverrides["rules"])
	}
	if cfg.EffectiveSegments["ai_memo"] != "remember weak points" {
		t.Fatalf("unexpected ai_memo effective segment: %s", cfg.EffectiveSegments["ai_memo"])
	}
	if cfg.UpdatedAt != "2026-03-04T00:00:00Z" {
		t.Fatalf("unexpected updated_at: %s", cfg.UpdatedAt)
	}
}
