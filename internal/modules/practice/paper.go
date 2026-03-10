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

	prompt := fmt.Sprintf(`# 角色定位
你是一位资深的%s学科命题专家，具有多年高考命题与教学经验。你深谙考试大纲要求，能够精准把握知识点考查深度，出题严谨、科学、具有区分度。

# 组卷任务
请根据以下要求，生成一套高质量的%s单元测试卷。

## 组卷参数
- **考查单元**：%s
- **难度等级**：%d/10（1-3基础，4-6中等，7-8较难，9-10极难，对标高考难度分布）
- **题目总数**：%d道
- **题型分布**：选择题40%%、填空题30%%、解答题30%%

## 难度等级说明
- **1-3级（基础）**：考查基本概念、基础知识，学生掌握后应能轻松作答
- **4-6级（中等）**：考查知识应用、综合理解，需要一定思考和计算
- **7-8级（较难）**：考查知识迁移、综合分析，需要较强的逻辑推理能力
- **9-10级（极难）**：考查创新思维、深度理解，对标高考压轴题难度

# 命题要求

## 1. 知识点覆盖
- 紧扣"%s"单元核心知识点
- 题目应覆盖本单元的重点、难点、易错点
- 避免超纲或偏离单元主题

## 2. 难度分布（重要）
根据指定难度等级%d/10，合理分配各题难度：
- 难度1-3：基础题占70%%，中等题占30%%
- 难度4-6：基础题占30%%，中等题占50%%，较难题占20%%
- 难度7-8：中等题占40%%，较难题占50%%，极难题占10%%
- 难度9-10：较难题占40%%，极难题占60%%

## 3. 题型要求

### 选择题（40%%）
- 每题4个选项（A/B/C/D），有且仅有1个正确答案
- 选项设置要有迷惑性，能考查学生对概念的精准理解
- 避免明显错误选项，确保题目有区分度
- 分值：每题5分

### 填空题（30%%）
- 答案应简洁明确，避免歧义
- 可设置多空题，但每空答案应独立可判
- 重点考查计算能力、公式应用、概念理解
- 分值：每空3-5分

### 解答题（30%%）
- 需要完整的解题过程和推导步骤
- 设置合理的分步得分点
- 考查综合分析、逻辑推理、问题解决能力
- 分值：每题10-20分

## 4. 质量标准
- **科学性**：题目表述准确，答案唯一且正确
- **规范性**：符合学科术语规范和答题格式要求
- **原创性**：避免直接照搬教材例题或常见题目
- **适切性**：难度与学生认知水平相匹配
- **完整性**：每道题必须包含完整的标准答案

# 输出格式

请严格按照以下JSON数组格式输出，确保JSON格式正确：

[
  {
    "question": "<完整题目，包含题干、选项（如有）、问题要求>",
    "answer": "<标准答案，选择题给出正确选项及解析，填空题给出答案，解答题给出完整解题步骤>",
    "points": <整数，该题分值>,
    "type": "<题型：选择/填空/解答>"
  },
  ...
]

# 示例（仅供参考格式）

[
  {
    "question": "【选择题】下列关于...的说法，正确的是（  ）\nA. ...\nB. ...\nC. ...\nD. ...",
    "answer": "C。解析：...",
    "points": 5,
    "type": "选择"
  },
  {
    "question": "【填空题】已知...，则...的值为______。",
    "answer": "答案：...\n解析：...",
    "points": 5,
    "type": "填空"
  },
  {
    "question": "【解答题】（本题满分15分）\n已知...，求证：...",
    "answer": "解：\n（1）...\n（2）...\n（3）...\n综上所述，...",
    "points": 15,
    "type": "解答"
  }
]

# 注意事项
1. 题目总数必须严格等于%d道
2. 题型分布比例必须严格遵守（允许±1道的误差）
3. 总分应在100分左右（允许±10分的误差）
4. 每道题的answer字段必须包含详细解析，不能只给答案
5. 确保JSON格式完全正确，可被程序直接解析`,
		req.Subject, req.Subject, req.Unit, req.Difficulty, req.QuestionCount,
		req.Unit, req.Difficulty, req.QuestionCount)

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

func (g *PaperGenerator) ValidatePaper(questions []PaperQuestion, req GeneratePaperRequest) error {
	if len(questions) != req.QuestionCount {
		return fmt.Errorf("question count mismatch: expected %d, got %d", req.QuestionCount, len(questions))
	}
	totalPoints := 0
	for _, q := range questions {
		if q.Question == "" || q.Answer == "" {
			return fmt.Errorf("invalid question: missing question or answer")
		}
		if q.Points <= 0 {
			return fmt.Errorf("invalid question: points must be positive")
		}
		totalPoints += q.Points
	}
	if totalPoints < 90 || totalPoints > 110 {
		return fmt.Errorf("total points out of range: %d (expected 90-110)", totalPoints)
	}
	return nil
}
