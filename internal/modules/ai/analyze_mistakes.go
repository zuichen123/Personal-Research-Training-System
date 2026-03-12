package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"prts/internal/modules/mistake"
	"prts/internal/modules/profile"
	"prts/internal/shared/errs"
)

type AnalyzeMistakesRequest struct {
	UserID   string           `json:"user_id"`
	Mistakes []mistake.Record `json:"mistakes"`
	Subject  string           `json:"subject"`
}

type AnalyzeMistakesResult struct {
	WeakPoints      []string          `json:"weak_points"`
	CommonReasons   []string          `json:"common_reasons"`
	Strengths       []string          `json:"strengths"`
	Recommendations []string          `json:"recommendations"`
	SubjectInsights map[string]string `json:"subject_insights"`
}

func (s *Service) AnalyzeMistakes(ctx context.Context, req AnalyzeMistakesRequest) (AnalyzeMistakesResult, error) {
	if len(req.Mistakes) == 0 {
		return AnalyzeMistakesResult{}, errs.BadRequest("mistakes are required")
	}

	mistakeSummary := buildMistakeSummary(req.Mistakes, req.Subject)
	prompt := fmt.Sprintf(`分析以下错题记录，总结用户的薄弱点、常见错误原因、优势和改进建议。

错题记录：
%s

请以JSON格式返回分析结果：
{
  "weak_points": ["薄弱点1", "薄弱点2"],
  "common_reasons": ["常见错误原因1", "常见错误原因2"],
  "strengths": ["优势1", "优势2"],
  "recommendations": ["建议1", "建议2"],
  "subject_insights": {"科目1": "该科目的具体分析"}
}`, mistakeSummary)

	resp, err := s.client.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return AnalyzeMistakesResult{}, err
	}

	var result AnalyzeMistakesResult
	if err := json.Unmarshal([]byte(resp.Content), &result); err != nil {
		return AnalyzeMistakesResult{}, errs.Internal(fmt.Sprintf("parse ai response: %v", err))
	}
	return result, nil
}

func buildMistakeSummary(mistakes []mistake.Record, subjectFilter string) string {
	var sb strings.Builder
	for i, m := range mistakes {
		if subjectFilter != "" && !strings.EqualFold(m.Subject, subjectFilter) {
			continue
		}
		sb.WriteString(fmt.Sprintf("%d. 科目：%s，难度：%d，原因：%s\n", i+1, m.Subject, m.Difficulty, m.Reason))
	}
	return sb.String()
}

func (s *Service) AnalyzeMistakesAndUpdateProfile(ctx context.Context, req AnalyzeMistakesRequest) (AnalyzeMistakesResult, error) {
	result, err := s.AnalyzeMistakes(ctx, req)
	if err != nil {
		return result, err
	}

	if s.profileService == nil {
		return result, nil
	}

	userProfile, err := s.profileService.Get(ctx, req.UserID)
	if err != nil && errs.FromError(err).Code != "not_found" {
		return result, nil
	}

	if userProfile.SubjectProfiles == nil {
		userProfile.SubjectProfiles = make(map[string]interface{})
	}

	analysisData := map[string]interface{}{
		"weak_points":      result.WeakPoints,
		"common_reasons":   result.CommonReasons,
		"strengths":        result.Strengths,
		"recommendations":  result.Recommendations,
		"subject_insights": result.SubjectInsights,
		"updated_at":       time.Now().UTC().Format(time.RFC3339),
	}

	if req.Subject != "" {
		userProfile.SubjectProfiles[req.Subject] = analysisData
	} else {
		userProfile.SubjectProfiles["overall_mistakes"] = analysisData
	}

	_, _ = s.profileService.Upsert(ctx, profile.UpsertInput{
		UserID:          req.UserID,
		Nickname:        userProfile.Nickname,
		Age:             userProfile.Age,
		AcademicStatus:  userProfile.AcademicStatus,
		Goals:           userProfile.Goals,
		SubjectProfiles: userProfile.SubjectProfiles,
	})

	return result, nil
}
