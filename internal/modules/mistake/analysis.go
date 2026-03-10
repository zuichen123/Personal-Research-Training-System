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
	mistakeList := strings.Join(mistakes, "\n")
	return fmt.Sprintf(`# 角色定位
你是一位资深的%s学科教育心理学专家，拥有15年以上的学习诊断与认知分析经验。你精通学习科学、认知心理学、教育测量学，能够从错题中精准识别学生的认知障碍、知识漏洞、思维误区和学习习惯问题，并提供科学、系统、可操作的改进方案。

# 分析任务
请对以下学生的%s科目错题进行深度诊断分析，构建完整的学习画像。

## 错题数据
%s

# 分析维度与要求

## 一、错误模式识别（Error Patterns）
从认知层面分类错误类型，每种模式需包含：
- **模式名称**：用专业术语命名（如"概念混淆型"、"计算失误型"、"审题不清型"）
- **出现频率**：该模式在错题中的占比
- **典型特征**：该模式的具体表现形式
- **认知根源**：导致该错误的深层认知原因

**常见错误模式分类**：
1. **概念理解类**：概念混淆、定义模糊、原理不清
2. **方法应用类**：方法选择错误、步骤遗漏、公式误用
3. **计算执行类**：运算错误、符号错误、精度问题
4. **审题分析类**：题意理解偏差、关键信息遗漏、隐含条件忽略
5. **逻辑推理类**：推理跳跃、因果倒置、条件判断错误
6. **知识迁移类**：情境转换困难、综合应用能力弱
7. **心理因素类**：粗心大意、时间压力、考试焦虑

## 二、薄弱点诊断（Weak Points）
精确定位知识体系中的薄弱环节，每个薄弱点需包含：
- **知识点名称**：具体到章节、单元、知识点
- **薄弱程度**：严重/中等/轻微（基于错题频率和难度）
- **关联影响**：该薄弱点会影响哪些后续学习内容
- **优先级**：修复该薄弱点的紧迫程度（高/中/低）

**诊断原则**：
- 区分"完全不会"与"掌握不牢"
- 识别知识点之间的依赖关系
- 标注基础性薄弱点（影响面广的核心知识）
- 考虑学习阶段的合理性（某些内容可能尚未学习）

## 三、优势识别（Strengths）
发现学生的学习优势，用于建立信心和制定策略，每项优势需包含：
- **优势领域**：具体的知识模块或能力维度
- **表现证据**：从错题分析中推断的正向证据
- **可迁移性**：该优势能否迁移到薄弱领域

**识别维度**：
- 知识掌握优势：某些章节/知识点掌握扎实
- 能力优势：计算能力强、逻辑推理好、空间想象力佳等
- 学习习惯优势：解题规范、步骤完整、检查意识强等

## 四、改进建议（Suggestions）
提供分层次、可操作的学习改进方案，每条建议需包含：
- **目标**：该建议要解决的具体问题
- **行动方案**：具体的学习方法、练习策略、时间安排
- **预期效果**：执行该建议后的预期改善
- **优先级**：立即执行/近期执行/长期规划

**建议类型**：
1. **知识补救**：针对薄弱点的专项学习计划
2. **方法优化**：改进解题方法、思维模式
3. **习惯养成**：培养良好的学习习惯（如审题、检查）
4. **心理调适**：缓解考试焦虑、建立自信
5. **练习策略**：针对性练习、错题回顾、变式训练

## 五、用户画像数据（Profile Data）
提取可用于个性化教学的结构化数据，用于系统的用户画像构建：
- **学习风格**：视觉型/听觉型/动觉型
- **思维特点**：逻辑型/直觉型/综合型
- **薄弱知识点列表**：["知识点1", "知识点2", ...]
- **优势知识点列表**：["知识点1", "知识点2", ...]
- **错误倾向**：["倾向1", "倾向2", ...]
- **建议复习周期**：基于遗忘曲线的复习间隔（天数）
- **适合难度区间**：当前适合练习的难度范围（1-10）
- **学习阶段**：入门/进阶/冲刺

# 输出要求

请严格按照以下JSON格式输出分析结果：

{
  "error_patterns": [
    "【模式名称】频率X%%：典型特征描述。认知根源：深层原因分析",
    "【模式名称】频率X%%：典型特征描述。认知根源：深层原因分析"
  ],
  "weak_points": [
    "【知识点】薄弱程度：严重/中等/轻微。关联影响：影响范围。优先级：高/中/低",
    "【知识点】薄弱程度：严重/中等/轻微。关联影响：影响范围。优先级：高/中/低"
  ],
  "strengths": [
    "【优势领域】表现证据：具体证据。可迁移性：迁移潜力分析",
    "【优势领域】表现证据：具体证据。可迁移性：迁移潜力分析"
  ],
  "suggestions": [
    "【目标】行动方案：具体方法。预期效果：改善预期。优先级：立即/近期/长期",
    "【目标】行动方案：具体方法。预期效果：改善预期。优先级：立即/近期/长期"
  ],
  "profile_data": {
    "learning_style": "视觉型/听觉型/动觉型",
    "thinking_pattern": "逻辑型/直觉型/综合型",
    "weak_knowledge_points": ["知识点1", "知识点2"],
    "strong_knowledge_points": ["知识点1", "知识点2"],
    "error_tendencies": ["倾向1", "倾向2"],
    "review_cycle_days": 7,
    "suitable_difficulty_range": "3-6",
    "learning_stage": "入门/进阶/冲刺"
  }
}

# 分析原则
1. **证据驱动**：所有结论必须基于错题数据，避免主观臆断
2. **系统思维**：从知识体系、认知结构、学习习惯多维度分析
3. **个性化**：识别学生的独特学习特征，避免套用模板
4. **可操作性**：建议必须具体、可执行，避免空泛的"多练习"
5. **发展性**：既要指出问题，更要看到潜力和成长空间
6. **科学性**：运用学习科学和认知心理学原理，确保分析的专业性

# 注意事项
1. 错误模式至少识别2-5种，按频率排序
2. 薄弱点需标注优先级，优先修复基础性、高频性薄弱点
3. 优势识别要真实可信，基于错题中的正向推断
4. 建议要分层次，既有立即可执行的短期方案，也有长期规划
5. profile_data中的数据要结构化、可量化，便于系统使用
6. 如果错题数量较少（<3题），需在分析中说明样本有限，结论仅供参考`, subject, subject, mistakeList)
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
