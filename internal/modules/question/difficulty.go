package question

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
)

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

type DifficultyService struct {
	db       *sql.DB
	aiClient AIClient
}

func NewDifficultyService(db *sql.DB, aiClient AIClient) *DifficultyService {
	return &DifficultyService{db: db, aiClient: aiClient}
}

func (s *DifficultyService) GetRubric(ctx context.Context, subject string) (*DifficultyRubric, error) {
	query := `SELECT id, subject, level, description, criteria FROM difficulty_rubrics WHERE subject = ? ORDER BY level`
	rows, err := s.db.QueryContext(ctx, query, subject)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	rubric := &DifficultyRubric{Subject: subject, Levels: make([]DifficultyLevel, 0, 10)}
	for rows.Next() {
		var level DifficultyLevel
		if err := rows.Scan(&level.ID, &level.Subject, &level.Level, &level.Description, &level.Criteria); err != nil {
			return nil, err
		}
		rubric.Levels = append(rubric.Levels, level)
	}
	return rubric, nil
}

func (s *DifficultyService) AssessDifficulty(ctx context.Context, question, subject string) (int, error) {
	prompt := s.buildDifficultyPrompt(subject, question)

	resp, err := s.aiClient.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return 5, err
	}

	return s.parseDifficultyResult(resp.Content)
}

func (s *DifficultyService) buildDifficultyPrompt(subject, question string) string {
	return fmt.Sprintf(`# 角色定位
你是一位资深的%s学科高考命题与难度评估专家，拥有20年以上的命题、阅卷与试题分析经验。你精通高考命题规律、考查目标、能力层级划分，能够精准评估试题的认知难度、解题复杂度和区分度。

# 评估任务
请对以下%s试题进行专业的难度评估，给出1-10级的难度等级。

## 试题内容
%s

# 难度分级标准（10级制，对标高考）

## 难度等级定义

### 1-3级：基础题（高考前3道选择题难度）
**认知要求**：识记、理解基本概念和原理
**解题特征**：
- 直接考查单一知识点，无需综合
- 题干简洁明了，信息直给
- 解题步骤1-2步，思维路径单一
- 正确率应在85%%以上
**典型题型**：概念判断、公式直接应用、基础计算

**1级**：纯识记，教材原话或定义直接复现
**2级**：简单理解，需要对概念进行基本解释或简单计算
**3级**：基础应用，单一知识点的直接套用，略有变化

### 4-6级：中等题（高考中档题难度）
**认知要求**：应用、分析，需要一定的知识整合能力
**解题特征**：
- 考查2-3个知识点的综合运用
- 题干信息需要提取和整理
- 解题步骤3-5步，需要选择合适方法
- 正确率应在50-70%%
**典型题型**：综合计算、简单证明、情境分析

**4级**：简单综合，2个知识点的直接组合，方法明确
**5级**：标准综合，需要分析题意，选择解题策略
**6级**：复杂综合，多步骤推理，需要较强的逻辑思维

### 7-8级：较难题（高考压轴题前半部分难度）
**认知要求**：综合分析、知识迁移、创新应用
**解题特征**：
- 考查3个以上知识点的深度综合
- 题干信息隐蔽，需要深度挖掘
- 解题步骤5-8步，需要构建解题模型
- 正确率应在20-40%%
**典型题型**：复杂证明、综合应用、模型构建

**7级**：知识迁移，需要将知识应用到新情境
**8级**：深度综合，需要构建完整的解题思路，多角度分析

### 9-10级：极难题（高考压轴题最后一问难度）
**认知要求**：创新思维、深度理解、系统构建
**解题特征**：
- 考查学科核心素养和思维能力
- 题干信息复杂，需要多层次分析
- 解题步骤8步以上，需要创新性思维
- 正确率应在5-15%%
**典型题型**：压轴大题、创新探究、开放性问题

**9级**：高度综合，需要系统性思维和创新方法
**10级**：顶尖难度，需要深刻洞察和突破性思维，对标高考最难题

# 评估维度

## 1. 知识点复杂度
- 单一知识点：1-3级
- 2-3个知识点：4-6级
- 3个以上知识点：7-8级
- 学科核心素养：9-10级

## 2. 认知层次（布鲁姆分类法）
- 识记、理解：1-3级
- 应用、分析：4-6级
- 综合、评价：7-8级
- 创新、构建：9-10级

## 3. 解题步骤
- 1-2步：1-3级
- 3-5步：4-6级
- 5-8步：7-8级
- 8步以上：9-10级

## 4. 思维要求
- 直接套用：1-3级
- 方法选择：4-6级
- 策略构建：7-8级
- 创新突破：9-10级

## 5. 区分度
- 正确率>85%%：1-3级
- 正确率50-70%%：4-6级
- 正确率20-40%%：7-8级
- 正确率<15%%：9-10级

# 输出要求

请严格按照以下JSON格式输出评估结果：

{
  "difficulty_level": <整数，1-10>,
  "confidence": <整数，0-100，表示评估的置信度>,
  "analysis": {
    "knowledge_complexity": "<知识点复杂度分析>",
    "cognitive_level": "<认知层次分析>",
    "solution_steps": <整数，预估解题步骤数>,
    "thinking_requirement": "<思维要求分析>",
    "expected_accuracy": "<预估正确率范围>"
  },
  "justification": "<100-200字的难度判定理由，需说明：1.考查的核心知识点 2.解题的关键难点 3.为什么是这个难度等级>",
  "comparable_questions": "<与高考真题的对比，如：相当于2023年全国卷理科数学第X题>"
}

# 评估原则
1. **客观性**：基于试题本身特征，不受主观偏好影响
2. **精准性**：准确定位难度等级，避免高估或低估
3. **一致性**：同类型、同难度的题目应给出相同评级
4. **参照性**：以高考真题为标杆，确保难度对标准确
5. **全面性**：综合考虑知识、能力、思维、区分度等多维度

# 注意事项
1. 难度评估要考虑目标学生群体（高中生）的认知水平
2. 不要被题目长度迷惑，长题不一定难，短题不一定易
3. 重点关注解题的关键难点和思维障碍
4. 如果题目存在歧义或错误，需在justification中指出
5. confidence低于70时，需在justification中说明不确定的原因`, subject, subject, question)
}

func (s *DifficultyService) parseDifficultyResult(content string) (int, error) {
	content = strings.TrimSpace(content)
	if idx := strings.Index(content, "{"); idx >= 0 {
		content = content[idx:]
	}
	if idx := strings.LastIndex(content, "}"); idx >= 0 {
		content = content[:idx+1]
	}

	var result struct {
		DifficultyLevel int `json:"difficulty_level"`
		Confidence      int `json:"confidence"`
	}
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		return 5, fmt.Errorf("parse difficulty result: %w", err)
	}

	if result.DifficultyLevel < 1 || result.DifficultyLevel > 10 {
		return 5, fmt.Errorf("invalid difficulty level: %d", result.DifficultyLevel)
	}

	return result.DifficultyLevel, nil
}

type DifficultyRubric struct {
	Subject string
	Levels  []DifficultyLevel
}

type DifficultyLevel struct {
	ID          int64
	Subject     string
	Level       int
	Description string
	Criteria    string
}
