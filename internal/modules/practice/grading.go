package practice

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

type GradingService struct {
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

type GradingResult struct {
	Score            int      `json:"score"`
	IsCorrect        bool     `json:"is_correct"`
	Feedback         string   `json:"feedback"`
	ErrorAnalysis    string   `json:"error_analysis,omitempty"`
	Suggestions      []string `json:"suggestions,omitempty"`
	DetailedSolution string   `json:"detailed_solution"`
}

func NewGradingService(aiClient AIClient) *GradingService {
	return &GradingService{aiClient: aiClient}
}

func (s *GradingService) GradeAnswer(ctx context.Context, subject, question, correctAnswer, userAnswer string) (*GradingResult, error) {
	prompt := s.buildGradingPrompt(subject, question, correctAnswer, userAnswer)

	resp, err := s.aiClient.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return nil, err
	}

	return s.parseGradingResult(resp.Content)
}

func (s *GradingService) buildGradingPrompt(subject, question, correctAnswer, userAnswer string) string {
	return fmt.Sprintf(`作为专业的%s教师，请评分学生答案。

题目：%s
标准答案：%s
学生答案：%s

评分标准（高考级别）：
- 100分：完全正确，步骤清晰
- 80-99分：答案正确，步骤略有瑕疵
- 60-79分：方法正确，计算错误
- 40-59分：部分理解，重大错误
- 0-39分：方法错误或无理解

返回JSON格式：
{
  "score": 分数,
  "is_correct": true/false,
  "feedback": "总体评价",
  "error_analysis": "错误分析（如有）",
  "suggestions": ["建议1", "建议2"],
  "detailed_solution": "详细解答"
}`, subject, question, correctAnswer, userAnswer)
}

func (s *GradingService) parseGradingResult(content string) (*GradingResult, error) {
	content = strings.TrimSpace(content)
	if idx := strings.Index(content, "{"); idx >= 0 {
		content = content[idx:]
	}
	if idx := strings.LastIndex(content, "}"); idx >= 0 {
		content = content[:idx+1]
	}

	var result GradingResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		return nil, fmt.Errorf("parse grading result: %w", err)
	}
	return &result, nil
}
