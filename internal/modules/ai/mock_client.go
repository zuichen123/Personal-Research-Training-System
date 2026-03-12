package ai

import (
	"context"
	"fmt"
	"strings"
	"time"

	"prts/internal/modules/question"
)

type MockClient struct {
	latency time.Duration
}

func NewMockClient(latency time.Duration) *MockClient {
	return &MockClient{latency: latency}
}

func (m *MockClient) ProviderName() string {
	return "mock"
}

func (m *MockClient) ModelName() string {
	return "mock-v1"
}

func (m *MockClient) IsReady() bool {
	return true
}

func (m *MockClient) GenerateQuestions(ctx context.Context, req GenerateRequest) ([]question.CreateInput, error) {
	req = normalizeGenerateRequest(req)

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(m.latency):
	}

	result := make([]question.CreateInput, 0, req.Count)
	for i := 1; i <= req.Count; i++ {
		tags := []string{req.Topic, "ai_generated"}
		if req.Scope != "" {
			tags = append(tags, req.Scope)
		}

		result = append(result, question.CreateInput{
			Title:        fmt.Sprintf("%s Practice #%d", req.Topic, i),
			Stem:         fmt.Sprintf("Briefly explain the key points of %s (Q%d)", req.Topic, i),
			Type:         question.ShortAnswer,
			Subject:      req.Subject,
			Source:       question.SourceAIGenerated,
			AnswerKey:    []string{"core concept", "application scenario"},
			Difficulty:   req.Difficulty,
			MasteryLevel: 0,
			Tags:         tags,
		})
	}
	return result, nil
}

func (m *MockClient) GradeAnswer(ctx context.Context, req GradeRequest) (GradeResult, error) {
	select {
	case <-ctx.Done():
		return GradeResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	if len(req.UserAnswer) == 0 && len(req.Attachments) > 0 {
		return GradeResult{
			Score:       0,
			Correct:     false,
			Feedback:    "mock provider cannot interpret media attachments yet",
			Analysis:    "No text answer was provided; only media attachments were received.",
			Explanation: "Mock provider does not parse image/audio content. Please add a text answer for deterministic grading.",
			WrongReason: "media understanding unavailable in mock provider",
		}, nil
	}

	if len(req.Question.AnswerKey) == 0 {
		return GradeResult{
			Score:    0,
			Correct:  false,
			Feedback: "question has no answer key configured",
			Analysis: "Cannot evaluate because answer_key is empty.",
		}, nil
	}

	normalizedAnswer := strings.ToLower(strings.Join(req.UserAnswer, " "))
	hits := 0
	for _, expected := range req.Question.AnswerKey {
		if strings.Contains(normalizedAnswer, strings.ToLower(strings.TrimSpace(expected))) {
			hits++
		}
	}

	score := float64(hits) / float64(len(req.Question.AnswerKey)) * 100
	correct := score >= 60

	result := GradeResult{
		Score:         score,
		Correct:       correct,
		Feedback:      fmt.Sprintf("hit key points %d/%d", hits, len(req.Question.AnswerKey)),
		Analysis:      fmt.Sprintf("Matched %d expected key points out of %d.", hits, len(req.Question.AnswerKey)),
		Explanation:   "Compare the expected key points with your answer and fill in missing concepts.",
		ModelMetadata: "provider=mock",
	}
	if !correct {
		result.WrongReason = "insufficient key-point coverage"
	}

	return result, nil
}

func (m *MockClient) BuildLearningPlan(ctx context.Context, req LearnRequest) (LearnResult, error) {
	select {
	case <-ctx.Done():
		return LearnResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	now := time.Now().UTC()
	mode := strings.TrimSpace(req.Mode)
	if mode == "" {
		mode = "long_term_learning"
	}
	subject := strings.TrimSpace(req.Subject)
	if subject == "" {
		subject = "general"
	}
	unit := strings.TrimSpace(req.Unit)
	if unit == "" {
		unit = "general unit"
	}

	finalGoal := strings.TrimSpace(req.FinalGoal)
	if finalGoal == "" {
		finalGoal = strings.Join(req.Goals, "; ")
	}
	if finalGoal == "" {
		finalGoal = fmt.Sprintf("Build a stable study rhythm for %s", subject)
	}

	currentStatus := strings.TrimSpace(req.CurrentStatus)
	if currentStatus == "" {
		currentStatus = strings.TrimSpace(req.CurrentStage)
	}
	if currentStatus == "" {
		currentStatus = "pending"
	}

	start := parseDateOrDefault(req.StartDate, now)
	end := parseDateOrDefault(req.EndDate, start.AddDate(0, 3, 0))
	if end.Before(start) {
		end = start.AddDate(0, 0, 30)
	}

	durationDays := int(end.Sub(start).Hours()/24) + 1
	if durationDays < 1 {
		durationDays = 1
	}

	totalHours := req.TotalHours
	if totalHours <= 0 {
		if req.Profile.DailyStudyMinutes > 0 {
			totalHours = req.Profile.DailyStudyMinutes * durationDays / 60
		}
		if totalHours <= 0 {
			totalHours = maxInt(20, durationDays/2)
		}
	}

	outline := []string{
		"Break down the final goal into theme-level milestones",
		"Track daily progress and re-plan weekly",
		"Reserve weekly review slots for weak points",
	}
	if strings.Contains(strings.ToLower(mode), "review") {
		outline = []string{
			"Audit mistakes and classify weak knowledge points",
			"Redo core exercises without notes",
			"Perform one mixed review at the end of each week",
		}
	}
	checklist := []string{
		"Can explain each theme with examples",
		"Can finish planned daily tasks on time",
		"Can adjust schedule when delays happen",
	}

	themes := normalizeThemes(req.Themes, subject)
	themePlans := make([]LearnTheme, 0, len(themes))
	hoursPerTheme := float64(totalHours) / float64(maxInt(1, len(themes)))
	for _, theme := range themes {
		nodes := buildThemeNodes(theme, start, end, hoursPerTheme, req.Goals)
		themePlans = append(themePlans, LearnTheme{
			Name:           theme,
			EstimatedHours: roundOneDecimal(hoursPerTheme),
			Children:       nodes,
		})
	}

	missingFields, followUp := missingLearnInputs(req)
	planItems := planItemsFromThemes(themePlans, currentStatus)
	planItems = append([]LearnPlanItemNote{{
		PlanType:   "current_phase",
		Title:      fmt.Sprintf("AI plan: %s", finalGoal),
		Content:    fmt.Sprintf("Period %s ~ %s; mode=%s; subject=%s", formatDate(start), formatDate(end), mode, subject),
		TargetDate: formatDate(end),
		Status:     currentStatus,
		Priority:   1,
	}}, planItems...)

	return LearnResult{
		Mode:              mode,
		Subject:           subject,
		Unit:              unit,
		CreatedAt:         now.Format(time.RFC3339),
		FinalGoal:         finalGoal,
		CurrentStatus:     currentStatus,
		PlanStartDate:     formatDate(start),
		PlanEndDate:       formatDate(end),
		StudyOutline:      outline,
		ReviewChecklist:   checklist,
		StageSuggestion:   "Start from month/week plans and execute day plans strictly. Use manual optimization when schedule shifts.",
		MissingFields:     missingFields,
		FollowUpQuestions: followUp,
		Themes:            themePlans,
		PlanItems:         planItems,
		OptimizationHints: []string{
			"If delayed, trigger optimize with action=postpone and provide delay reason.",
			"If completed early, trigger optimize with action=complete_early to refill review tasks.",
		},
	}, nil
}

func (m *MockClient) OptimizeLearningPlan(ctx context.Context, req OptimizeLearnRequest) (OptimizeLearnResult, error) {
	select {
	case <-ctx.Done():
		return OptimizeLearnResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	action := strings.ToLower(strings.TrimSpace(req.Action))
	if action == "" {
		action = "postpone"
	}
	updated := req.Plan
	summary := make([]string, 0, 4)

	switch action {
	case "postpone":
		days := maxInt(1, req.Days)
		shiftLearnResult(&updated, days)
		updated.CurrentStatus = "rescheduled"
		summary = append(summary, fmt.Sprintf("Plan postponed by %d day(s).", days))
	case "advance":
		days := maxInt(1, req.Days)
		shiftLearnResult(&updated, -days)
		if strings.TrimSpace(updated.CurrentStatus) == "" || updated.CurrentStatus == "pending" {
			updated.CurrentStatus = "in_progress"
		}
		summary = append(summary, fmt.Sprintf("Plan advanced by %d day(s).", days))
	case "complete_early":
		updated.CurrentStatus = "completed_early"
		summary = append(summary, "Current phase marked as completed early.")
		updated.OptimizationHints = append(updated.OptimizationHints,
			"Use freed time for weak-subject consolidation or mixed mock exams.")
	default:
		summary = append(summary, "No optimization action applied because action is unsupported.")
	}

	if reason := strings.TrimSpace(req.Reason); reason != "" {
		summary = append(summary, "Reason: "+reason)
	}
	if supplement := strings.TrimSpace(req.Supplement); supplement != "" {
		summary = append(summary, "Supplement: "+supplement)
	}

	return OptimizeLearnResult{
		Action:        action,
		ChangeSummary: summary,
		UpdatedPlan:   updated,
	}, nil
}

func (m *MockClient) EvaluateLearning(ctx context.Context, req EvaluateRequest) (EvaluateResult, error) {
	select {
	case <-ctx.Done():
		return EvaluateResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	grade, _ := m.GradeAnswer(ctx, GradeRequest{
		Question:   req.Question,
		UserAnswer: req.UserAnswer,
	})

	retest := []question.CreateInput{}
	if !grade.Correct {
		retest = append(retest, question.CreateInput{
			Title:        "Retest: key point reconstruction",
			Stem:         "List the missing key points and explain with one example",
			Type:         question.ShortAnswer,
			Subject:      req.Question.Subject,
			Source:       question.SourceWrongBook,
			AnswerKey:    req.Question.AnswerKey,
			Difficulty:   req.Question.Difficulty,
			MasteryLevel: 0,
			Tags:         []string{"retest", "ai_review"},
		})
	}

	return EvaluateResult{
		Score:                    grade.Score,
		SingleEvaluation:         fmt.Sprintf("Single-question evaluation: %s", grade.Feedback),
		ComprehensiveEvaluation:  "Comprehensive evaluation: topic coverage is improving but still uneven",
		SingleExplanation:        "Single explanation: focus on key concept + condition + application",
		ComprehensiveExplanation: "Comprehensive explanation: connect concepts across this unit before mixed tests",
		KnowledgeSupplements: []string{
			"Add one contrasting example for each key concept",
			"Build a small mistake-to-concept map",
		},
		RetestQuestions: retest,
	}, nil
}

func (m *MockClient) ScoreLearning(ctx context.Context, req ScoreRequest) (ScoreResult, error) {
	select {
	case <-ctx.Done():
		return ScoreResult{}, ctx.Err()
	case <-time.After(m.latency):
	}

	score := req.Accuracy*0.5 + req.Stability*0.3 + req.Speed*0.2
	score = roundOneDecimal(score)

	advice := []string{
		"Prioritize weak knowledge nodes from mistakes",
		"Schedule one comprehensive review session every 3 days",
	}
	if score >= 85 {
		advice = []string{
			"Increase mixed-difficulty exercises",
			"Shift focus from accuracy to speed and consistency",
		}
	}

	return ScoreResult{
		Score:  score,
		Grade:  "",
		Advice: advice,
	}, nil
}

func (m *MockClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	select {
	case <-ctx.Done():
		return ChatResponse{}, ctx.Err()
	case <-time.After(m.latency):
	}

	lastUser := ""
	for i := len(req.Messages) - 1; i >= 0; i-- {
		if strings.EqualFold(strings.TrimSpace(req.Messages[i].Role), "user") {
			lastUser = strings.TrimSpace(req.Messages[i].Content)
			break
		}
	}
	modeConfig := resolveChatModeConfig(req.Mode)
	if modeConfig.promptKey == PromptKeyCompressSession {
		summary := "Mock summary: conversation compressed for long-term context."
		if lastUser != "" {
			summary = "Mock summary: " + truncateMockText(lastUser, 220)
		}
		return ChatResponse{
			Content: summary,
			Intent: IntentResult{
				Action: "none",
				Params: map[string]any{},
			},
		}, nil
	}
	if modeConfig.promptKey == PromptKeyDetectIntent {
		intent := IntentResult{
			Action:     "none",
			Confidence: 0.1,
			Reason:     "no clear execution intent",
			Params:     map[string]any{},
		}
		lower := strings.ToLower(lastUser)
		if (strings.Contains(lower, "删除") || strings.Contains(lower, "delete")) &&
			(strings.Contains(lower, "计划") || strings.Contains(lower, "plan")) &&
			(strings.Contains(lower, "全部") || strings.Contains(lower, "所有") || strings.Contains(lower, "all")) {
			intent.Action = "manage_app"
			intent.Confidence = 0.9
			intent.Reason = "bulk plan delete command detected"
			intent.Params = map[string]any{
				"module":    "plan",
				"operation": "delete_all",
				"all":       true,
			}
		} else if strings.Contains(lower, "agent") || strings.Contains(lower, "智能体") {
			intent.Action = "manage_app"
			intent.Confidence = 0.88
			intent.Reason = "agent management keyword detected"
			intent.Params = map[string]any{
				"module":    "agent",
				"operation": "create",
				"name":      "new-agent",
				"protocol":  "openai_compatible",
				"primary": map[string]any{
					"model": "gpt-4o-mini",
				},
			}
		} else if strings.Contains(lower, "题目") || strings.Contains(lower, "question") {
			intent.Action = "generate_questions"
			intent.Confidence = 0.85
			intent.Reason = "question generation keyword detected"
		} else if strings.Contains(lower, "计划") || strings.Contains(lower, "plan") {
			if strings.Contains(lower, "删除") || strings.Contains(lower, "delete") {
				intent.Action = "manage_app"
				intent.Confidence = 0.86
				intent.Reason = "plan delete command detected"
				intent.Params = map[string]any{
					"module":    "plan",
					"operation": "delete",
				}
			} else {
				intent.Action = "build_plan"
				intent.Confidence = 0.85
				intent.Reason = "learning plan keyword detected"
			}
		} else if strings.Contains(lower, "删除") && strings.Contains(lower, "题目") {
			intent.Action = "manage_app"
			intent.Confidence = 0.86
			intent.Reason = "question delete command detected"
			intent.Params = map[string]any{
				"module":    "question",
				"operation": "delete",
			}
		}
		return ChatResponse{Intent: intent}, nil
	}

	content := "Mock agent response: I have received your message."
	if lastUser != "" {
		content = "Mock agent response: " + lastUser
	}
	return ChatResponse{
		Content: content,
		Intent: IntentResult{
			Action: "none",
			Params: map[string]any{},
		},
	}, nil
}

func normalizeThemes(themes []string, subject string) []string {
	result := make([]string, 0, len(themes))
	for _, theme := range themes {
		t := strings.TrimSpace(theme)
		if t == "" {
			continue
		}
		result = append(result, t)
	}
	if len(result) > 0 {
		return result
	}
	if strings.TrimSpace(subject) != "" {
		return []string{strings.TrimSpace(subject)}
	}
	return []string{"general"}
}

func missingLearnInputs(req LearnRequest) ([]string, []string) {
	missing := []string{}
	questions := []string{}
	if strings.TrimSpace(req.FinalGoal) == "" {
		missing = append(missing, "final_goal")
		questions = append(questions, "What is your final target (exam/school/certification)?")
	}
	if req.TotalHours <= 0 {
		missing = append(missing, "total_hours")
		questions = append(questions, "How many study hours can you commit in total?")
	}
	if strings.TrimSpace(req.StartDate) == "" {
		missing = append(missing, "start_date")
		questions = append(questions, "When do you want to start?")
	}
	if strings.TrimSpace(req.EndDate) == "" {
		missing = append(missing, "end_date")
		questions = append(questions, "What is your expected end date?")
	}
	if strings.TrimSpace(req.CurrentStatus) == "" && strings.TrimSpace(req.CurrentStage) == "" {
		missing = append(missing, "current_status")
		questions = append(questions, "What is your current learning stage/status?")
	}
	if len(req.Themes) == 0 {
		missing = append(missing, "themes")
		questions = append(questions, "Which themes/subjects should be included in this plan?")
	}
	return missing, questions
}

func buildThemeNodes(
	theme string,
	start, end time.Time,
	hours float64,
	goals []string,
) []LearnPlanNode {
	levels := []string{"month", "week", "day", "task"}
	durationDays := int(end.Sub(start).Hours()/24) + 1
	switch {
	case durationDays > 240:
		levels = []string{"year", "month", "week", "day", "task"}
	case durationDays <= 14:
		levels = []string{"day", "task"}
	case durationDays <= 60:
		levels = []string{"week", "day", "task"}
	}
	return buildNodesByLevel(levels, theme, start, end, hours, goals)
}

func buildNodesByLevel(
	levels []string,
	theme string,
	start, end time.Time,
	hours float64,
	goals []string,
) []LearnPlanNode {
	if len(levels) == 0 {
		return nil
	}
	level := levels[0]
	if level == "task" {
		tasks := normalizeGoals(goals)
		taskHours := hours / float64(maxInt(1, len(tasks)))
		nodes := make([]LearnPlanNode, 0, len(tasks))
		for i, task := range tasks {
			nodes = append(nodes, LearnPlanNode{
				Level:          "task",
				Title:          fmt.Sprintf("%s task %d", theme, i+1),
				EstimatedHours: roundOneDecimal(taskHours),
				StartDate:      formatDate(start),
				EndDate:        formatDate(end),
				Details:        []string{task},
			})
		}
		return nodes
	}

	segments := segmentCount(level)
	totalDays := maxInt(1, int(end.Sub(start).Hours()/24)+1)
	spanDays := maxInt(1, totalDays/segments)
	nodes := make([]LearnPlanNode, 0, segments)
	for i := 0; i < segments; i++ {
		segStart := start.AddDate(0, 0, i*spanDays)
		segEnd := segStart.AddDate(0, 0, spanDays-1)
		if i == segments-1 || segEnd.After(end) {
			segEnd = end
		}
		children := buildNodesByLevel(levels[1:], theme, segStart, segEnd, hours/float64(segments), goals)
		nodes = append(nodes, LearnPlanNode{
			Level:          level,
			Title:          fmt.Sprintf("%s %d", titleLevel(level), i+1),
			EstimatedHours: roundOneDecimal(hours / float64(segments)),
			StartDate:      formatDate(segStart),
			EndDate:        formatDate(segEnd),
			Details: []string{
				fmt.Sprintf("Theme: %s", theme),
				fmt.Sprintf("Focus window: %s ~ %s", formatDate(segStart), formatDate(segEnd)),
			},
			Children: children,
		})
	}
	return nodes
}

func normalizeGoals(goals []string) []string {
	out := make([]string, 0, len(goals))
	for _, goal := range goals {
		g := strings.TrimSpace(goal)
		if g == "" {
			continue
		}
		out = append(out, g)
	}
	if len(out) == 0 {
		return []string{
			"Read key concepts and build notes",
			"Complete focused practice set",
		}
	}
	return out
}

func segmentCount(level string) int {
	switch level {
	case "year":
		return 1
	case "month":
		return 2
	case "week":
		return 2
	case "day":
		return 3
	default:
		return 1
	}
}

func planItemsFromThemes(themes []LearnTheme, status string) []LearnPlanItemNote {
	flat := make([]LearnPlanItemNote, 0, 24)
	for _, theme := range themes {
		flattenPlanItems(theme.Children, &flat, status)
	}
	if len(flat) > 24 {
		return flat[:24]
	}
	return flat
}

func flattenPlanItems(nodes []LearnPlanNode, out *[]LearnPlanItemNote, status string) {
	for _, node := range nodes {
		if len(*out) >= 24 {
			return
		}
		*out = append(*out, LearnPlanItemNote{
			PlanType:   mapPlanType(node.Level),
			Title:      node.Title,
			Content:    strings.Join(node.Details, "; "),
			TargetDate: node.EndDate,
			Status:     status,
			Priority:   3,
		})
		flattenPlanItems(node.Children, out, status)
	}
}

func mapPlanType(level string) string {
	switch level {
	case "year":
		return "year_plan"
	case "month":
		return "month_plan"
	case "week":
		return "week_plan"
	case "day", "task":
		return "day_plan"
	default:
		return "current_phase"
	}
}

func shiftLearnResult(plan *LearnResult, days int) {
	plan.PlanStartDate = shiftDate(plan.PlanStartDate, days)
	plan.PlanEndDate = shiftDate(plan.PlanEndDate, days)
	for i := range plan.Themes {
		shiftNodes(plan.Themes[i].Children, days)
	}
	for i := range plan.PlanItems {
		plan.PlanItems[i].TargetDate = shiftDate(plan.PlanItems[i].TargetDate, days)
	}
}

func shiftNodes(nodes []LearnPlanNode, days int) {
	for i := range nodes {
		nodes[i].StartDate = shiftDate(nodes[i].StartDate, days)
		nodes[i].EndDate = shiftDate(nodes[i].EndDate, days)
		shiftNodes(nodes[i].Children, days)
	}
}

func shiftDate(raw string, days int) string {
	if strings.TrimSpace(raw) == "" {
		return raw
	}
	dt, err := time.Parse("2006-01-02", raw)
	if err != nil {
		return raw
	}
	return formatDate(dt.AddDate(0, 0, days))
}

func parseDateOrDefault(raw string, fallback time.Time) time.Time {
	if strings.TrimSpace(raw) == "" {
		return fallback
	}
	dt, err := time.Parse("2006-01-02", raw)
	if err != nil {
		return fallback
	}
	return dt
}

func formatDate(dt time.Time) string {
	return dt.Format("2006-01-02")
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func truncateMockText(s string, max int) string {
	trimmed := strings.TrimSpace(s)
	if max <= 0 || len(trimmed) <= max {
		return trimmed
	}
	if max <= 3 {
		return trimmed[:max]
	}
	return trimmed[:max-3] + "..."
}

func titleLevel(level string) string {
	switch level {
	case "year":
		return "Year"
	case "month":
		return "Month"
	case "week":
		return "Week"
	case "day":
		return "Day"
	case "task":
		return "Task"
	default:
		return "Plan"
	}
}
