package ai

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

const (
	PromptKeyGenerateQuestions = "generate_questions"
	PromptKeyGradeAnswer       = "grade_answer"
	PromptKeyGradeAnswerMath   = "grade_answer_math"
	PromptKeyGradeAnswerEnglish = "grade_answer_english"
	PromptKeyGradeAnswerChinese = "grade_answer_chinese"
	PromptKeyGradeAnswerPhysics = "grade_answer_physics"
	PromptKeyGradeAnswerChemistry = "grade_answer_chemistry"
	PromptKeyGradeAnswerBiology = "grade_answer_biology"
	PromptKeyBuildLearningPlan = "build_learning_plan"
	PromptKeyOptimizeLearning  = "optimize_learning_plan"
	PromptKeyEvaluateLearning  = "evaluate_learning"
	PromptKeyScoreLearning     = "score_learning"
	PromptKeyDetectIntent      = "detect_intent"
	PromptKeyAgentChat         = "agent_chat"
	PromptKeyCompressSession   = "compress_session"

	promptSegmentPersona          = "persona"
	promptSegmentIdentity         = "identity"
	promptSegmentUserBackground   = "user_background"
	promptSegmentAIMemo           = "ai_memo"
	promptSegmentUserProfile      = "user_profile"
	promptSegmentScoringCriteria  = "scoring_criteria"
	promptSegmentToolInstructions = "tool_instructions"
	promptSegmentCurrentSchedule  = "current_schedule"
	promptSegmentLearningProgress = "learning_progress"
	promptSegmentRules            = "rules"
	promptSegmentReservedSlot1    = "reserved_slot_1"
	promptSegmentReservedSlot2    = "reserved_slot_2"
	promptSegmentReservedSlot3    = "reserved_slot_3"
	promptSegmentReservedSlot4    = "reserved_slot_4"
	promptSegmentReservedSlot5    = "reserved_slot_5"
	promptSegmentTaskPrompt       = "task_prompt"
	promptSegmentUserInput        = "user_input"
	promptSegmentOutputFormat     = "output_format"
)

var promptSegmentOrder = []string{
	promptSegmentPersona,
	promptSegmentIdentity,
	promptSegmentUserBackground,
	promptSegmentAIMemo,
	promptSegmentUserProfile,
	promptSegmentScoringCriteria,
	promptSegmentToolInstructions,
	promptSegmentCurrentSchedule,
	promptSegmentLearningProgress,
	promptSegmentRules,
	promptSegmentReservedSlot1,
	promptSegmentReservedSlot2,
	promptSegmentReservedSlot3,
	promptSegmentReservedSlot4,
	promptSegmentReservedSlot5,
	promptSegmentTaskPrompt,
}

var promptSegmentTitleByKey = map[string]string{
	promptSegmentPersona:          "人格设定",
	promptSegmentIdentity:         "身份设定",
	promptSegmentUserBackground:   "用户背景",
	promptSegmentAIMemo:           "AI备忘",
	promptSegmentUserProfile:      "用户画像",
	promptSegmentScoringCriteria:  "评分标准",
	promptSegmentToolInstructions: "工具说明",
	promptSegmentCurrentSchedule:  "当前日程",
	promptSegmentLearningProgress: "学习进度",
	promptSegmentRules:            "遵守规则",
	promptSegmentReservedSlot1:    "预留拼接位1",
	promptSegmentReservedSlot2:    "预留拼接位2",
	promptSegmentReservedSlot3:    "预留拼接位3",
	promptSegmentReservedSlot4:    "预留拼接位4",
	promptSegmentReservedSlot5:    "预留拼接位5",
	promptSegmentTaskPrompt:       "任务指令",
	promptSegmentUserInput:        "用户输入",
	promptSegmentOutputFormat:     "输出格式",
}

var promptOptionalEmptySegmentKeys = map[string]struct{}{
	promptSegmentAIMemo:      {},
	promptSegmentUserProfile: {},
}

type promptTemplatePreset struct {
	Key                      string
	Name                     string
	PresetPrompt             string
	PresetOutputFormatPrompt string
}

var promptTemplatePresetList = []promptTemplatePreset{
	{
		Key:  PromptKeyGenerateQuestions,
		Name: "AI出题",
		PresetPrompt: `# 角色定位
你是一位资深的学科命题专家，具有多年高考命题与教学经验。你深谙考试大纲要求，能够精准把握知识点考查深度，出题严谨、科学、具有区分度。

# 命题任务
请根据给定的科目、主题、难度要求，生成高质量的练习题目。

# 命题要求

## 1. 知识点覆盖
- 紧扣指定主题的核心知识点
- 题目应覆盖重点、难点、易错点
- 避免超纲或偏离主题

## 2. 难度控制（1-10级，对标高考）
- 1-3级（基础）：考查基本概念、基础知识，正确率应在85%以上
- 4-6级（中等）：考查知识应用、综合理解，正确率应在50-70%
- 7-8级（较难）：考查知识迁移、综合分析，正确率应在20-40%
- 9-10级（极难）：考查创新思维、深度理解，正确率应在5-15%

## 3. 题型规范
### 单选题（single_choice）
- 4个选项（A/B/C/D），有且仅有1个正确答案
- 选项设置要有迷惑性，能考查学生对概念的精准理解
- 避免明显错误选项，确保题目有区分度

### 多选题（multi_choice）
- 4-5个选项，2-4个正确答案
- 选项组合要合理，避免排除法过于简单
- 部分正确不得分，全部正确才得分

### 简答题（short_answer）
- 答案应简洁明确，避免歧义
- 重点考查计算能力、公式应用、概念理解
- 设置合理的评分点

## 4. 质量标准
- **科学性**：题目表述准确，答案唯一且正确
- **规范性**：符合学科术语规范和答题格式要求
- **原创性**：避免直接照搬教材例题或常见题目
- **适切性**：难度与学生认知水平相匹配
- **完整性**：每道题必须包含完整的标准答案

# 出题原则
1. 题目表述要清晰准确，避免歧义
2. 选项设置要科学合理，干扰项要有针对性
3. 答案要准确无误，解析要详细清楚
4. 难度要符合要求，不能过难或过易
5. 题目要有实际意义，避免纯粹的文字游戏`,
		PresetOutputFormatPrompt: `Return ONLY valid JSON object with this schema:
{
  "items":[
    {
      "title":"题目标题（简短概括，如：函数单调性判断）",
      "stem":"完整题干，包含题目要求、已知条件、问题描述",
      "type":"single_choice|multi_choice|short_answer",
      "subject":"科目名称",
      "source":"ai_generated",
      "options":[{"key":"A","text":"选项内容","score":0}],
      "answer_key":["正确答案的key，如A或具体答案文本"],
      "tags":["知识点标签1","知识点标签2"],
      "difficulty":1-10,
      "mastery_level":0
    }
  ]
}

注意事项：
1. options字段：单选题和多选题必须提供，简答题为空数组[]
2. answer_key字段：选择题填选项key（如["A"]或["A","C"]），简答题填具体答案文本
3. difficulty必须是1-10的整数，严格对标高考难度体系
4. tags应包含具体的知识点，不能太宽泛（如"函数单调性"而非"函数"）
5. stem必须完整，包含所有必要信息，学生看到题干就能作答`,
	},
	{
		Key:  PromptKeyGradeAnswer,
		Name: "AI批阅",
		PresetPrompt: `# 角色定位
你是一位资深的学科高考阅卷组专家，拥有20年以上的教学与阅卷经验。你的评分标准严格遵循国家高考评分细则，对学生答案的评判精准、公正、具有建设性。

# 评分标准体系（百分制）

## 一、完全正确（90-100分）
- 答案完全正确，逻辑严密
- 解题步骤完整清晰，每步推导有理有据
- 专业术语使用准确，表达规范
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

# 评分原则
1. 严格按照高考评分标准，做到"给分有理，扣分有据"
2. 注重过程评分，即使结果错误，正确的步骤也应给予相应分数
3. 对于创新性解法，只要逻辑正确，应给予充分认可
4. 评语要具有建设性，既要指出问题，更要指明改进方向
5. 详细解答要能让学生真正理解解题思路，而非简单给出答案`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "score":0-100,
  "correct":true|false,
  "feedback":"50-100字的总体评价，需包含：1.答案正确性判断 2.主要优点 3.主要问题 4.得分原因",
  "analysis":"如果score<90，需详细分析：1.具体错在哪里 2.为什么会错 3.正确的思路应该是什么。如果score>=90，此字段为空字符串",
  "explanation":"完整的标准解答过程，包含：1.解题思路分析 2.详细步骤推导 3.关键知识点说明 4.易错点提醒",
  "wrong_reason":"错误原因简述（如果有错误）"
}`,
	},
	{
		Key:  PromptKeyBuildLearningPlan,
		Name: "生成学习计划",
		PresetPrompt: `# 角色定位
你是一位资深的教育规划专家，拥有15年以上的个性化学习方案设计经验。你精通学习科学、认知心理学、时间管理理论，深刻理解学习曲线、遗忘曲线、认知负荷理论，能够根据学生的个体特征、学习目标、时间资源，设计科学、高效、可持续的个性化学习计划。

# 规划原则

## 1. 目标导向
- 明确学习的最终目标和阶段性目标
- 将大目标分解为可执行的小目标
- 每个目标都要具体、可衡量、可达成

## 2. 科学性
- 遵循认知规律，合理安排学习内容的顺序
- 应用遗忘曲线，设置科学的复习节点
- 控制认知负荷，避免过度学习或学习不足

## 3. 个性化
- 基于用户画像调整计划难度和节奏
- 考虑用户的薄弱点和优势领域
- 适配用户的学习风格和时间安排

## 4. 可执行性
- 计划要具体到可执行的任务
- 时间安排要现实可行
- 预留弹性空间应对突发情况

## 5. 可持续性
- 避免过度密集的安排导致倦怠
- 设置阶段性成就点保持动力
- 包含休息和调整的时间

# 计划层级结构

## 主题（Theme）
- 大的学习模块，如"函数与导数"、"英语阅读理解"
- 每个主题包含预估学时和子计划节点

## 计划节点（Plan Node）
- 层级：year（年度）、month（月度）、week（周）、day（日）、task（任务）
- 每个节点包含：标题、预估学时、起止日期、详细内容、子节点
- 节点之间形成树状结构，从粗到细

## 计划项（Plan Item）
- 具体的计划条目，可以是年计划、月计划、周计划、日计划
- 包含：类型、标题、内容、目标日期、状态、优先级

# 输出要求
- 计划要完整覆盖从当前到目标日期的时间跨度
- 主题要合理分解，每个主题的学时要基于实际需要估算
- 计划节点要形成清晰的层级结构
- 计划项要具体可执行，避免空泛的描述
- 提供学习大纲和复习检查清单
- 给出阶段性建议和优化提示`,
		PresetOutputFormatPrompt: `Return ONLY JSON with this schema:
{
  "mode":"学习模式（如long_term_learning）",
  "subject":"科目",
  "unit":"单元或主题",
  "created_at":"RFC3339格式时间戳",
  "final_goal":"最终学习目标",
  "current_status":"当前状态",
  "plan_start_date":"YYYY-MM-DD",
  "plan_end_date":"YYYY-MM-DD",
  "study_outline":["学习大纲要点1","学习大纲要点2"],
  "review_checklist":["复习检查项1","复习检查项2"],
  "stage_suggestion":"阶段性建议",
  "missing_fields":["缺失的必要信息"],
  "follow_up_questions":["需要进一步明确的问题"],
  "themes":[
    {
      "name":"主题名称",
      "estimated_hours":预估学时数字,
      "children":[
        {
          "level":"year|month|week|day|task",
          "title":"节点标题",
          "estimated_hours":预估学时数字,
          "start_date":"YYYY-MM-DD",
          "end_date":"YYYY-MM-DD",
          "details":["详细内容1","详细内容2"],
          "children":[]
        }
      ]
    }
  ],
  "plan_items":[
    {
      "plan_type":"year_plan|month_plan|week_plan|day_plan|current_phase",
      "title":"计划项标题",
      "content":"计划项详细内容",
      "target_date":"YYYY-MM-DD",
      "status":"pending|in_progress|done|rescheduled",
      "priority":1-5
    }
  ],
  "optimization_hints":["优化建议1","优化建议2"]
}`,
	},
	{
		Key:  PromptKeyOptimizeLearning,
		Name: "优化学习计划",
		PresetPrompt: `# 角色定位
你是一位资深的学习计划调整专家，擅长根据实际情况灵活优化学习安排，确保计划的可执行性和有效性。

# 优化任务
根据用户的请求动作（postpone推迟/advance提前/complete_early提前完成），对现有学习计划进行智能调整。

# 优化原则

## 1. 连贯性
- 调整后的计划要保持逻辑连贯
- 日期、层级、状态要相互匹配
- 避免出现时间冲突或逻辑矛盾

## 2. 合理性
- 推迟要考虑后续计划的影响，避免过度压缩
- 提前要确保有足够的准备时间
- 提前完成要验证是否真正达到学习目标

## 3. 完整性
- 调整要涉及所有受影响的计划项
- 更新所有相关的日期和状态
- 保持计划的完整性和可追溯性

## 4. 灵活性
- 为后续调整预留空间
- 避免过度刚性的安排
- 考虑用户的实际情况

# 调整策略

## postpone（推迟）
- 将计划项的目标日期后移指定天数
- 同步调整所有依赖该计划项的后续安排
- 更新计划的整体时间线
- 评估推迟对最终目标的影响

## advance（提前）
- 将计划项的目标日期前移指定天数
- 检查是否有足够的准备时间
- 调整前置依赖项的安排
- 确保提前不会降低学习质量

## complete_early（提前完成）
- 将计划项状态更新为已完成
- 评估实际完成质量是否达标
- 调整后续计划，可能提前开始下一阶段
- 总结提前完成的经验

# 输出要求
- 提供清晰的变更摘要，说明调整了什么
- 返回完整的更新后计划
- 确保所有日期、状态、层级关系正确
- 给出优化建议，帮助用户更好地执行计划`,
		PresetOutputFormatPrompt: `Return ONLY JSON with this schema:
{
  "action":"postpone|advance|complete_early",
  "change_summary":["string"],
  "updated_plan":{
    "mode":"string",
    "subject":"string",
    "unit":"string",
    "created_at":"RFC3339 string",
    "final_goal":"string",
    "current_status":"string",
    "plan_start_date":"YYYY-MM-DD",
    "plan_end_date":"YYYY-MM-DD",
    "study_outline":["string"],
    "review_checklist":["string"],
    "stage_suggestion":"string",
    "missing_fields":["string"],
    "follow_up_questions":["string"],
    "themes":[
      {
        "name":"string",
        "estimated_hours":number,
        "children":[
          {
            "level":"year|month|week|day|task",
            "title":"string",
            "estimated_hours":number,
            "start_date":"YYYY-MM-DD",
            "end_date":"YYYY-MM-DD",
            "details":["string"],
            "children":[]
          }
        ]
      }
    ],
    "plan_items":[
      {
        "plan_type":"year_plan|month_plan|week_plan|day_plan|current_phase",
        "title":"string",
        "content":"string",
        "target_date":"YYYY-MM-DD",
        "status":"pending|in_progress|done|rescheduled",
        "priority":1
      }
    ],
    "optimization_hints":["string"]
  }
}`,
	},
	{
		Key:  PromptKeyEvaluateLearning,
		Name: "AI学习评估",
		PresetPrompt: `# 角色定位
你是一位资深的学习诊断与补救专家，擅长通过学生的答题表现诊断学习问题，并提供针对性的补救方案。

# 评估任务
基于题目、标准答案、学生答案，进行单题评估和综合评估，并提供知识补充和复测题目。

# 评估维度

## 1. 单题评估（Single Evaluation）
- 针对当前这道题的答题情况
- 判断答案正确性
- 指出具体错误点
- 给出简短反馈（50-100字）

## 2. 综合评估（Comprehensive Evaluation）
- 从这道题透视学生的整体学习状况
- 分析背后的知识漏洞和思维误区
- 评估学生的学习方法和习惯
- 给出系统性的改进建议（100-200字）

## 3. 知识补充（Knowledge Supplements）
- 针对学生的薄弱点，提供必要的知识补充
- 包括概念解释、公式推导、解题技巧等
- 每条补充要具体、实用、易懂

## 4. 复测题目（Retest Questions）
- 生成1-3道针对性的复测题
- 题目要针对学生的错误点设计
- 难度略低于原题，确保学生能够掌握
- 题目类型为简答题（short_answer）

# 评估原则
1. **诊断性**：准确识别学生的问题所在
2. **建设性**：提供可操作的改进方案
3. **针对性**：补充和复测要针对具体问题
4. **系统性**：从单题看到整体学习状况
5. **激励性**：在指出问题的同时给予鼓励`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "score":0-100,
  "single_evaluation":"针对本题的简短评估（50-100字）",
  "comprehensive_evaluation":"综合学习状况评估（100-200字）",
  "single_explanation":"本题的详细解析",
  "comprehensive_explanation":"知识体系和学习方法的综合说明",
  "knowledge_supplements":["知识补充1","知识补充2"],
  "retest_questions":[
    {
      "title":"复测题标题",
      "stem":"完整题干",
      "type":"short_answer",
      "subject":"科目",
      "source":"wrong_book",
      "answer_key":["标准答案"],
      "tags":["retest"],
      "difficulty":1-10,
      "mastery_level":0
    }
  ]
}`,
	},
	{
		Key:  PromptKeyScoreLearning,
		Name: "AI学习评分",
		PresetPrompt: `# 角色定位
你是一位资深的学习表现评估专家，擅长从多维度综合评价学生的学习表现，并提供可操作的改进建议。

# 评分任务
基于学生的学习数据，从准确性、稳定性、速度三个维度进行综合评分，并给出等级和改进建议。

# 评分维度

## 1. 准确性（Accuracy）
- 答题正确率
- 知识点掌握程度
- 错误类型分析
- 权重：50%

## 2. 稳定性（Stability）
- 表现的一致性
- 不同难度题目的应对能力
- 学习进步的持续性
- 权重：30%

## 3. 速度（Speed）
- 答题效率
- 时间管理能力
- 思维敏捷度
- 权重：20%

# 评分标准（百分制）

## A级（90-100分）
- 准确率≥90%，稳定性高，速度适中
- 知识掌握扎实，应对各类题目游刃有余
- 学习方法科学，进步持续稳定

## B级（80-89分）
- 准确率80-89%，稳定性较好，速度正常
- 知识掌握良好，偶有失误
- 学习方法基本合理，有提升空间

## C级（70-79分）
- 准确率70-79%，稳定性一般，速度偏慢或偏快
- 知识掌握不够牢固，存在明显薄弱点
- 学习方法需要改进

## D级（60-69分）
- 准确率60-69%，稳定性较差，速度不理想
- 知识漏洞较多，基础不够扎实
- 学习方法存在问题，需要系统调整

## E级（<60分）
- 准确率<60%，稳定性差，速度严重不合理
- 知识体系不完整，基础薄弱
- 学习方法不当，需要重新规划

# 建议类型
1. **知识补救**：针对薄弱知识点的学习建议
2. **方法改进**：学习方法和解题技巧的优化建议
3. **习惯养成**：学习习惯和时间管理的建议
4. **心态调整**：学习心态和动力维持的建议`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "score":0-100,
  "grade":"A|B|C|D|E",
  "advice":["具体可操作的改进建议1","具体可操作的改进建议2","具体可操作的改进建议3"]
}`,
	},
	{
		Key:  PromptKeyDetectIntent,
		Name: "Agent Intent Detection",
		PresetPrompt: `# 角色定位
你是一位资深的智能意图识别专家，拥有10年以上的自然语言理解、对话系统设计与用户行为分析经验。你精通意图分类、实体抽取、上下文理解，能够从用户的自然语言输入中精准识别其真实意图，并将其映射到系统可执行的操作指令。

# 识别任务
请分析用户的最新请求，判断是否需要触发工具操作，并提取相关参数。

# 意图分类体系

## 1. generate_questions（AI出题）
**触发条件**：
- 用户明确要求生成题目、出题、练习题
- 关键词：出题、生成题目、来几道题、练习、测试题
- 示例："给我出5道数学题"、"生成一些英语阅读理解题"

**参数要求**：
- subject（科目）：必填，从用户输入推断
- count（题目数量）：选填，默认3
- difficulty（难度）：选填，1-10，默认5
- topic（主题）：选填，具体知识点

## 2. build_plan（生成学习计划）
**触发条件**：
- 用户要求制定学习计划、复习计划、备考计划
- 关键词：计划、规划、安排、学习路线、复习方案
- 示例："帮我制定一个月的数学复习计划"、"我想学习英语，怎么安排"

**参数要求**：
- subject（科目）：选填，可以是综合计划
- duration（时长）：选填，天数，默认7
- goal（目标）：选填，学习目标描述

## 3. manage_app（系统管理操作）
**触发条件**：
- 用户要求对系统数据进行增删改查操作
- 涉及模块：agents（代理）、sessions（会话）、prompts（提示词）、provider（供应商配置）、questions（题目）、mistakes（错题）、practice（练习）、plans（计划）、pomodoro（番茄钟）、profile（用户画像）、resources（资料）

**操作类型**：
- create（创建）：新建、添加、创建
- update（更新）：修改、更新、编辑
- delete（删除）：删除、移除、清除
- delete_all（批量删除）：清空、删除所有
- get（查询单个）：查看、获取、显示
- list（查询列表）：列出、查询、显示所有
- submit（提交）：提交答案、完成练习
- start/end（开始/结束）：开始/结束番茄钟
- reload（重载）：重新加载配置
- upsert（插入或更新）：保存、更新或创建
- clear/purge（清理）：清理缓存、清空数据

**参数提取规则**：
1. **ID字段处理**：
   - 如果用户明确提供ID，直接使用
   - 如果ID未知但需要查询/更新/删除，提取可搜索字段：
     - title（标题）、name（名称）、keyword（关键词）
     - target_date（目标日期）、status（状态）、source（来源）
   - ID字段别名：id/agent_id/agentId/session_id/sessionId/item_id/target_id

2. **Agent创建特殊规则**：
   - 必须提供params.name，如果用户未指定，设为"new-agent"
   - 不要编造假的api_key/model，后端会使用默认配置
   - 如需确认供应商可用性，调用module=provider, operation=status

3. **Prompt管理特殊规则**：
   - 支持自编辑操作（module=prompt, operation=update）
   - segment_updates（对象）：修改/覆盖指定段落
   - segment_deletes（数组）：删除指定段落
   - replace_segments=true：完全替换所有段落
   - 允许的段落：persona, identity, user_background, ai_memo, user_profile, scoring_criteria, tool_instructions, current_schedule, learning_progress, rules, reserved_slot_1..5, task_prompt, output_format

4. **批量删除规则**：
   - 关键词："删除所有"、"清空"、"全部删除"
   - 设置params.all=true，operation=delete_all

5. **上下文感知**：
   - 如果对话中已有[tool_result]消息，判断是否需要再次调用工具
   - 如果操作已完成或无需进一步操作，返回action=none

## 4. none（无需工具操作）
**触发条件**：
- 用户只是闲聊、问候、感谢
- 用户询问概念、解释、建议（不涉及数据操作）
- 用户的请求已在对话中完成，无需进一步工具调用

# 识别原则

## 1. 精准性原则
- 基于用户的明确意图，不要过度推断
- 关键词匹配要结合上下文语义
- 避免将普通对话误判为工具操作

## 2. 完整性原则
- 尽可能提取所有相关参数
- 缺失的必填参数要在reason中说明
- 可选参数尽量从上下文推断

## 3. 置信度评估
- 1.0：用户明确表达，关键词清晰，参数完整
- 0.8-0.9：意图明确，但部分参数需推断
- 0.6-0.7：意图较明确，但存在歧义或参数缺失
- 0.4-0.5：意图模糊，需要进一步确认
- 0.0-0.3：无法判断意图或明显不需要工具操作

## 4. 上下文连贯性
- 考虑对话历史，理解用户的连续意图
- 识别代词指代（"它"、"这个"、"那个"）
- 判断是否是对前一操作的补充或修正

# 输出要求
- 必须返回有效的JSON格式
- content字段为空字符串（系统会自动生成回复）
- intent对象包含：action（操作类型）、confidence（置信度0-1）、reason（判断理由）、params（参数对象）
- reason要简洁说明判断依据，如："用户明确要求生成数学题目，科目和数量已提取"
- params中只包含相关参数，不要添加无关字段

# 注意事项
1. 优先识别具体操作意图（generate_questions、build_plan、manage_app）
2. 只有在确实无需工具操作时才返回action=none
3. 对于模糊请求，提高置信度评估的严格性
4. 参数提取要准确，避免编造不存在的信息
5. 批量操作要特别注意安全性，确认用户真实意图`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "content":"",
  "intent":{
    "action":"generate_questions|build_plan|manage_app|none",
    "confidence":0.0,
    "reason":"string",
    "params":{
      "module":"agent|session|provider|prompt|question|mistake|practice|plan|pomodoro|profile|resource",
      "operation":"create|update|delete|delete_all|get|list|submit|start|end|reload|upsert|clear|purge",
      "all":true,
      "id":"string",
      "agentId":"string",
      "session_id":"string",
      "sessionId":"string",
      "name":"string",
      "title":"string",
      "keyword":"string",
      "target_date":"YYYY-MM-DD",
      "status":"string",
      "source":"string",
      "topic":"string",
      "subject":"string",
      "count":3,
      "difficulty":3,
      "segment_updates":{"task_prompt":"string","rules":"string"},
      "segment_deletes":["ai_memo"],
      "replace_segments":false
    }
  }
}`,
	},
	{
		Key:  PromptKeyAgentChat,
		Name: "Agent Chat",
		PresetPrompt: `# 角色定位
你是一位资深的个性化辅导教师，拥有15年以上的一对一教学与学习指导经验。你精通教育心理学、认知科学、学习策略，能够根据学生的个体特征、学习状态、知识水平，提供精准、高效、富有启发性的辅导服务。你不仅是知识的传授者，更是学习的引导者、思维的启发者、成长的陪伴者。

# 辅导原则

## 1. 以学生为中心
- 关注学生的真实需求和困惑
- 尊重学生的认知水平和学习节奏
- 鼓励学生主动思考，避免直接给出答案
- 培养学生的自主学习能力和问题解决能力

## 2. 因材施教
- 根据学生的知识基础调整讲解深度
- 识别学生的学习风格（视觉型/听觉型/动觉型）
- 针对学生的薄弱点提供针对性指导
- 发现并强化学生的优势领域

## 3. 启发式教学
- 通过提问引导学生思考，而非直接告知
- 鼓励学生尝试、试错、反思
- 提供思路和方法，而非现成答案
- 培养学生的批判性思维和创新能力

## 4. 及时反馈与鼓励
- 对学生的进步给予及时肯定
- 对错误进行建设性反馈，指出改进方向
- 保持耐心和积极态度，营造安全的学习环境
- 帮助学生建立学习信心和成就感

## 5. 系统性与连贯性
- 将知识点串联成体系，帮助学生建立知识网络
- 关联前后知识，强化理解和记忆
- 提供学习方法和策略，授人以渔
- 培养学生的元认知能力（学会如何学习）

# 对话策略

## 学生提问时
1. **理解问题**：确认学生的真实困惑点
2. **诊断原因**：判断是概念不清、方法不当还是粗心大意
3. **启发引导**：通过提问引导学生自己发现答案
4. **补充讲解**：在学生思考后，补充必要的知识点
5. **举一反三**：提供类似例子，巩固理解

## 学生求助时
1. **评估紧急程度**：判断是卡住无法继续，还是需要验证思路
2. **提供支架**：给予适当提示，而非完整答案
3. **分步指导**：将复杂问题分解为小步骤
4. **鼓励尝试**：让学生先尝试，再提供反馈

## 学生分享成果时
1. **真诚肯定**：认可学生的努力和进步
2. **深入分析**：指出做得好的地方和可改进之处
3. **拓展延伸**：提出更深层次的思考问题
4. **记录成长**：将学生的进步记录到用户画像

## 学生情绪低落时
1. **共情理解**：理解学生的挫折感
2. **积极归因**：帮助学生正确看待困难和失败
3. **调整策略**：建议降低难度或改变学习方法
4. **重建信心**：回顾过往成功经验，激发动力

# 交互规范

## 语言风格
- **清晰简洁**：避免冗长和复杂的表述
- **通俗易懂**：用学生能理解的语言解释专业概念
- **亲切自然**：保持温和、耐心、友好的语气
- **专业准确**：确保知识点的科学性和准确性

## 回复结构
1. **回应学生**：先回应学生的问题或情绪
2. **核心内容**：提供知识讲解、方法指导或问题解答
3. **启发思考**：提出引导性问题或建议
4. **行动建议**：给出具体的下一步行动（如练习、复习）

## 特殊情况处理
- **系统管理请求**：识别后优先使用intent.manage_app工具，而非仅口头回复
- **超出能力范围**：诚实告知，建议查阅资料或寻求其他帮助
- **不当请求**：礼貌拒绝，引导学生回到正常学习轨道
- **重复问题**：耐心解答，但提醒学生做好笔记和总结

# 教学技巧

## 苏格拉底式提问
- "你觉得这道题的关键是什么？"
- "如果我们换一个角度看，会怎样？"
- "你能用自己的话解释一下这个概念吗？"
- "这个方法为什么有效？背后的原理是什么？"

## 脚手架支持
- 提供框架和思路，让学生填充细节
- 给出第一步，让学生完成后续步骤
- 提供类比和例子，帮助理解抽象概念
- 逐步减少支持，培养独立能力

## 元认知培养
- "你是怎么想到这个方法的？"
- "做完这道题，你有什么收获？"
- "下次遇到类似问题，你会怎么做？"
- "你觉得自己在这个知识点上掌握得如何？"

# 注意事项
1. 始终保持教育者的专业性和责任感
2. 不要直接给出作业答案，要引导学生思考
3. 对于考试作弊等不当行为，要明确拒绝并教育
4. 关注学生的身心健康，必要时建议休息或寻求专业帮助
5. 尊重学生隐私，不评判学生的家庭背景或个人情况
6. 持续学习和改进，根据学生反馈优化辅导方式`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "content":"string",
  "intent":{"action":"none","confidence":0,"reason":"","params":{}}
}`,
	},
	{
		Key:  PromptKeyCompressSession,
		Name: "Compress Session",
		PresetPrompt: `Summarize historical conversation for future context.
Keep factual details, user goals, constraints, pending tasks, and explicit preferences.
Avoid repetition and keep the summary concise and structured.`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "content":"string",
  "intent":{"action":"none","confidence":0,"reason":"","params":{}}
}`,
	},
}

var promptTemplatePresetByKey = func() map[string]promptTemplatePreset {
	out := make(map[string]promptTemplatePreset, len(promptTemplatePresetList))
	for _, preset := range promptTemplatePresetList {
		out[preset.Key] = preset
	}
	return out
}()

var promptPresetDirByKey = map[string]string{
	PromptKeyGenerateQuestions: filepath.Join("prompts", "ai", "generate_questions"),
	PromptKeyGradeAnswer:       filepath.Join("prompts", "ai", "grade_answer"),
	PromptKeyGradeAnswerMath:   filepath.Join("prompts", "ai", "grade_answer_math"),
	PromptKeyGradeAnswerEnglish: filepath.Join("prompts", "ai", "grade_answer_english"),
	PromptKeyGradeAnswerChinese: filepath.Join("prompts", "ai", "grade_answer_chinese"),
	PromptKeyGradeAnswerPhysics: filepath.Join("prompts", "ai", "grade_answer_physics"),
	PromptKeyGradeAnswerChemistry: filepath.Join("prompts", "ai", "grade_answer_chemistry"),
	PromptKeyGradeAnswerBiology: filepath.Join("prompts", "ai", "grade_answer_biology"),
	PromptKeyBuildLearningPlan: filepath.Join("prompts", "ai", "build_learning_plan"),
	PromptKeyOptimizeLearning:  filepath.Join("prompts", "ai", "optimize_learning_plan"),
	PromptKeyEvaluateLearning:  filepath.Join("prompts", "ai", "evaluate_learning"),
	PromptKeyScoreLearning:     filepath.Join("prompts", "ai", "score_learning"),
	PromptKeyDetectIntent:      filepath.Join("prompts", "ai", "detect_intent"),
	PromptKeyAgentChat:         filepath.Join("prompts", "ai", "agent_chat"),
	PromptKeyCompressSession:   filepath.Join("prompts", "ai", "compress_session"),
}

var promptPresetLegacyTaskFileByKey = map[string]string{
	PromptKeyGenerateQuestions: filepath.Join("prompts", "ai", "generate_questions.md"),
	PromptKeyGradeAnswer:       filepath.Join("prompts", "ai", "grade_answer.md"),
	PromptKeyBuildLearningPlan: filepath.Join("prompts", "ai", "build_learning_plan.md"),
	PromptKeyOptimizeLearning:  filepath.Join("prompts", "ai", "optimize_learning_plan.md"),
	PromptKeyEvaluateLearning:  filepath.Join("prompts", "ai", "evaluate_learning.md"),
	PromptKeyScoreLearning:     filepath.Join("prompts", "ai", "score_learning.md"),
	PromptKeyDetectIntent:      filepath.Join("prompts", "ai", "detect_intent.md"),
	PromptKeyAgentChat:         filepath.Join("prompts", "ai", "agent_chat.md"),
	PromptKeyCompressSession:   filepath.Join("prompts", "ai", "compress_session.md"),
}

type promptPresetFileCacheEntry struct {
	Exists  bool
	Content string
}

type promptPresetBundle struct {
	SegmentValues          map[string]string
	HasOutputFormatPrompt  bool
	OutputFormatPromptText string
}

var promptPresetTextCache sync.Map

type promptTemplateOverride struct {
	CustomPrompt       string
	OutputFormatPrompt string
	SegmentOverrides   map[string]string
	UpdatedAt          string
}

type PromptTemplateRuntime struct {
	mu        sync.RWMutex
	overrides map[string]promptTemplateOverride
}

func NewPromptTemplateRuntime() *PromptTemplateRuntime {
	return &PromptTemplateRuntime{
		overrides: make(map[string]promptTemplateOverride, len(promptTemplatePresetList)),
	}
}

func normalizePromptKey(key string) string {
	return strings.ToLower(strings.TrimSpace(key))
}

func isSupportedPromptKey(key string) bool {
	_, ok := promptTemplatePresetByKey[normalizePromptKey(key)]
	return ok
}

func supportedPromptKeysText() string {
	keys := make([]string, 0, len(promptTemplatePresetList))
	for _, preset := range promptTemplatePresetList {
		keys = append(keys, preset.Key)
	}
	return strings.Join(keys, "/")
}

func promptTemplateNameForKey(key string) string {
	preset, ok := promptTemplatePresetByKey[normalizePromptKey(key)]
	if !ok {
		return ""
	}
	return preset.Name
}

func (r *PromptTemplateRuntime) Compose(key, userInput string) string {
	return r.ComposeWithPatch(key, userInput, PromptRuntimePatch{})
}

func (r *PromptTemplateRuntime) ComposeWithPatch(key, userInput string, patch PromptRuntimePatch) string {
	cfg, ok := r.Get(normalizePromptKey(key))
	if !ok {
		return strings.TrimSpace(userInput)
	}
	segments := clonePromptSegmentMap(cfg.EffectiveSegments)
	output := strings.TrimSpace(cfg.EffectiveOutputFormatPrompt)
	normalizedPatch := normalizePromptRuntimePatch(patch)
	if normalizedPatch.ReplaceSegments {
		segments = map[string]string{}
	}
	for _, rawKey := range normalizedPatch.SegmentDeletes {
		segmentKey := normalizePromptSegmentKey(rawKey)
		if segmentKey == "" {
			continue
		}
		if segmentKey == promptSegmentOutputFormat {
			output = ""
			continue
		}
		delete(segments, segmentKey)
	}
	for rawKey, rawValue := range normalizedPatch.SegmentUpdates {
		segmentKey := normalizePromptSegmentKey(rawKey)
		if segmentKey == "" || segmentKey == promptSegmentUserInput {
			continue
		}
		value := strings.TrimSpace(rawValue)
		if segmentKey == promptSegmentOutputFormat {
			output = value
			continue
		}
		if value == "" {
			delete(segments, segmentKey)
			continue
		}
		segments[segmentKey] = value
	}
	return composePromptDocument(segments, userInput, output)
}

func composePromptDocument(segments map[string]string, userInput, outputFormat string) string {
	blocks := make([]string, 0, len(promptSegmentOrder)+2)
	normalized := normalizePromptSegmentMap(segments)
	for _, key := range promptSegmentOrder {
		value := strings.TrimSpace(normalized[key])
		if value == "" && isOptionalPromptSegment(key) {
			continue
		}
		if value == "" {
			continue
		}
		blocks = append(blocks, formatPromptBlock(promptSegmentTitleForKey(key), value))
	}
	inputText := strings.TrimSpace(userInput)
	if inputText != "" {
		blocks = append(blocks, formatPromptBlock(promptSegmentTitleForKey(promptSegmentUserInput), inputText))
	}
	outputText := strings.TrimSpace(outputFormat)
	if outputText != "" {
		blocks = append(blocks, formatPromptBlock(promptSegmentTitleForKey(promptSegmentOutputFormat), outputText))
	}
	return strings.Join(blocks, "\n\n")
}

func formatPromptBlock(title, content string) string {
	return fmt.Sprintf("## %s\n%s", strings.TrimSpace(title), strings.TrimSpace(content))
}

func normalizePromptSegmentKey(key string) string {
	return strings.ToLower(strings.TrimSpace(key))
}

func promptSegmentTitleForKey(key string) string {
	normalized := normalizePromptSegmentKey(key)
	if title, ok := promptSegmentTitleByKey[normalized]; ok {
		return title
	}
	return normalized
}

func isSupportedPromptSegment(key string) bool {
	normalized := normalizePromptSegmentKey(key)
	if normalized == promptSegmentUserInput {
		return false
	}
	if normalized == promptSegmentOutputFormat {
		return true
	}
	_, ok := promptSegmentTitleByKey[normalized]
	return ok
}

func isOptionalPromptSegment(key string) bool {
	_, ok := promptOptionalEmptySegmentKeys[normalizePromptSegmentKey(key)]
	return ok
}

func clonePromptSegmentMap(in map[string]string) map[string]string {
	if len(in) == 0 {
		return map[string]string{}
	}
	out := make(map[string]string, len(in))
	for k, v := range in {
		out[k] = strings.TrimSpace(v)
	}
	return out
}

func normalizePromptRuntimePatch(in PromptRuntimePatch) PromptRuntimePatch {
	out := PromptRuntimePatch{
		SegmentUpdates:  map[string]string{},
		SegmentDeletes:  []string{},
		ReplaceSegments: in.ReplaceSegments,
	}
	for rawKey, rawValue := range in.SegmentUpdates {
		key := normalizePromptSegmentKey(rawKey)
		if key == "" {
			continue
		}
		out.SegmentUpdates[key] = strings.TrimSpace(rawValue)
	}
	for _, rawKey := range in.SegmentDeletes {
		key := normalizePromptSegmentKey(rawKey)
		if key == "" {
			continue
		}
		out.SegmentDeletes = append(out.SegmentDeletes, key)
	}
	return out
}

func normalizePromptSegmentMap(in map[string]string) map[string]string {
	if len(in) == 0 {
		return map[string]string{}
	}
	out := make(map[string]string, len(in))
	for k, v := range in {
		normalized := normalizePromptSegmentKey(k)
		if normalized == "" {
			continue
		}
		if normalized == promptSegmentUserInput {
			continue
		}
		out[normalized] = strings.TrimSpace(v)
	}
	return out
}

func defaultPromptSegmentsForPreset(preset promptTemplatePreset) map[string]string {
	out := map[string]string{
		promptSegmentPersona:          "You are a pragmatic and reliable study assistant. Keep responses concise, factual, and actionable.",
		promptSegmentIdentity:         fmt.Sprintf("Current role profile: %s (%s).", strings.TrimSpace(preset.Name), strings.TrimSpace(preset.Key)),
		promptSegmentUserBackground:   "Use available user background from profile/session context. If missing, make conservative assumptions.",
		promptSegmentAIMemo:           "",
		promptSegmentUserProfile:      "",
		promptSegmentScoringCriteria:  "Prioritize correctness, consistency, completeness, and execution feasibility.",
		promptSegmentToolInstructions: "Use tools only when necessary. For mutating operations, verify targets before execution.",
		promptSegmentCurrentSchedule:  "No explicit schedule is provided in this prompt.",
		promptSegmentLearningProgress: "No explicit progress snapshot is provided in this prompt.",
		promptSegmentRules:            "Follow system and developer constraints strictly. Avoid fabrication. Keep structured outputs valid.",
		promptSegmentReservedSlot1:    "[reserved slot 1]",
		promptSegmentReservedSlot2:    "[reserved slot 2]",
		promptSegmentReservedSlot3:    "[reserved slot 3]",
		promptSegmentReservedSlot4:    "[reserved slot 4]",
		promptSegmentReservedSlot5:    "[reserved slot 5]",
		promptSegmentTaskPrompt:       strings.TrimSpace(preset.PresetPrompt),
	}
	return out
}

func loadPromptPresetFile(path string) (string, bool) {
	trimmedPath := strings.TrimSpace(path)
	if trimmedPath == "" {
		return "", false
	}
	if cached, ok := promptPresetTextCache.Load(trimmedPath); ok {
		if entry, okCast := cached.(promptPresetFileCacheEntry); okCast {
			return entry.Content, entry.Exists
		}
	}
	bytes, err := os.ReadFile(trimmedPath)
	if err != nil {
		entry := promptPresetFileCacheEntry{Exists: false}
		promptPresetTextCache.Store(trimmedPath, entry)
		return "", false
	}
	entry := promptPresetFileCacheEntry{
		Exists:  true,
		Content: strings.TrimSpace(string(bytes)),
	}
	promptPresetTextCache.Store(trimmedPath, entry)
	return entry.Content, true
}

func loadPromptPresetBundle(key string) promptPresetBundle {
	normalized := normalizePromptKey(key)
	bundle := promptPresetBundle{
		SegmentValues: map[string]string{},
	}
	dir := strings.TrimSpace(promptPresetDirByKey[normalized])
	if dir != "" {
		for _, segmentKey := range promptSegmentOrder {
			content, exists := loadPromptPresetFile(filepath.Join(dir, segmentKey+".md"))
			if !exists {
				continue
			}
			if segmentKey == promptSegmentTaskPrompt && strings.TrimSpace(content) == "" {
				continue
			}
			bundle.SegmentValues[segmentKey] = strings.TrimSpace(content)
		}
		if outputText, exists := loadPromptPresetFile(filepath.Join(dir, promptSegmentOutputFormat+".md")); exists {
			trimmedOutput := strings.TrimSpace(outputText)
			if trimmedOutput != "" {
				bundle.HasOutputFormatPrompt = true
				bundle.OutputFormatPromptText = trimmedOutput
			}
		}
	}
	if _, ok := bundle.SegmentValues[promptSegmentTaskPrompt]; !ok {
		if legacyPath := strings.TrimSpace(promptPresetLegacyTaskFileByKey[normalized]); legacyPath != "" {
			if legacyText, exists := loadPromptPresetFile(legacyPath); exists {
				trimmedLegacy := strings.TrimSpace(legacyText)
				if trimmedLegacy != "" {
					bundle.SegmentValues[promptSegmentTaskPrompt] = trimmedLegacy
				}
			}
		}
	}
	return bundle
}

func parsePromptSegmentOverridesJSON(raw string) map[string]string {
	text := strings.TrimSpace(raw)
	if text == "" {
		return map[string]string{}
	}
	var payload map[string]string
	if err := json.Unmarshal([]byte(text), &payload); err != nil {
		return map[string]string{}
	}
	return normalizePromptSegmentMap(payload)
}

func mustPromptSegmentOverridesJSON(in map[string]string) string {
	normalized := normalizePromptSegmentMap(in)
	if len(normalized) == 0 {
		return "{}"
	}
	raw, err := json.Marshal(normalized)
	if err != nil {
		return "{}"
	}
	return string(raw)
}

func (r *PromptTemplateRuntime) List() []PromptTemplateConfig {
	r.mu.RLock()
	defer r.mu.RUnlock()

	out := make([]PromptTemplateConfig, 0, len(promptTemplatePresetList))
	for _, preset := range promptTemplatePresetList {
		cfg := buildPromptConfig(preset, r.overrides[preset.Key])
		out = append(out, cfg)
	}
	return out
}

func (r *PromptTemplateRuntime) Get(key string) (PromptTemplateConfig, bool) {
	normalized := normalizePromptKey(key)
	preset, ok := promptTemplatePresetByKey[normalized]
	if !ok {
		return PromptTemplateConfig{}, false
	}

	r.mu.RLock()
	defer r.mu.RUnlock()
	return buildPromptConfig(preset, r.overrides[normalized]), true
}

func (r *PromptTemplateRuntime) getOverride(key string) (promptTemplateOverride, bool) {
	normalized := normalizePromptKey(key)
	r.mu.RLock()
	defer r.mu.RUnlock()
	override, ok := r.overrides[normalized]
	return override, ok
}

func (r *PromptTemplateRuntime) setOverride(key string, override promptTemplateOverride) (PromptTemplateConfig, bool) {
	normalized := normalizePromptKey(key)
	preset, ok := promptTemplatePresetByKey[normalized]
	if !ok {
		return PromptTemplateConfig{}, false
	}

	r.mu.Lock()
	r.overrides[normalized] = normalizePromptTemplateOverride(override)
	out := buildPromptConfig(preset, r.overrides[normalized])
	r.mu.Unlock()
	return out, true
}

func (r *PromptTemplateRuntime) deleteOverride(key string) {
	normalized := normalizePromptKey(key)
	r.mu.Lock()
	delete(r.overrides, normalized)
	r.mu.Unlock()
}

func (r *PromptTemplateRuntime) ReplaceAll(records []PromptTemplateRecord) {
	next := make(map[string]promptTemplateOverride, len(records))
	for _, record := range records {
		key := normalizePromptKey(record.PromptKey)
		if !isSupportedPromptKey(key) {
			continue
		}
		next[key] = normalizePromptTemplateOverride(promptTemplateOverride{
			CustomPrompt:       record.CustomPrompt,
			OutputFormatPrompt: record.OutputFormatPrompt,
			SegmentOverrides:   parsePromptSegmentOverridesJSON(record.SegmentOverridesJSON),
			UpdatedAt:          record.UpdatedAt,
		})
	}
	r.mu.Lock()
	r.overrides = next
	r.mu.Unlock()
}

func normalizePromptTemplateOverride(in promptTemplateOverride) promptTemplateOverride {
	customPrompt := strings.TrimSpace(in.CustomPrompt)
	segmentOverrides := normalizePromptSegmentMap(in.SegmentOverrides)
	if customPrompt != "" {
		segmentOverrides[promptSegmentTaskPrompt] = customPrompt
	} else if taskOverride := strings.TrimSpace(segmentOverrides[promptSegmentTaskPrompt]); taskOverride != "" {
		customPrompt = taskOverride
	}
	return promptTemplateOverride{
		CustomPrompt:       customPrompt,
		OutputFormatPrompt: strings.TrimSpace(in.OutputFormatPrompt),
		SegmentOverrides:   segmentOverrides,
		UpdatedAt:          strings.TrimSpace(in.UpdatedAt),
	}
}

func buildPromptConfig(preset promptTemplatePreset, override promptTemplateOverride) PromptTemplateConfig {
	presetBundle := loadPromptPresetBundle(preset.Key)
	resolvedPresetPrompt := strings.TrimSpace(preset.PresetPrompt)
	if taskPrompt, ok := presetBundle.SegmentValues[promptSegmentTaskPrompt]; ok {
		if trimmedTaskPrompt := strings.TrimSpace(taskPrompt); trimmedTaskPrompt != "" {
			resolvedPresetPrompt = trimmedTaskPrompt
		}
	}
	resolvedPresetOutputPrompt := strings.TrimSpace(preset.PresetOutputFormatPrompt)
	if presetBundle.HasOutputFormatPrompt {
		resolvedPresetOutputPrompt = strings.TrimSpace(presetBundle.OutputFormatPromptText)
	}
	resolvedPreset := preset
	resolvedPreset.PresetPrompt = resolvedPresetPrompt

	customPrompt := strings.TrimSpace(override.CustomPrompt)
	outputPrompt := strings.TrimSpace(override.OutputFormatPrompt)
	presetSegments := defaultPromptSegmentsForPreset(resolvedPreset)
	for segmentKey, text := range presetBundle.SegmentValues {
		normalizedSegmentKey := normalizePromptSegmentKey(segmentKey)
		if normalizedSegmentKey == "" ||
			normalizedSegmentKey == promptSegmentUserInput ||
			normalizedSegmentKey == promptSegmentOutputFormat {
			continue
		}
		presetSegments[normalizedSegmentKey] = strings.TrimSpace(text)
	}
	segmentOverrides := normalizePromptSegmentMap(override.SegmentOverrides)
	effectiveSegments := clonePromptSegmentMap(presetSegments)
	for key, value := range segmentOverrides {
		if key == promptSegmentOutputFormat || key == promptSegmentUserInput {
			continue
		}
		if value == "" {
			if isOptionalPromptSegment(key) {
				effectiveSegments[key] = ""
			}
			continue
		}
		effectiveSegments[key] = value
	}
	if customPrompt != "" {
		effectiveSegments[promptSegmentTaskPrompt] = customPrompt
		segmentOverrides[promptSegmentTaskPrompt] = customPrompt
	}
	effectiveOutputPrompt := resolvedPresetOutputPrompt
	if outputPrompt != "" {
		effectiveOutputPrompt = outputPrompt
	}
	effectivePrompt := composePromptDocument(effectiveSegments, "", "")
	return PromptTemplateConfig{
		Key:                         preset.Key,
		Name:                        preset.Name,
		PresetPrompt:                resolvedPresetPrompt,
		PresetOutputFormatPrompt:    resolvedPresetOutputPrompt,
		PresetSegments:              clonePromptSegmentMap(presetSegments),
		CustomPrompt:                customPrompt,
		OutputFormatPrompt:          outputPrompt,
		SegmentOverrides:            clonePromptSegmentMap(segmentOverrides),
		EffectiveSegments:           clonePromptSegmentMap(effectiveSegments),
		EffectivePrompt:             effectivePrompt,
		EffectiveOutputFormatPrompt: effectiveOutputPrompt,
		UpdatedAt:                   strings.TrimSpace(override.UpdatedAt),
	}
}
