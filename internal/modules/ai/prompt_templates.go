package ai

import (
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
)

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
Allowed actions: generate_questions, build_plan, none.
Return confidence in [0,1] and include key params when possible.`,
		PresetOutputFormatPrompt: `Return ONLY JSON:
{
  "content":"",
  "intent":{
    "action":"generate_questions|build_plan|none",
    "confidence":0.0,
    "reason":"string",
    "params":{"topic":"string","subject":"string","count":3,"difficulty":3}
  }
}`,
	},
		{
			Key:  PromptKeyAgentChat,
			Name: "Agent Chat",
			PresetPrompt: `You are a tutoring agent in a self-study system.
Respond clearly and concisely based on the conversation.`,
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
	parts := []string{
		strings.TrimSpace(cfg.EffectivePrompt),
		strings.TrimSpace(cfg.EffectiveOutputFormatPrompt),
		strings.TrimSpace(userInput),
	}
	return joinPromptParts(parts...)
}

func joinPromptParts(parts ...string) string {
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed == "" {
			continue
		}
		out = append(out, trimmed)
	}
	return strings.Join(out, "\n\n")
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
			UpdatedAt:          record.UpdatedAt,
		})
	}
	r.mu.Lock()
	r.overrides = next
	r.mu.Unlock()
}

func normalizePromptTemplateOverride(in promptTemplateOverride) promptTemplateOverride {
	return promptTemplateOverride{
		CustomPrompt:       strings.TrimSpace(in.CustomPrompt),
		OutputFormatPrompt: strings.TrimSpace(in.OutputFormatPrompt),
		UpdatedAt:          strings.TrimSpace(in.UpdatedAt),
	}
}

func buildPromptConfig(preset promptTemplatePreset, override promptTemplateOverride) PromptTemplateConfig {
	customPrompt := strings.TrimSpace(override.CustomPrompt)
	outputPrompt := strings.TrimSpace(override.OutputFormatPrompt)
	effectivePrompt := preset.PresetPrompt
	if customPrompt != "" {
		effectivePrompt = customPrompt
	}
	effectiveOutputPrompt := preset.PresetOutputFormatPrompt
	if outputPrompt != "" {
		effectiveOutputPrompt = outputPrompt
	}
	return PromptTemplateConfig{
		Key:                         preset.Key,
		Name:                        preset.Name,
		PresetPrompt:                preset.PresetPrompt,
		PresetOutputFormatPrompt:    preset.PresetOutputFormatPrompt,
		CustomPrompt:                customPrompt,
		OutputFormatPrompt:          outputPrompt,
		EffectivePrompt:             effectivePrompt,
		EffectiveOutputFormatPrompt: effectiveOutputPrompt,
		UpdatedAt:                   strings.TrimSpace(override.UpdatedAt),
	}
}

