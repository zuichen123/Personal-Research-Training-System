package ai

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"
)

const (
	PromptKeyGenerateQuestions = "generate_questions"
	PromptKeyGradeAnswer       = "grade_answer"
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
		PresetPrompt: `You are an exam question generator.
Generate high-quality practice questions aligned with topic, subject, scope and difficulty.
Keep each item specific, answerable, and suitable for self-study.`,
		PresetOutputFormatPrompt: `Return ONLY valid JSON object with this schema:
{
  "items":[
    {
      "title":"string",
      "stem":"string",
      "type":"single_choice|multi_choice|short_answer",
      "subject":"string",
      "source":"ai_generated",
      "options":[{"key":"A","text":"...","score":0}],
      "answer_key":["string"],
      "tags":["string"],
      "difficulty":1-5,
      "mastery_level":0-100
    }
  ]
}`,
	},
	{
		Key:  PromptKeyGradeAnswer,
		Name: "AI批阅",
		PresetPrompt: `You are a strict grader.
Evaluate the answer against the answer key and provide concise feedback.`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "score":0-100,
  "correct":true|false,
  "feedback":"string",
  "analysis":"string",
  "explanation":"string",
  "wrong_reason":"string"
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
      "difficulty":1-5,
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
	cfg, ok := r.Get(normalizePromptKey(key))
	if !ok {
		return strings.TrimSpace(userInput)
	}
	return composePromptDocument(cfg.EffectiveSegments, userInput, cfg.EffectiveOutputFormatPrompt)
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
	customPrompt := strings.TrimSpace(override.CustomPrompt)
	outputPrompt := strings.TrimSpace(override.OutputFormatPrompt)
	presetSegments := defaultPromptSegmentsForPreset(preset)
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
	effectiveOutputPrompt := preset.PresetOutputFormatPrompt
	if outputPrompt != "" {
		effectiveOutputPrompt = outputPrompt
	}
	effectivePrompt := composePromptDocument(effectiveSegments, "", "")
	return PromptTemplateConfig{
		Key:                         preset.Key,
		Name:                        preset.Name,
		PresetPrompt:                preset.PresetPrompt,
		PresetOutputFormatPrompt:    preset.PresetOutputFormatPrompt,
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
