package practice

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

type PaperGenerator struct {
	aiClient AIClient
}

type GeneratePaperRequest struct {
	Subject    string
	Unit       string
	Difficulty int
	QuestionCount int
}

type PaperQuestion struct {
	Question string `json:"question"`
	Answer   string `json:"answer"`
	Points   int    `json:"points"`
	Type     string `json:"type"`
}

func NewPaperGenerator(aiClient AIClient) *PaperGenerator {
	return &PaperGenerator{aiClient: aiClient}
}

func (g *PaperGenerator) GeneratePaper(ctx context.Context, req GeneratePaperRequest) ([]PaperQuestion, error) {
	if req.QuestionCount <= 0 {
		req.QuestionCount = 10
	}
	if req.Difficulty <= 0 {
		req.Difficulty = 5
	}

	prompt := fmt.Sprintf(`生成%s试卷，要求：
- 单元：%s
- 难度：%d/10（高考标准）
- 题目数量：%d
- 题型分布：选择题40%%、填空题30%%、解答题30%%

返回JSON数组：
[{"question":"题目","answer":"答案","points":分值,"type":"选择/填空/解答"}]`,
		req.Subject, req.Unit, req.Difficulty, req.QuestionCount)

	resp, err := g.aiClient.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return nil, err
	}

	return g.parsePaper(resp.Content)
}

func (g *PaperGenerator) parsePaper(content string) ([]PaperQuestion, error) {
	content = strings.TrimSpace(content)
	if idx := strings.Index(content, "["); idx >= 0 {
		content = content[idx:]
	}
	if idx := strings.LastIndex(content, "]"); idx >= 0 {
		content = content[:idx+1]
	}

	var questions []PaperQuestion
	if err := json.Unmarshal([]byte(content), &questions); err != nil {
		return nil, fmt.Errorf("parse paper: %w", err)
	}
	return questions, nil
}
