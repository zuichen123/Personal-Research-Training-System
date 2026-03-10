package mistake

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

type AnalysisService struct {
	aiClient AIClient
}

type AIClient interface {
	Chat(ctx context.Context, req ChatRequest) (ChatResponse, error)
}

type ChatRequest struct {
	Messages []ChatMessage
}

type ChatMessage struct {
	Role    string
	Content string
}

type ChatResponse struct {
	Content string
}

type AnalysisResult struct {
	ErrorPatterns []string          `json:"error_patterns"`
	WeakPoints    []string          `json:"weak_points"`
	Strengths     []string          `json:"strengths"`
	Suggestions   []string          `json:"suggestions"`
	ProfileData   map[string]string `json:"profile_data"`
}

func NewAnalysisService(aiClient AIClient) *AnalysisService {
	return &AnalysisService{aiClient: aiClient}
}

func (s *AnalysisService) AnalyzeMistakes(ctx context.Context, userID int64, subject string, mistakes []string) (*AnalysisResult, error) {
	prompt := s.buildAnalysisPrompt(subject, mistakes)

	resp, err := s.aiClient.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return nil, err
	}

	return s.parseAnalysis(resp.Content)
}

func (s *AnalysisService) buildAnalysisPrompt(subject string, mistakes []string) string {
	mistakeList := strings.Join(mistakes, "\n- ")
	return fmt.Sprintf(`分析学生在%s科目的错题，识别：
1. 错误模式（重复出现的错误类型）
2. 薄弱点（需要加强的知识点）
3. 优势（掌握较好的部分）
4. 学习建议

错题列表：
- %s

返回JSON格式：
{
  "error_patterns": ["模式1", "模式2"],
  "weak_points": ["薄弱点1", "薄弱点2"],
  "strengths": ["优势1", "优势2"],
  "suggestions": ["建议1", "建议2"],
  "profile_data": {"key": "value"}
}`, subject, mistakeList)
}

func (s *AnalysisService) parseAnalysis(content string) (*AnalysisResult, error) {
	content = strings.TrimSpace(content)
	if idx := strings.Index(content, "{"); idx >= 0 {
		content = content[idx:]
	}
	if idx := strings.LastIndex(content, "}"); idx >= 0 {
		content = content[:idx+1]
	}

	var result AnalysisResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		return nil, fmt.Errorf("parse analysis: %w", err)
	}
	return &result, nil
}
