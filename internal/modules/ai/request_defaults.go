package ai

import "strings"

func normalizeGenerateRequest(req GenerateRequest) GenerateRequest {
	if req.Count <= 0 {
		req.Count = 3
	}
	if req.Count > 20 {
		req.Count = 20
	}
	if req.Difficulty < 1 {
		req.Difficulty = 2
	}
	if strings.TrimSpace(req.Subject) == "" {
		req.Subject = "general"
	}
	return req
}
