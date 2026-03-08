package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

type promptField struct {
	key   string
	value any
}

func buildPromptKeyValueInput(fields ...promptField) string {
	lines := make([]string, 0, len(fields))
	for _, field := range fields {
		key := strings.TrimSpace(field.key)
		if key == "" {
			continue
		}
		lines = append(lines, fmt.Sprintf("%s=%s", key, promptFieldValue(field.value)))
	}
	return strings.Join(lines, "\n")
}

func joinPromptInput(parts ...string) string {
	return strings.TrimSpace(strings.Join(normalizeStringList(parts), " "))
}

func promptFieldValue(value any) string {
	if text, ok := value.(string); ok {
		return strings.TrimSpace(text)
	}
	return fmt.Sprintf("%v", value)
}

func jsonPromptValue(value any) string {
	raw, err := json.Marshal(value)
	if err != nil {
		return "{}"
	}
	return string(raw)
}
