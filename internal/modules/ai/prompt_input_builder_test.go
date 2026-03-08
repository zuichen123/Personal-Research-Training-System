package ai

import "testing"

func TestBuildPromptKeyValueInput(t *testing.T) {
	got := buildPromptKeyValueInput(
		promptField{key: " topic ", value: " algebra "},
		promptField{key: "count", value: 3},
		promptField{key: "answer_key", value: []string{"a", "b"}},
	)
	want := `topic=algebra
count=3
answer_key=[a b]`
	if got != want {
		t.Fatalf("buildPromptKeyValueInput()=%q, want %q", got, want)
	}
}

func TestJoinPromptInput(t *testing.T) {
	got := joinPromptInput(" math ", "", "  algebra geometry  ", " ")
	if got != "math algebra geometry" {
		t.Fatalf("joinPromptInput()=%q", got)
	}
}

func TestJSONPromptValue(t *testing.T) {
	got := jsonPromptValue(struct {
		Topic string `json:"topic"`
		Days  int    `json:"days"`
	}{Topic: "math", Days: 3})
	want := `{"topic":"math","days":3}`
	if got != want {
		t.Fatalf("jsonPromptValue()=%q, want %q", got, want)
	}
}
