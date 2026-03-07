package bootstrap

import (
	"context"
	"fmt"
	"sort"
	"strconv"
	"strings"

	"self-study-tool/internal/modules/ai"
	"self-study-tool/internal/modules/mistake"
	"self-study-tool/internal/modules/plan"
	"self-study-tool/internal/modules/pomodoro"
	"self-study-tool/internal/modules/practice"
	"self-study-tool/internal/modules/profile"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/modules/resource"
	"self-study-tool/internal/shared/errs"
)

type aiAppControl struct {
	aiService       *ai.Service
	questionService *question.Service
	mistakeService  *mistake.Service
	practiceService *practice.Service
	planService     *plan.Service
	pomodoroService *pomodoro.Service
	resourceService *resource.Service
	profileService  *profile.Service
}

func newAIAppControl(
	aiService *ai.Service,
	questionService *question.Service,
	mistakeService *mistake.Service,
	practiceService *practice.Service,
	planService *plan.Service,
	pomodoroService *pomodoro.Service,
	resourceService *resource.Service,
	profileService *profile.Service,
) ai.AppControl {
	return &aiAppControl{
		aiService:       aiService,
		questionService: questionService,
		mistakeService:  mistakeService,
		practiceService: practiceService,
		planService:     planService,
		pomodoroService: pomodoroService,
		resourceService: resourceService,
		profileService:  profileService,
	}
}

func (c *aiAppControl) Execute(ctx context.Context, req ai.AppControlRequest) (ai.AppControlResult, error) {
	module := strings.ToLower(strings.TrimSpace(req.Module))
	operation := strings.ToLower(strings.TrimSpace(req.Operation))
	params := req.Params
	if params == nil {
		params = map[string]any{}
	}

	switch module {
	case "question", "questions":
		return c.executeQuestion(ctx, operation, params)
	case "mistake", "mistakes":
		return c.executeMistake(ctx, operation, params)
	case "practice", "attempt", "attempts":
		return c.executePractice(ctx, operation, params)
	case "plan", "plans":
		return c.executePlan(ctx, operation, params)
	case "pomodoro", "focus":
		return c.executePomodoro(ctx, operation, params)
	case "profile", "user_profile":
		return c.executeProfile(ctx, operation, params)
	case "resource", "resources":
		return c.executeResource(ctx, operation, params)
	case "agent", "agents":
		return c.executeAgent(ctx, operation, params)
	case "session", "sessions":
		return c.executeSession(ctx, operation, params)
	case "provider", "ai_provider":
		return c.executeProvider(ctx, operation, params)
	case "math", "calculator", "math_tool":
		return c.executeMath(ctx, operation, params)
	case "prompt", "prompts":
		return c.executePrompt(ctx, operation, params)
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported manage_app module")
	}
}

func (c *aiAppControl) executeQuestion(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		items, err := c.questionService.List(ctx)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		filtered := filterQuestionItems(items, params)
		opts := parseQuestionFetchOptions(params, true)
		sourceCount := len(filtered)
		truncated := false
		if opts.Limit > 0 && len(filtered) > opts.Limit {
			filtered = filtered[:opts.Limit]
			truncated = true
		}
		resultItems := make([]map[string]any, 0, len(filtered))
		for _, item := range filtered {
			resultItems = append(resultItems, c.buildQuestionPayload(ctx, item, opts))
		}
		summary := fmt.Sprintf("Retrieved %d question(s).", len(resultItems))
		if truncated {
			summary = fmt.Sprintf("%s (result truncated by limit=%d)", summary, opts.Limit)
		}
		return ai.AppControlResult{
			Summary: summary,
			Data: map[string]any{
				"items":             resultItems,
				"count":             len(resultItems),
				"source_count":      sourceCount,
				"truncated":         truncated,
				"effective_include": opts.includeSummary(),
			},
		}, nil
	case "get":
		id := firstNonEmpty(asString(params["id"]), asString(params["question_id"]))
		item, err := c.questionService.GetByID(ctx, id)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		opts := parseQuestionFetchOptions(params, false)
		payload := c.buildQuestionPayload(ctx, item, opts)
		return ai.AppControlResult{
			Summary: fmt.Sprintf("Question %s loaded.", item.ID),
			Data: map[string]any{
				"item":              payload,
				"effective_include": opts.includeSummary(),
			},
		}, nil
	case "create":
		in := question.CreateInput{
			Title:        asString(params["title"]),
			Stem:         asString(params["stem"]),
			Type:         question.QuestionType(asString(params["type"])),
			Subject:      asString(params["subject"]),
			Source:       question.QuestionSource(asString(params["source"])),
			Options:      asQuestionOptions(params["options"]),
			AnswerKey:    asStringSlice(params["answer_key"]),
			Tags:         asStringSlice(params["tags"]),
			Difficulty:   asInt(params["difficulty"], 3),
			MasteryLevel: asInt(params["mastery_level"], 0),
		}
		item, err := c.questionService.Create(ctx, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已创建题目 %s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "update":
		id := asString(params["id"])
		oldItem, err := c.questionService.GetByID(ctx, id)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		in := question.UpdateInput{
			Title:        firstNonEmpty(asString(params["title"]), oldItem.Title),
			Stem:         firstNonEmpty(asString(params["stem"]), oldItem.Stem),
			Type:         question.QuestionType(firstNonEmpty(asString(params["type"]), string(oldItem.Type))),
			Subject:      firstNonEmpty(asString(params["subject"]), oldItem.Subject),
			Source:       question.QuestionSource(firstNonEmpty(asString(params["source"]), string(oldItem.Source))),
			Options:      oldItem.Options,
			AnswerKey:    oldItem.AnswerKey,
			Tags:         oldItem.Tags,
			Difficulty:   pickInt(params, "difficulty", oldItem.Difficulty),
			MasteryLevel: pickInt(params, "mastery_level", oldItem.MasteryLevel),
		}
		if hasValue(params, "options") {
			in.Options = asQuestionOptions(params["options"])
		}
		if hasValue(params, "answer_key") {
			in.AnswerKey = asStringSlice(params["answer_key"])
		}
		if hasValue(params, "tags") {
			in.Tags = asStringSlice(params["tags"])
		}
		item, err := c.questionService.Update(ctx, id, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已更新题目 %s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "delete":
		id := asString(params["id"])
		if err := c.questionService.Delete(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已删除题目 %s。", id)}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported question operation")
	}
}

func (c *aiAppControl) executeMistake(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		items, err := c.mistakeService.List(ctx, asString(params["question_id"]))
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取 %d 条错题记录。", len(items)), Data: map[string]any{"items": items}}, nil
	case "get":
		item, err := c.mistakeService.GetByID(ctx, asString(params["id"]))
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取错题记录 %s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "create":
		in := mistake.CreateInput{
			QuestionID:   asString(params["question_id"]),
			Subject:      asString(params["subject"]),
			Difficulty:   asInt(params["difficulty"], 1),
			MasteryLevel: asInt(params["mastery_level"], 0),
			UserAnswer:   asStringSlice(params["user_answer"]),
			Feedback:     asString(params["feedback"]),
			Reason:       asString(params["reason"]),
		}
		item, err := c.mistakeService.Create(ctx, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已创建错题记录 %s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "delete":
		id := asString(params["id"])
		if err := c.mistakeService.Delete(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已删除错题记录 %s。", id)}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported mistake operation")
	}
}

func (c *aiAppControl) executePractice(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		qid := asString(params["question_id"])
		items, err := c.practiceService.ListAttempts(ctx)
		if qid != "" {
			items, err = c.practiceService.ListAttemptsByQuestionID(ctx, qid)
		}
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取 %d 条练习记录。", len(items)), Data: map[string]any{"items": items}}, nil
	case "submit":
		in := practice.SubmitInput{
			QuestionID: firstNonEmpty(asString(params["question_id"]), asString(params["questionId"])),
			UserAnswer: asStringSlice(firstNonNil(params["user_answer"], params["answer"])),
			ElapsedSeconds: firstNonNegativeInt(
				asInt(firstNonNil(params["elapsed_seconds"], params["elapsed"], params["duration_seconds"]), 0),
				0,
			),
		}
		item, err := c.practiceService.Submit(ctx, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已提交练习，记录ID=%s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "delete":
		id := asString(params["id"])
		if err := c.practiceService.DeleteAttempt(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已删除练习记录 %s。", id)}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported practice operation")
	}
}

func (c *aiAppControl) executePlan(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		planType := firstNonEmpty(asString(params["plan_type"]), asString(params["type"]))
		items, err := c.planService.List(ctx, planType)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		filtered := filterPlanItems(items, params)
		limit := asInt(params["limit"], len(filtered))
		if limit < 0 {
			limit = len(filtered)
		}
		truncated := false
		if limit > 0 && len(filtered) > limit {
			filtered = filtered[:limit]
			truncated = true
		}
		summary := fmt.Sprintf("Retrieved %d plan(s).", len(filtered))
		preview := summarizePlanItems(filtered, 5)
		if preview != "" {
			summary = fmt.Sprintf("%s Preview: %s", summary, preview)
		}
		if truncated {
			summary = fmt.Sprintf("%s (result truncated by limit=%d)", summary, limit)
		}
		return ai.AppControlResult{
			Summary: summary,
			Data: map[string]any{
				"items":          filtered,
				"count":          len(filtered),
				"source_count":   len(items),
				"effective_type": planType,
			},
		}, nil
	case "get":
		id, candidates, err := c.resolvePlanID(ctx, params)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		if id == "" {
			return ai.AppControlResult{}, buildPlanResolveError("get", candidates)
		}
		item, err := c.planService.GetByID(ctx, id)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("Plan %s loaded.", item.ID), Data: map[string]any{"item": item}}, nil
	case "create":
		in := plan.CreateInput{
			PlanType:   plan.PlanType(asString(params["plan_type"])),
			Title:      asString(params["title"]),
			Content:    asString(params["content"]),
			TargetDate: asString(params["target_date"]),
			Status:     asString(params["status"]),
			Priority:   asInt(params["priority"], 3),
			Source:     plan.PlanSource(asString(params["source"])),
		}
		item, err := c.planService.Create(ctx, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("Plan %s created.", item.ID), Data: map[string]any{"item": item}}, nil
	case "update":
		id, candidates, err := c.resolvePlanID(ctx, params)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		if id == "" {
			return ai.AppControlResult{}, buildPlanResolveError("update", candidates)
		}
		oldItem, err := c.planService.GetByID(ctx, id)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		in := plan.UpdateInput{
			PlanType:   plan.PlanType(firstNonEmpty(asString(params["plan_type"]), string(oldItem.PlanType))),
			Title:      firstNonEmpty(asString(params["title"]), oldItem.Title),
			Content:    firstNonEmpty(asString(params["content"]), oldItem.Content),
			TargetDate: firstNonEmpty(asString(params["target_date"]), oldItem.TargetDate),
			Status:     firstNonEmpty(asString(params["status"]), oldItem.Status),
			Priority:   pickInt(params, "priority", oldItem.Priority),
			Source:     plan.PlanSource(firstNonEmpty(asString(params["source"]), string(oldItem.Source))),
		}
		item, err := c.planService.Update(ctx, id, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("Plan %s updated.", item.ID), Data: map[string]any{"item": item}}, nil
	case "delete":
		if shouldDeleteAllPlans(operation, params) {
			return c.deletePlanItems(ctx, params)
		}
		id, candidates, err := c.resolvePlanID(ctx, params)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		if id == "" {
			return ai.AppControlResult{}, buildPlanResolveError("delete", candidates)
		}
		if err := c.planService.Delete(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("Deleted plan %s.", id)}, nil
	case "delete_all", "clear", "purge":
		return c.deletePlanItems(ctx, params)
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported plan operation")
	}
}

func (c *aiAppControl) deletePlanItems(
	ctx context.Context,
	params map[string]any,
) (ai.AppControlResult, error) {
	planType := firstNonEmpty(asString(params["plan_type"]), asString(params["type"]))
	items, err := c.planService.List(ctx, planType)
	if err != nil {
		return ai.AppControlResult{}, err
	}
	filtered := filterPlanItems(items, params)
	if len(filtered) == 0 {
		return ai.AppControlResult{
			Summary: "No plan matched; nothing deleted.",
			Data: map[string]any{
				"deleted_count": 0,
				"deleted_ids":   []string{},
				"source_count":  len(items),
			},
		}, nil
	}
	deletedIDs := make([]string, 0, len(filtered))
	for _, item := range filtered {
		if err := c.planService.Delete(ctx, item.ID); err != nil {
			return ai.AppControlResult{}, err
		}
		deletedIDs = append(deletedIDs, item.ID)
	}
	summary := fmt.Sprintf("Deleted %d plan(s).", len(deletedIDs))
	preview := summarizePlanItems(filtered, 5)
	if preview != "" {
		summary = fmt.Sprintf("%s Preview: %s", summary, preview)
	}
	return ai.AppControlResult{
		Summary: summary,
		Data: map[string]any{
			"deleted_count": len(deletedIDs),
			"deleted_ids":   deletedIDs,
			"source_count":  len(items),
		},
	}, nil
}

func shouldDeleteAllPlans(operation string, params map[string]any) bool {
	op := strings.ToLower(strings.TrimSpace(operation))
	if op == "delete_all" || op == "clear" || op == "purge" {
		return true
	}
	if asBool(params["all"], false) || asBool(params["delete_all"], false) || asBool(params["bulk"], false) {
		return true
	}
	scope := strings.ToLower(firstNonEmpty(asString(params["scope"]), asString(params["target"])))
	if scope == "all" || scope == "all_plans" || scope == "plans" {
		return true
	}
	keyword := strings.ToLower(
		firstNonEmpty(
			asString(params["keyword"]),
			asString(params["query"]),
			asString(params["q"]),
			asString(params["title"]),
			asString(params["name"]),
		),
	)
	switch keyword {
	case "all", "all plans", "全部", "所有", "全部计划", "所有计划":
		return true
	default:
		return false
	}
}

func filterPlanItems(items []plan.Item, params map[string]any) []plan.Item {
	keyword := strings.ToLower(
		firstNonEmpty(
			asString(params["keyword"]),
			asString(params["query"]),
			asString(params["q"]),
			asString(params["title"]),
			asString(params["name"]),
		),
	)
	targetDate := firstNonEmpty(asString(params["target_date"]), asString(params["date"]))
	status := strings.ToLower(asString(params["status"]))
	source := strings.ToLower(asString(params["source"]))
	priority := -1
	if hasValue(params, "priority") {
		priority = asInt(params["priority"], -1)
	}

	out := make([]plan.Item, 0, len(items))
	for _, item := range items {
		if targetDate != "" && strings.TrimSpace(item.TargetDate) != targetDate {
			continue
		}
		if status != "" && strings.ToLower(strings.TrimSpace(item.Status)) != status {
			continue
		}
		if source != "" && strings.ToLower(strings.TrimSpace(string(item.Source))) != source {
			continue
		}
		if priority > 0 && item.Priority != priority {
			continue
		}
		if keyword != "" {
			title := strings.ToLower(strings.TrimSpace(item.Title))
			content := strings.ToLower(strings.TrimSpace(item.Content))
			if !strings.Contains(title, keyword) && !strings.Contains(content, keyword) {
				continue
			}
		}
		out = append(out, item)
	}
	return out
}

func summarizePlanItems(items []plan.Item, limit int) string {
	if len(items) == 0 || limit == 0 {
		return ""
	}
	if limit < 0 || limit > len(items) {
		limit = len(items)
	}
	chunks := make([]string, 0, limit)
	for i := 0; i < limit; i++ {
		item := items[i]
		date := strings.TrimSpace(item.TargetDate)
		if date == "" {
			date = "-"
		}
		chunks = append(
			chunks,
			fmt.Sprintf(
				"id=%s title=%q date=%s status=%s",
				item.ID,
				item.Title,
				date,
				item.Status,
			),
		)
	}
	return strings.Join(chunks, "; ")
}

func (c *aiAppControl) resolvePlanID(
	ctx context.Context,
	params map[string]any,
) (string, []plan.Item, error) {
	directID := firstNonEmpty(
		asString(params["id"]),
		asString(params["plan_id"]),
		asString(params["item_id"]),
		asString(params["target_id"]),
	)
	if directID != "" {
		return directID, nil, nil
	}

	planType := firstNonEmpty(asString(params["plan_type"]), asString(params["type"]))
	items, err := c.planService.List(ctx, planType)
	if err != nil {
		return "", nil, err
	}
	candidates := filterPlanItems(items, params)
	if len(candidates) == 1 {
		return candidates[0].ID, candidates, nil
	}

	title := strings.TrimSpace(firstNonEmpty(asString(params["title"]), asString(params["name"])))
	if title != "" && len(candidates) > 1 {
		exact := make([]plan.Item, 0, len(candidates))
		for _, item := range candidates {
			if strings.EqualFold(strings.TrimSpace(item.Title), title) {
				exact = append(exact, item)
			}
		}
		if len(exact) == 1 {
			return exact[0].ID, exact, nil
		}
		if len(exact) > 1 {
			candidates = exact
		}
	}

	return "", candidates, nil
}

func buildPlanResolveError(operation string, candidates []plan.Item) error {
	op := strings.TrimSpace(operation)
	if op == "" {
		op = "operate"
	}
	if len(candidates) == 0 {
		return errs.BadRequest(
			fmt.Sprintf(
				"plan %s requires id, or provide title/keyword/target_date/status/source to find a unique plan",
				op,
			),
		)
	}
	return errs.BadRequest(
		fmt.Sprintf(
			"plan %s is ambiguous: matched %d item(s). Candidates: %s",
			op,
			len(candidates),
			summarizePlanItems(candidates, 5),
		),
	)
}
func (c *aiAppControl) executePomodoro(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		items, err := c.pomodoroService.List(ctx, asString(params["status"]))
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取 %d 条专注记录。", len(items)), Data: map[string]any{"items": items}}, nil
	case "start":
		in := pomodoro.StartInput{
			TaskTitle:       asString(params["task_title"]),
			PlanID:          asString(params["plan_id"]),
			DurationMinutes: asInt(params["duration_minutes"], 25),
			BreakMinutes:    asInt(params["break_minutes"], 5),
		}
		item, err := c.pomodoroService.Start(ctx, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已开始专注，记录ID=%s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "end":
		id := asString(params["id"])
		in := pomodoro.EndInput{
			Status: pomodoro.SessionStatus(firstNonEmpty(asString(params["status"]), string(pomodoro.Completed))),
		}
		item, err := c.pomodoroService.End(ctx, id, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已结束专注，记录ID=%s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "delete":
		id := asString(params["id"])
		if err := c.pomodoroService.Delete(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已删除专注记录 %s。", id)}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported pomodoro operation")
	}
}

func (c *aiAppControl) executeProfile(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "get":
		userID := firstNonEmpty(asString(params["user_id"]), "default")
		item, err := c.profileService.Get(ctx, userID)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取用户档案 %s。", item.UserID), Data: map[string]any{"item": item}}, nil
	case "upsert", "update":
		userID := firstNonEmpty(asString(params["user_id"]), "default")
		oldItem, err := c.profileService.Get(ctx, userID)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		in := profile.UpsertInput{
			UserID:            userID,
			Nickname:          firstNonEmpty(asString(params["nickname"]), oldItem.Nickname),
			Age:               pickInt(params, "age", oldItem.Age),
			AcademicStatus:    firstNonEmpty(asString(params["academic_status"]), oldItem.AcademicStatus),
			Goals:             pickStringSlice(params, "goals", oldItem.Goals),
			GoalTargetDate:    firstNonEmpty(asString(params["goal_target_date"]), oldItem.GoalTargetDate),
			DailyStudyMinutes: pickInt(params, "daily_study_minutes", oldItem.DailyStudyMinutes),
			WeakSubjects:      pickStringSlice(params, "weak_subjects", oldItem.WeakSubjects),
			TargetDestination: firstNonEmpty(asString(params["target_destination"]), oldItem.TargetDestination),
			Notes:             firstNonEmpty(asString(params["notes"]), oldItem.Notes),
		}
		item, err := c.profileService.Upsert(ctx, in)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: "已更新用户档案。", Data: map[string]any{"item": item}}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported profile operation")
	}
}

func (c *aiAppControl) executeResource(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		items, err := c.resourceService.List(ctx, asString(params["question_id"]))
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取 %d 条资料。", len(items)), Data: map[string]any{"items": items}}, nil
	case "get":
		item, err := c.resourceService.GetByID(ctx, asString(params["id"]))
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取资料 %s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "delete":
		id := asString(params["id"])
		if err := c.resourceService.Delete(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已删除资料 %s。", id)}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported resource operation")
	}
}

func (c *aiAppControl) executeAgent(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		items, err := c.aiService.ListAgents(ctx)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取 %d 个智能体。", len(items)), Data: map[string]any{"items": items}}, nil
	case "create":
		req := applyCreateAgentDefaults(
			buildUpsertAgentRequest(params),
			params,
			loadAgentCreateProviderDefaults(c.aiService),
		)
		item, err := c.aiService.CreateAgent(ctx, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已创建智能体 %s。", item.Name), Data: map[string]any{"item": item}}, nil
	case "update":
		id, err := c.resolveAgentID(ctx, "update", params)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		req := buildUpsertAgentRequest(params)
		item, err := c.aiService.UpdateAgent(ctx, id, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已更新智能体 %s。", item.Name), Data: map[string]any{"item": item}}, nil
	case "delete":
		id, err := c.resolveAgentID(ctx, "delete", params)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		if err := c.aiService.DeleteAgent(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已删除智能体 %s。", id)}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported agent operation")
	}
}

func (c *aiAppControl) resolveAgentID(ctx context.Context, operation string, params map[string]any) (string, error) {
	directID := firstNonEmpty(
		asString(params["id"]),
		asString(params["agent_id"]),
		asString(params["agentId"]),
		asString(params["item_id"]),
		asString(params["target_id"]),
	)
	if directID != "" {
		return directID, nil
	}
	if c.aiService == nil {
		return "", errs.BadRequest("ai service is not ready")
	}
	items, err := c.aiService.ListAgents(ctx)
	if err != nil {
		return "", err
	}
	resolved, candidates := resolveAgentIDFromItems(params, items)
	if resolved != "" {
		return resolved, nil
	}
	return "", buildAgentResolveError(operation, candidates)
}

func resolveAgentIDFromItems(params map[string]any, items []ai.Agent) (string, []ai.Agent) {
	candidates := filterAgentItems(items, params)
	if len(candidates) == 1 {
		return candidates[0].ID, candidates
	}
	name := strings.TrimSpace(firstNonEmpty(asString(params["name"]), asString(params["title"])))
	if name != "" && len(candidates) > 1 {
		exact := make([]ai.Agent, 0, len(candidates))
		for _, item := range candidates {
			if strings.EqualFold(strings.TrimSpace(item.Name), name) {
				exact = append(exact, item)
			}
		}
		if len(exact) == 1 {
			return exact[0].ID, exact
		}
		if len(exact) > 1 {
			candidates = exact
		}
	}
	return "", candidates
}

func filterAgentItems(items []ai.Agent, params map[string]any) []ai.Agent {
	keyword := strings.ToLower(
		firstNonEmpty(
			asString(params["keyword"]),
			asString(params["query"]),
			asString(params["q"]),
			asString(params["name"]),
			asString(params["title"]),
		),
	)
	protocol := strings.ToLower(asString(params["protocol"]))
	matchEnabled := hasValue(params, "enabled")
	enabled := asBool(params["enabled"], false)

	out := make([]ai.Agent, 0, len(items))
	for _, item := range items {
		if protocol != "" && strings.ToLower(strings.TrimSpace(string(item.Protocol))) != protocol {
			continue
		}
		if matchEnabled && item.Enabled != enabled {
			continue
		}
		if keyword != "" {
			name := strings.ToLower(strings.TrimSpace(item.Name))
			id := strings.ToLower(strings.TrimSpace(item.ID))
			if !strings.Contains(name, keyword) && !strings.Contains(id, keyword) {
				continue
			}
		}
		out = append(out, item)
	}
	return out
}

func buildAgentResolveError(operation string, candidates []ai.Agent) error {
	op := strings.TrimSpace(operation)
	if op == "" {
		op = "operate"
	}
	if len(candidates) == 0 {
		return errs.BadRequest(
			fmt.Sprintf(
				"agent %s requires id, or provide name/keyword/protocol/enabled to find a unique agent",
				op,
			),
		)
	}
	return errs.BadRequest(
		fmt.Sprintf(
			"agent %s is ambiguous: matched %d item(s). Candidates: %s",
			op,
			len(candidates),
			summarizeAgentItems(candidates, 5),
		),
	)
}

func summarizeAgentItems(items []ai.Agent, limit int) string {
	if len(items) == 0 || limit == 0 {
		return ""
	}
	if limit < 0 || limit > len(items) {
		limit = len(items)
	}
	chunks := make([]string, 0, limit)
	for i := 0; i < limit; i++ {
		item := items[i]
		chunks = append(
			chunks,
			fmt.Sprintf(
				"id=%s name=%q protocol=%s enabled=%t",
				item.ID,
				item.Name,
				item.Protocol,
				item.Enabled,
			),
		)
	}
	return strings.Join(chunks, "; ")
}

type createAgentProviderDefaults struct {
	Protocol ai.AgentProtocol
	Primary  ai.AgentProviderConfig
	Ready    bool
}

func loadAgentCreateProviderDefaults(service *ai.Service) createAgentProviderDefaults {
	if service == nil {
		return createAgentProviderDefaults{}
	}
	protocol, primary, ok := service.DefaultAgentProviderConfig()
	if !ok {
		return createAgentProviderDefaults{}
	}
	return createAgentProviderDefaults{
		Protocol: protocol,
		Primary:  primary,
		Ready:    true,
	}
}

func applyCreateAgentDefaults(
	req ai.UpsertAgentRequest,
	params map[string]any,
	defaults createAgentProviderDefaults,
) ai.UpsertAgentRequest {
	req.Name = firstNonEmpty(req.Name, asString(params["agent_name"]), asString(params["title"]), asString(params["keyword"]))
	if req.Name == "" {
		req.Name = "new-agent"
	}

	protocol := strings.ToLower(strings.TrimSpace(string(req.Protocol)))
	if protocol == "" {
		if defaults.Ready {
			req.Protocol = defaults.Protocol
			protocol = strings.ToLower(strings.TrimSpace(string(req.Protocol)))
		}
	}
	if protocol == string(ai.AgentProtocolMock) {
		return req
	}

	missingPrimary := strings.TrimSpace(req.Primary.APIKey) == "" || strings.TrimSpace(req.Primary.Model) == ""
	if missingPrimary && defaults.Ready {
		if !strings.EqualFold(protocol, string(defaults.Protocol)) {
			req.Protocol = defaults.Protocol
			protocol = strings.ToLower(strings.TrimSpace(string(req.Protocol)))
			req.Primary = defaults.Primary
		} else {
			req.Primary.BaseURL = firstNonEmpty(req.Primary.BaseURL, defaults.Primary.BaseURL)
			req.Primary.APIKey = firstNonEmpty(req.Primary.APIKey, defaults.Primary.APIKey)
			req.Primary.Model = firstNonEmpty(req.Primary.Model, defaults.Primary.Model)
		}
	}
	return req
}

func (c *aiAppControl) executeSession(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		agentID := firstNonEmpty(asString(params["agent_id"]), asString(params["agentId"]))
		limit := asInt(params["limit"], 20)
		cursor := asString(params["cursor"])
		items, err := c.aiService.ListAgentSessions(ctx, agentID, limit, cursor)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取 %d 个会话。", len(items)), Data: map[string]any{"items": items}}, nil
	case "create":
		agentID := firstNonEmpty(asString(params["agent_id"]), asString(params["agentId"]))
		req := ai.CreateSessionRequest{Title: asString(params["title"])}
		item, err := c.aiService.CreateAgentSession(ctx, agentID, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已创建会话 %s。", item.ID), Data: map[string]any{"item": item}}, nil
	case "delete":
		id := firstNonEmpty(asString(params["id"]), asString(params["session_id"]), asString(params["sessionId"]))
		if err := c.aiService.DeleteAgentSession(ctx, id); err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已删除会话 %s。", id)}, nil
	case "compress":
		id := firstNonEmpty(asString(params["id"]), asString(params["session_id"]), asString(params["sessionId"]))
		req := ai.CompressSessionRequest{
			Force:   asBool(params["force"], false),
			Trigger: firstNonEmpty(asString(params["trigger"]), "manual"),
		}
		result, err := c.aiService.CompressSessionMessages(ctx, id, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("会话压缩状态：%s。", result.Status), Data: map[string]any{"result": result}}, nil
	case "get_schedule_binding", "schedule_binding_get":
		id := firstNonEmpty(asString(params["id"]), asString(params["session_id"]), asString(params["sessionId"]))
		result, err := c.aiService.GetSessionScheduleBinding(ctx, id)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{
			Summary: "已获取会话日程绑定。",
			Data: map[string]any{
				"binding":       result.Binding,
				"matched_plans": result.MatchedPlans,
			},
		}, nil
	case "update_schedule_binding", "schedule_binding_update":
		id := firstNonEmpty(asString(params["id"]), asString(params["session_id"]), asString(params["sessionId"]))
		req := ai.UpdateSessionScheduleBindingRequest{
			Mode:          asString(params["mode"]),
			Theme:         asString(params["theme"]),
			ManualPlanIDs: asStringSlice(params["manual_plan_ids"]),
		}
		if hasValue(params, "auto_enabled") {
			v := asBool(params["auto_enabled"], false)
			req.AutoEnabled = &v
		}
		result, err := c.aiService.UpdateSessionScheduleBinding(ctx, id, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{
			Summary: "已更新会话日程绑定。",
			Data: map[string]any{
				"binding":       result.Binding,
				"matched_plans": result.MatchedPlans,
			},
		}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported session operation")
	}
}

func (c *aiAppControl) executeProvider(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "status", "get":
		status := c.aiService.ProviderStatus()
		return ai.AppControlResult{Summary: "已获取 AI 服务配置状态。", Data: map[string]any{"status": status}}, nil
	case "update":
		req := ai.UpdateProviderConfigRequest{
			Provider:      asString(params["provider"]),
			APIKey:        asString(params["api_key"]),
			Model:         asString(params["model"]),
			OpenAIBaseURL: asString(params["openai_base_url"]),
		}
		status, err := c.aiService.UpdateProviderConfig(req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: "已更新 AI 服务配置。", Data: map[string]any{"status": status}}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported provider operation")
	}
}

func (c *aiAppControl) executeMath(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "compute", "calculate", "eval":
		req := ai.MathComputeRequest{
			Expression: firstNonEmpty(asString(params["expression"]), asString(params["formula"])),
			Variables:  asFloatMap(firstNonNil(params["variables"], params["vars"])),
			Precision:  asInt(params["precision"], 6),
		}
		item, err := c.aiService.ComputeMath(ctx, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{
			Summary: fmt.Sprintf("数学计算完成，结果=%s。", item.Formatted),
			Data: map[string]any{
				"result": item,
			},
		}, nil
	case "verify", "check":
		req := ai.MathVerifyRequest{
			Question:        asString(params["question"]),
			CandidateAnswer: firstNonEmpty(asString(params["candidate_answer"]), asString(params["answer"])),
			ReferenceAnswer: firstNonEmpty(asString(params["reference_answer"]), asString(params["answer_key"])),
			SolutionProcess: firstNonEmpty(asString(params["solution_process"]), asString(params["process"])),
		}
		item, err := c.aiService.VerifyMathAnswer(ctx, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		state := "不通过"
		if item.Correct {
			state = "通过"
		}
		return ai.AppControlResult{
			Summary: fmt.Sprintf("答案校验%s，难度=%d。", state, item.Difficulty),
			Data: map[string]any{
				"result": item,
			},
		}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported math operation")
	}
}

func (c *aiAppControl) executePrompt(ctx context.Context, operation string, params map[string]any) (ai.AppControlResult, error) {
	switch operation {
	case "list":
		items := c.aiService.ListPromptTemplates()
		return ai.AppControlResult{Summary: fmt.Sprintf("已获取 %d 个提示词模板。", len(items)), Data: map[string]any{"items": items}}, nil
	case "reload":
		items, err := c.aiService.ReloadPromptTemplates(ctx)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已重载 %d 个提示词模板。", len(items)), Data: map[string]any{"items": items}}, nil
	case "update":
		key := asString(params["key"])
		customPrompt, hasCustom := params["custom_prompt"]
		outputPrompt, hasOutput := params["output_format_prompt"]
		req := ai.UpdatePromptTemplateRequest{}
		if hasCustom {
			value := asString(customPrompt)
			req.CustomPrompt = &value
		}
		if hasOutput {
			value := asString(outputPrompt)
			req.OutputFormatPrompt = &value
		}
		req.SegmentUpdates = asStringMap(params["segment_updates"])
		req.SegmentDeletes = asStringSlice(params["segment_deletes"])
		req.ReplaceSegments = asBool(params["replace_segments"], false)
		segment := asString(params["segment"])
		if segment != "" {
			mode := strings.ToLower(firstNonEmpty(asString(params["mode"]), asString(params["segment_mode"]), "modify"))
			segmentValue := firstNonEmpty(asString(params["segment_value"]), asString(params["value"]), asString(params["text"]))
			switch mode {
			case "delete", "remove", "clear":
				req.SegmentDeletes = append(req.SegmentDeletes, segment)
			case "overwrite":
				req.ReplaceSegments = true
				if req.SegmentUpdates == nil {
					req.SegmentUpdates = map[string]string{}
				}
				req.SegmentUpdates[segment] = segmentValue
			default:
				if req.SegmentUpdates == nil {
					req.SegmentUpdates = map[string]string{}
				}
				req.SegmentUpdates[segment] = segmentValue
			}
		}
		item, err := c.aiService.UpdatePromptTemplate(ctx, key, req)
		if err != nil {
			return ai.AppControlResult{}, err
		}
		return ai.AppControlResult{Summary: fmt.Sprintf("已更新提示词模板 %s。", item.Key), Data: map[string]any{"item": item}}, nil
	default:
		return ai.AppControlResult{}, errs.BadRequest("unsupported prompt operation")
	}
}

type questionFetchOptions struct {
	Limit             int
	AttemptLimit      int
	ContentMaxChars   int
	IncludeQuestion   bool
	IncludeContent    bool
	IncludeOptions    bool
	IncludeAnswerKey  bool
	IncludeTags       bool
	IncludeUserAnswer bool
	IncludeAttempts   bool
}

func parseQuestionFetchOptions(params map[string]any, forList bool) questionFetchOptions {
	opts := questionFetchOptions{
		Limit:             0,
		AttemptLimit:      asInt(firstNonNil(params["attempt_limit"], params["user_answer_limit"]), 3),
		ContentMaxChars:   asInt(firstNonNil(params["content_max_chars"], params["stem_max_chars"]), 0),
		IncludeQuestion:   true,
		IncludeContent:    !forList,
		IncludeOptions:    !forList,
		IncludeAnswerKey:  !forList,
		IncludeTags:       true,
		IncludeUserAnswer: false,
		IncludeAttempts:   false,
	}
	if forList {
		opts.Limit = asInt(firstNonNil(params["limit"], params["question_limit"]), 10)
	}

	view := strings.ToLower(firstNonEmpty(asString(params["view"]), asString(params["detail"]), asString(params["mode"])))
	switch view {
	case "basic", "summary", "compact":
		opts.IncludeContent = false
		opts.IncludeOptions = false
		opts.IncludeAnswerKey = false
		opts.IncludeUserAnswer = false
		opts.IncludeAttempts = false
	case "content", "question":
		opts.IncludeContent = true
	case "answer", "answers", "grading":
		opts.IncludeContent = true
		opts.IncludeOptions = true
		opts.IncludeAnswerKey = true
	case "practice", "attempt", "attempts":
		opts.IncludeUserAnswer = true
		opts.IncludeAttempts = true
	case "full", "all":
		opts.IncludeContent = true
		opts.IncludeOptions = true
		opts.IncludeAnswerKey = true
		opts.IncludeUserAnswer = true
		opts.IncludeAttempts = true
	}
	if asBool(firstNonNil(params["include_full"], params["full"]), false) {
		opts.IncludeContent = true
		opts.IncludeOptions = true
		opts.IncludeAnswerKey = true
		opts.IncludeUserAnswer = true
		opts.IncludeAttempts = true
	}

	includeSet := parseQuestionIncludeSet(firstNonNil(params["include"], params["fields"], params["with"]))
	if _, ok := includeSet["full"]; ok {
		opts.IncludeContent = true
		opts.IncludeOptions = true
		opts.IncludeAnswerKey = true
		opts.IncludeUserAnswer = true
		opts.IncludeAttempts = true
	}
	if _, ok := includeSet["question"]; ok {
		opts.IncludeQuestion = true
	}
	if _, ok := includeSet["content"]; ok {
		opts.IncludeContent = true
	}
	if _, ok := includeSet["options"]; ok {
		opts.IncludeOptions = true
	}
	if _, ok := includeSet["answer_key"]; ok {
		opts.IncludeAnswerKey = true
	}
	if _, ok := includeSet["tags"]; ok {
		opts.IncludeTags = true
	}
	if _, ok := includeSet["user_answer"]; ok {
		opts.IncludeUserAnswer = true
	}
	if _, ok := includeSet["attempts"]; ok {
		opts.IncludeAttempts = true
	}

	excludeSet := parseQuestionIncludeSet(params["exclude"])
	if _, ok := excludeSet["question"]; ok {
		opts.IncludeQuestion = false
	}
	if _, ok := excludeSet["content"]; ok {
		opts.IncludeContent = false
	}
	if _, ok := excludeSet["options"]; ok {
		opts.IncludeOptions = false
	}
	if _, ok := excludeSet["answer_key"]; ok {
		opts.IncludeAnswerKey = false
	}
	if _, ok := excludeSet["tags"]; ok {
		opts.IncludeTags = false
	}
	if _, ok := excludeSet["user_answer"]; ok {
		opts.IncludeUserAnswer = false
	}
	if _, ok := excludeSet["attempts"]; ok {
		opts.IncludeAttempts = false
	}

	applyBoolOverride(params, "include_question", &opts.IncludeQuestion)
	applyBoolOverride(params, "include_content", &opts.IncludeContent)
	applyBoolOverride(params, "include_stem", &opts.IncludeContent)
	applyBoolOverride(params, "include_options", &opts.IncludeOptions)
	applyBoolOverride(params, "include_answer_key", &opts.IncludeAnswerKey)
	applyBoolOverride(params, "include_tags", &opts.IncludeTags)
	applyBoolOverride(params, "include_user_answer", &opts.IncludeUserAnswer)
	applyBoolOverride(params, "include_attempts", &opts.IncludeAttempts)

	if opts.AttemptLimit <= 0 {
		opts.AttemptLimit = 3
	}
	if opts.ContentMaxChars < 0 {
		opts.ContentMaxChars = 0
	}
	if opts.Limit < 0 {
		opts.Limit = 0
	}
	if !opts.IncludeQuestion &&
		!opts.IncludeContent &&
		!opts.IncludeOptions &&
		!opts.IncludeAnswerKey &&
		!opts.IncludeUserAnswer &&
		!opts.IncludeAttempts &&
		!opts.IncludeTags {
		opts.IncludeQuestion = true
	}
	return opts
}

func (opts questionFetchOptions) includeSummary() []string {
	out := make([]string, 0, 7)
	if opts.IncludeQuestion {
		out = append(out, "question")
	}
	if opts.IncludeContent {
		out = append(out, "content")
	}
	if opts.IncludeOptions {
		out = append(out, "options")
	}
	if opts.IncludeAnswerKey {
		out = append(out, "answer_key")
	}
	if opts.IncludeTags {
		out = append(out, "tags")
	}
	if opts.IncludeUserAnswer {
		out = append(out, "user_answer")
	}
	if opts.IncludeAttempts {
		out = append(out, "attempts")
	}
	return out
}

func filterQuestionItems(items []question.Question, params map[string]any) []question.Question {
	idSet := extractQuestionIDSet(params)
	subject := strings.ToLower(asString(params["subject"]))
	source := strings.ToLower(asString(params["source"]))
	keyword := strings.ToLower(
		firstNonEmpty(
			asString(params["keyword"]),
			asString(params["query"]),
			asString(params["q"]),
			asString(params["title"]),
			asString(params["stem"]),
		),
	)
	minDifficulty := 0
	maxDifficulty := 0
	if hasValue(params, "min_difficulty") {
		minDifficulty = asInt(params["min_difficulty"], 0)
	}
	if hasValue(params, "max_difficulty") {
		maxDifficulty = asInt(params["max_difficulty"], 0)
	}

	out := make([]question.Question, 0, len(items))
	for _, item := range items {
		if len(idSet) > 0 {
			if _, ok := idSet[item.ID]; !ok {
				continue
			}
		}
		if subject != "" && strings.ToLower(strings.TrimSpace(item.Subject)) != subject {
			continue
		}
		if source != "" && strings.ToLower(strings.TrimSpace(string(item.Source))) != source {
			continue
		}
		if minDifficulty > 0 && item.Difficulty < minDifficulty {
			continue
		}
		if maxDifficulty > 0 && item.Difficulty > maxDifficulty {
			continue
		}
		if keyword != "" {
			title := strings.ToLower(strings.TrimSpace(item.Title))
			stem := strings.ToLower(strings.TrimSpace(item.Stem))
			if !strings.Contains(title, keyword) && !strings.Contains(stem, keyword) {
				continue
			}
		}
		out = append(out, item)
	}

	sort.SliceStable(out, func(i, j int) bool {
		left := out[i]
		right := out[j]
		if left.UpdatedAt.Equal(right.UpdatedAt) {
			return left.ID < right.ID
		}
		return left.UpdatedAt.After(right.UpdatedAt)
	})
	return out
}

func extractQuestionIDSet(params map[string]any) map[string]struct{} {
	out := map[string]struct{}{}
	ids := asStringSlice(firstNonNil(params["question_ids"], params["ids"]))
	ids = append(ids, firstNonEmpty(asString(params["id"]), asString(params["question_id"])))
	for _, id := range ids {
		trimmed := strings.TrimSpace(id)
		if trimmed == "" {
			continue
		}
		out[trimmed] = struct{}{}
	}
	return out
}

func parseQuestionIncludeSet(raw any) map[string]struct{} {
	out := map[string]struct{}{}
	for _, token := range splitFlexibleTokens(raw) {
		normalized := normalizeQuestionIncludeToken(token)
		if normalized == "" {
			continue
		}
		out[normalized] = struct{}{}
	}
	return out
}

func splitFlexibleTokens(raw any) []string {
	base := asStringSlice(raw)
	if len(base) == 0 {
		return []string{}
	}
	out := make([]string, 0, len(base))
	for _, item := range base {
		parts := strings.FieldsFunc(item, func(r rune) bool {
			return r == ',' || r == ';' || r == '|'
		})
		if len(parts) == 0 {
			if strings.TrimSpace(item) != "" {
				out = append(out, strings.TrimSpace(item))
			}
			continue
		}
		for _, part := range parts {
			trimmed := strings.TrimSpace(part)
			if trimmed == "" {
				continue
			}
			out = append(out, trimmed)
		}
	}
	return out
}

func normalizeQuestionIncludeToken(token string) string {
	switch strings.ToLower(strings.TrimSpace(token)) {
	case "question", "questions", "basic", "summary", "compact", "meta":
		return "question"
	case "content", "stem", "question_content":
		return "content"
	case "options", "option":
		return "options"
	case "answer", "answers", "answer_key", "key":
		return "answer_key"
	case "tag", "tags":
		return "tags"
	case "user_answer", "user_answers", "answer_history":
		return "user_answer"
	case "attempt", "attempts", "practice", "practice_attempts":
		return "attempts"
	case "full", "all":
		return "full"
	default:
		return ""
	}
}

func applyBoolOverride(params map[string]any, key string, target *bool) {
	if !hasValue(params, key) {
		return
	}
	*target = asBool(params[key], *target)
}

func truncateQuestionContent(content string, maxChars int) string {
	text := strings.TrimSpace(content)
	if maxChars <= 0 {
		return text
	}
	runes := []rune(text)
	if len(runes) <= maxChars {
		return text
	}
	return strings.TrimSpace(string(runes[:maxChars])) + " ..."
}

func (c *aiAppControl) buildQuestionPayload(
	ctx context.Context,
	item question.Question,
	opts questionFetchOptions,
) map[string]any {
	out := map[string]any{
		"id": item.ID,
	}
	if opts.IncludeQuestion {
		out["title"] = item.Title
		out["type"] = item.Type
		out["subject"] = item.Subject
		out["source"] = item.Source
		out["difficulty"] = item.Difficulty
		out["mastery_level"] = item.MasteryLevel
		out["created_at"] = item.CreatedAt
		out["updated_at"] = item.UpdatedAt
	}
	if opts.IncludeContent {
		out["stem"] = truncateQuestionContent(item.Stem, opts.ContentMaxChars)
	}
	if opts.IncludeOptions {
		out["options"] = item.Options
	}
	if opts.IncludeAnswerKey {
		out["answer_key"] = item.AnswerKey
	}
	if opts.IncludeTags {
		out["tags"] = item.Tags
	}
	if !opts.IncludeUserAnswer && !opts.IncludeAttempts {
		return out
	}
	attemptsAll := c.listQuestionAttempts(ctx, item.ID)
	attempts := attemptsAll
	if opts.AttemptLimit > 0 && len(attempts) > opts.AttemptLimit {
		attempts = attempts[:opts.AttemptLimit]
	}
	if opts.IncludeUserAnswer {
		out["recent_user_answers"] = summarizeAttemptAnswers(attempts)
	}
	if opts.IncludeAttempts {
		out["recent_attempts"] = attempts
	}
	out["attempt_count"] = len(attemptsAll)
	return out
}

func (c *aiAppControl) listQuestionAttempts(ctx context.Context, questionID string) []practice.Attempt {
	if c.practiceService == nil {
		return []practice.Attempt{}
	}
	items, err := c.practiceService.ListAttemptsByQuestionID(ctx, questionID)
	if err != nil || len(items) == 0 {
		return []practice.Attempt{}
	}
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].SubmittedAt.Equal(items[j].SubmittedAt) {
			return items[i].ID > items[j].ID
		}
		return items[i].SubmittedAt.After(items[j].SubmittedAt)
	})
	return items
}

func summarizeAttemptAnswers(items []practice.Attempt) []map[string]any {
	if len(items) == 0 {
		return []map[string]any{}
	}
	out := make([]map[string]any, 0, len(items))
	for _, item := range items {
		out = append(out, map[string]any{
			"user_answer":  item.UserAnswer,
			"correct":      item.Correct,
			"score":        item.Score,
			"submitted_at": item.SubmittedAt,
		})
	}
	return out
}

func buildUpsertAgentRequest(params map[string]any) ai.UpsertAgentRequest {
	primary := asMap(params["primary"])
	fallback := asMap(params["fallback"])

	return ai.UpsertAgentRequest{
		Name:     asString(params["name"]),
		Protocol: ai.AgentProtocol(firstNonEmpty(asString(params["protocol"]), "")),
		Primary: ai.AgentProviderConfig{
			BaseURL: firstNonEmpty(asString(primary["base_url"]), asString(params["primary_base_url"])),
			APIKey:  firstNonEmpty(asString(primary["api_key"]), asString(params["primary_api_key"])),
			Model:   firstNonEmpty(asString(primary["model"]), asString(params["primary_model"])),
		},
		Fallback: ai.AgentProviderConfig{
			BaseURL: firstNonEmpty(asString(fallback["base_url"]), asString(params["fallback_base_url"])),
			APIKey:  firstNonEmpty(asString(fallback["api_key"]), asString(params["fallback_api_key"])),
			Model:   firstNonEmpty(asString(fallback["model"]), asString(params["fallback_model"])),
		},
		SystemPrompt:       asString(params["system_prompt"]),
		IntentCapabilities: pickStringSlice(params, "intent_capabilities", []string{"chat", "generate_questions", "build_plan", "manage_app"}),
		Enabled:            boolPtr(asBool(params["enabled"], true)),
	}
}

func firstNonNil(values ...any) any {
	for _, item := range values {
		if item != nil {
			return item
		}
	}
	return nil
}

func firstNonNegativeInt(values ...int) int {
	for _, item := range values {
		if item >= 0 {
			return item
		}
	}
	return 0
}

func asMap(v any) map[string]any {
	if v == nil {
		return map[string]any{}
	}
	if m, ok := v.(map[string]any); ok {
		return m
	}
	return map[string]any{}
}

func asStringMap(v any) map[string]string {
	raw := asMap(v)
	if len(raw) == 0 {
		return map[string]string{}
	}
	out := make(map[string]string, len(raw))
	for k, value := range raw {
		key := strings.TrimSpace(k)
		if key == "" {
			continue
		}
		out[key] = asString(value)
	}
	return out
}

func asFloatMap(v any) map[string]float64 {
	raw := asMap(v)
	if len(raw) == 0 {
		return map[string]float64{}
	}
	out := make(map[string]float64, len(raw))
	for key, value := range raw {
		name := strings.TrimSpace(key)
		if name == "" {
			continue
		}
		parsed, ok := asFloat(value)
		if !ok {
			continue
		}
		out[name] = parsed
	}
	return out
}

func asString(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return strings.TrimSpace(s)
	}
	return strings.TrimSpace(fmt.Sprintf("%v", v))
}

func asInt(v any, def int) int {
	switch x := v.(type) {
	case int:
		return x
	case int32:
		return int(x)
	case int64:
		return int(x)
	case float32:
		return int(x)
	case float64:
		return int(x)
	case string:
		text := strings.TrimSpace(x)
		if text == "" {
			return def
		}
		var out int
		_, _ = fmt.Sscanf(text, "%d", &out)
		if out == 0 {
			return def
		}
		return out
	default:
		return def
	}
}

func asFloat(v any) (float64, bool) {
	switch x := v.(type) {
	case float64:
		return x, true
	case float32:
		return float64(x), true
	case int:
		return float64(x), true
	case int32:
		return float64(x), true
	case int64:
		return float64(x), true
	case string:
		text := strings.TrimSpace(x)
		if text == "" {
			return 0, false
		}
		out, err := strconv.ParseFloat(text, 64)
		if err != nil {
			return 0, false
		}
		return out, true
	default:
		return 0, false
	}
}

func asBool(v any, def bool) bool {
	switch x := v.(type) {
	case bool:
		return x
	case string:
		text := strings.ToLower(strings.TrimSpace(x))
		if text == "true" || text == "1" || text == "yes" {
			return true
		}
		if text == "false" || text == "0" || text == "no" {
			return false
		}
	}
	return def
}

func asStringSlice(v any) []string {
	if v == nil {
		return []string{}
	}
	switch raw := v.(type) {
	case []string:
		out := make([]string, 0, len(raw))
		for _, item := range raw {
			text := strings.TrimSpace(item)
			if text != "" {
				out = append(out, text)
			}
		}
		return out
	case []any:
		out := make([]string, 0, len(raw))
		for _, item := range raw {
			text := asString(item)
			if text != "" {
				out = append(out, text)
			}
		}
		return out
	case string:
		text := strings.TrimSpace(raw)
		if text == "" {
			return []string{}
		}
		return []string{text}
	default:
		return []string{}
	}
}

func asQuestionOptions(v any) []question.Option {
	if v == nil {
		return []question.Option{}
	}
	rawList, ok := v.([]any)
	if !ok {
		return []question.Option{}
	}
	items := make([]question.Option, 0, len(rawList))
	for _, raw := range rawList {
		m := asMap(raw)
		key := asString(m["key"])
		text := asString(m["text"])
		if key == "" && text == "" {
			continue
		}
		items = append(items, question.Option{
			Key:   key,
			Text:  text,
			Score: asInt(m["score"], 0),
		})
	}
	return items
}

func pickStringSlice(params map[string]any, key string, def []string) []string {
	if !hasValue(params, key) {
		return def
	}
	return asStringSlice(params[key])
}

func pickInt(params map[string]any, key string, def int) int {
	if !hasValue(params, key) {
		return def
	}
	return asInt(params[key], def)
}

func hasValue(params map[string]any, key string) bool {
	_, ok := params[key]
	return ok
}

func firstNonEmpty(values ...string) string {
	for _, item := range values {
		trimmed := strings.TrimSpace(item)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func boolPtr(v bool) *bool {
	return &v
}
