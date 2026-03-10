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
		PresetPrompt: `Build a long-term study plan.
Use the user profile and input context to produce a realistic, executable plan.
Break down by themes and nested plan nodes (year/month/week/day/task as needed).`,
		PresetOutputFormatPrompt: `Return ONLY JSON with this schema:
{
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
}`,
	},
	{
		Key:  PromptKeyOptimizeLearning,
		Name: "优化学习计划",
		PresetPrompt: `Optimize the given study plan according to the requested action.
Action can be postpone, advance, or complete_early.
Keep the result coherent with dates, hierarchy and plan item status.`,
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
		PresetPrompt: `Evaluate the learning result and provide remediation.
Use question/context, answer key and user answer to produce both single and comprehensive evaluations.`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "score":0-100,
  "single_evaluation":"string",
  "comprehensive_evaluation":"string",
  "single_explanation":"string",
  "comprehensive_explanation":"string",
  "knowledge_supplements":["string"],
  "retest_questions":[
    {
      "title":"string",
      "stem":"string",
      "type":"short_answer",
      "subject":"string",
      "source":"wrong_book",
      "answer_key":["string"],
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
		PresetPrompt: `You are a learning score assistant.
Score learning performance from accuracy, stability and speed, and provide actionable advice.`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "score":0-100,
  "grade":"A|B|C|D|E",
  "advice":["string"]
}`,
	},
	{
		Key:  PromptKeyDetectIntent,
		Name: "Agent Intent Detection",
		PresetPrompt: `Detect whether the latest user request should trigger a tool action.
Allowed actions: generate_questions, build_plan, manage_app, none.
Use manage_app for software management requests such as creating/updating/deleting/listing:
- agents, sessions, prompts, provider config
- questions, mistakes, practice attempts, plans, pomodoro sessions, profile, resources
When action is manage_app, extract "module" and "operation" with required fields in params.
If id is unknown for get/update/delete, include searchable fields such as title/name/keyword/target_date/status/source so the backend can resolve the target.
For creating agents, always provide params.name. If user did not specify one, set params.name="new-agent".
For creating agents without explicit provider credentials, do not invent fake api_key/model and do not force mock;
the backend will try configured provider defaults. If provider availability must be confirmed, call module=provider operation=status.
For id fields, aliases id/agent_id/agentId/session_id/sessionId/item_id/target_id may appear; preserve them in params.
For prompt management (module=prompt, operation=update), support self-edit actions:
- modify/overwrite sections via params.segment_updates (object)
- delete sections via params.segment_deletes (array)
- overwrite all sections via params.replace_segments=true with segment_updates
Allowed prompt sections include: persona, identity, user_background, ai_memo, user_profile, scoring_criteria,
tool_instructions, current_schedule, learning_progress, rules, reserved_slot_1..reserved_slot_5, task_prompt, output_format.
For bulk-delete requests like "delete all plans / clear all plans", set module=plan, operation=delete_all, and params.all=true.
If conversation already contains recent [tool_result] messages, decide whether another manage_app tool step is still required.
If no further tool call is needed, return action=none.
Return confidence in [0,1] and include key params when possible.`,
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
		PresetPrompt: `You are a tutoring agent in a self-study system.
Respond clearly and concisely based on the conversation.
For software-management requests, prefer intent.manage_app instead of only verbal replies.`,
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
