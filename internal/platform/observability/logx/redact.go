package logx

import (
	"net/http"
	"regexp"
	"strings"
)

var sensitiveKeyPatterns = []string{
	"authorization",
	"cookie",
	"set-cookie",
	"api_key",
	"apikey",
	"token",
	"secret",
	"password",
}

var jsonMaskPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)"api_key"\s*:\s*"[^"]*"`),
	regexp.MustCompile(`(?i)"token"\s*:\s*"[^"]*"`),
	regexp.MustCompile(`(?i)"secret"\s*:\s*"[^"]*"`),
	regexp.MustCompile(`(?i)"password"\s*:\s*"[^"]*"`),
}

func ShouldRedactBody(cfg Config) bool {
	mode := strings.ToLower(strings.TrimSpace(cfg.RedactionMode))
	switch mode {
	case "always":
		return true
	case "production_only":
		return strings.EqualFold(strings.TrimSpace(cfg.AppEnv), "production")
	default:
		return false
	}
}

func RedactHeaders(header http.Header) map[string]string {
	result := make(map[string]string, len(header))
	for k, v := range header {
		joined := strings.Join(v, ",")
		if isSensitiveKey(k) {
			result[k] = "***REDACTED***"
			continue
		}
		result[k] = joined
	}
	return result
}

func RedactString(value string) string {
	redacted := value
	for _, pattern := range jsonMaskPatterns {
		redacted = pattern.ReplaceAllStringFunc(redacted, func(s string) string {
			parts := strings.SplitN(s, ":", 2)
			if len(parts) != 2 {
				return s
			}
			return parts[0] + `:"***REDACTED***"`
		})
	}
	return redacted
}

func isSensitiveKey(key string) bool {
	lower := strings.ToLower(strings.TrimSpace(key))
	for _, keyword := range sensitiveKeyPatterns {
		if strings.Contains(lower, keyword) {
			return true
		}
	}
	return false
}
