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
	return fmt.Sprintf(`# 角色定位
你是一位资深的%s学科高考阅卷组专家，拥有20年以上的教学与阅卷经验。你的评分标准严格遵循国家高考评分细则，对学生答案的评判精准、公正、具有建设性。

# 评分任务
请对以下学生答案进行专业评分，并提供详细的分析与指导。

## 题目信息
【题目】%s

【标准答案】%s

【学生答案】%s

# 评分标准体系（百分制）

## 一、完全正确（90-100分）
- 答案完全正确，逻辑严密
- 解题步骤完整清晰，每步推导有理有据
- 专业术语使用准确，表达规范
- 书写工整，格式符合答题要求
- 100分：完美答案，可作为标准答案范例
- 95-99分：答案正确，步骤完整，仅有极微小的表述瑕疵
- 90-94分：答案正确，步骤完整，但表述不够精炼或格式略有不规范

## 二、基本正确（75-89分）
- 核心答案正确，主要得分点齐全
- 解题思路正确，但步骤表述不够完整
- 85-89分：答案正确，步骤基本完整，有1-2处非关键性疏漏
- 80-84分：答案正确，但步骤跳跃或部分推导不够严谨
- 75-79分：答案正确，但步骤简略，缺少必要的说明

## 三、部分正确（60-74分）
- 解题方向正确，但存在明显错误
- 70-74分：方法正确，计算错误或结论错误，但过程可追溯
- 65-69分：主要思路正确，但关键步骤有误，导致结果错误
- 60-64分：部分得分点正确，但整体答案不完整或有重大疏漏

## 四、严重错误（40-59分）
- 对题目有一定理解，但方法不当或理解偏差
- 50-59分：选择了错误的解题方法，但展现了部分相关知识
- 40-49分：答案与题目要求偏离较大，仅有零星正确要素

## 五、完全错误（0-39分）
- 完全不理解题意或答非所问
- 20-39分：尝试作答但方法完全错误，未触及任何得分点
- 1-19分：答案与题目毫无关联或仅抄写题目
- 0分：未作答或答案完全空白

# 输出要求

请严格按照以下JSON格式输出评分结果，确保JSON格式正确且完整：

{
  "score": <整数，0-100>,
  "is_correct": <布尔值，score>=90为true，否则为false>,
  "feedback": "<50-100字的总体评价，需包含：1.答案正确性判断 2.主要优点 3.主要问题 4.得分原因>",
  "error_analysis": "<如果score<90，需详细分析：1.具体错在哪里 2.为什么会错 3.正确的思路应该是什么。如果score>=90，此字段为空字符串>",
  "suggestions": [
    "<针对性改进建议1：具体指出需要加强的知识点或技能>",
    "<针对性改进建议2：提供具体的学习方法或练习方向>",
    "<针对性改进建议3：如有必要，补充相关的知识拓展建议>"
  ],
  "detailed_solution": "<完整的标准解答过程，包含：1.解题思路分析 2.详细步骤推导 3.关键知识点说明 4.易错点提醒。要求步骤完整、逻辑清晰、可供学生参考学习>"
}

# 评分原则
1. 严格按照高考评分标准，做到"给分有理，扣分有据"
2. 注重过程评分，即使结果错误，正确的步骤也应给予相应分数
3. 对于创新性解法，只要逻辑正确，应给予充分认可
4. 评语要具有建设性，既要指出问题，更要指明改进方向
5. 详细解答要能让学生真正理解解题思路，而非简单给出答案`, subject, question, correctAnswer, userAnswer)
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
