package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"regexp"
	"sort"
	"strings"
	"time"

	"self-study-tool/internal/modules/plan"
	"self-study-tool/internal/platform/observability/logx"
	"self-study-tool/internal/shared/errs"
)

const (
	scheduleBindingModeAuto   = "auto"
	scheduleBindingModeManual = "manual"

	sessionScheduleBindingMetaKey = "schedule_binding"
)

type UpdateSessionScheduleBindingRequest struct {
	Mode          string   `json:"mode"`
	Theme         string   `json:"theme"`
	ManualPlanIDs []string `json:"manual_plan_ids"`
	AutoEnabled   *bool    `json:"auto_enabled"`
}

type SessionScheduleBindingResponse struct {
	Binding     ScheduleBinding `json:"binding"`
	MatchedPlans []plan.Item    `json:"matched_plans"`
}

type rankedPlanItem struct {
	Item  plan.Item
	Score int
}

func (s *Service) DefaultAgentProvider() DefaultAgentProvider {
	s.mu.RLock()
	defer s.mu.RUnlock()
	provider := strings.ToLower(strings.TrimSpace(s.runtime.Provider))
	protocol, cfg, ok := s.defaultAgentProviderConfigLocked()
	if !ok {
		return DefaultAgentProvider{
			Available: false,
			Provider:  provider,
		}
	}
	return DefaultAgentProvider{
		Available: true,
		Provider:  provider,
		Protocol:  protocol,
		Primary:   cfg,
	}
}

func (s *Service) GetSessionScheduleBinding(
	ctx context.Context,
	sessionID string,
) (SessionScheduleBindingResponse, error) {
	if s.agentStore == nil {
		return SessionScheduleBindingResponse{}, errs.BadRequest("ai agent store is not ready")
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return SessionScheduleBindingResponse{}, errs.BadRequest("session id is required")
	}
	session, err := s.agentStore.GetSessionByID(ctx, sessionID)
	if err != nil {
		return SessionScheduleBindingResponse{}, err
	}
	binding := scheduleBindingFromMeta(session.ContextSummaryMeta)
	items, _, _, err := s.resolveBoundSchedulePlans(ctx, binding, "", false)
	if err != nil {
		return SessionScheduleBindingResponse{}, err
	}
	return SessionScheduleBindingResponse{
		Binding:      binding,
		MatchedPlans: items,
	}, nil
}

func (s *Service) UpdateSessionScheduleBinding(
	ctx context.Context,
	sessionID string,
	req UpdateSessionScheduleBindingRequest,
) (SessionScheduleBindingResponse, error) {
	if s.agentStore == nil {
		return SessionScheduleBindingResponse{}, errs.BadRequest("ai agent store is not ready")
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return SessionScheduleBindingResponse{}, errs.BadRequest("session id is required")
	}
	session, err := s.agentStore.GetSessionByID(ctx, sessionID)
	if err != nil {
		return SessionScheduleBindingResponse{}, err
	}
	current := scheduleBindingFromMeta(session.ContextSummaryMeta)
	next, err := applyScheduleBindingUpdate(current, req)
	if err != nil {
		return SessionScheduleBindingResponse{}, err
	}
	items, autoTheme, matchedIDs, err := s.resolveBoundSchedulePlans(ctx, next, "", true)
	if err != nil {
		return SessionScheduleBindingResponse{}, err
	}
	if next.Mode == scheduleBindingModeAuto {
		next.LastAutoTheme = strings.TrimSpace(autoTheme)
		next.LastMatchedPlanIDs = cloneStringSlice(matchedIDs)
	} else {
		next.LastAutoTheme = ""
		next.LastMatchedPlanIDs = []string{}
	}
	next.UpdatedAt = nowRFC3339()

	meta := cloneAnyMap(session.ContextSummaryMeta)
	meta[sessionScheduleBindingMetaKey] = scheduleBindingToMap(next)
	if err := s.agentStore.UpdateSessionSummary(
		ctx,
		sessionID,
		session.ContextSummaryText,
		meta,
		session.ContextSummaryUpdatedAt,
		session.ContextSummaryMessageCount,
	); err != nil {
		return SessionScheduleBindingResponse{}, err
	}
	return SessionScheduleBindingResponse{
		Binding:      next,
		MatchedPlans: items,
	}, nil
}

func (s *Service) buildSessionSchedulePromptPatch(
	ctx context.Context,
	session AgentSession,
	latestUserInput string,
	persistAutoState bool,
) PromptRuntimePatch {
	binding := scheduleBindingFromMeta(session.ContextSummaryMeta)
	items, autoTheme, matchedIDs, err := s.resolveBoundSchedulePlans(ctx, binding, latestUserInput, false)
	if err != nil {
		logx.LoggerFromContext(ctx).Warn("ai session schedule binding resolve failed",
			slog.String("event", "ai.agent.schedule_binding"),
			slog.String("session_id", session.ID),
			slog.String("error", err.Error()),
		)
		return PromptRuntimePatch{}
	}
	if binding.Mode == scheduleBindingModeAuto {
		next := binding
		next.LastAutoTheme = strings.TrimSpace(autoTheme)
		next.LastMatchedPlanIDs = cloneStringSlice(matchedIDs)
		if persistAutoState &&
			(next.LastAutoTheme != binding.LastAutoTheme || !equalStringSlice(next.LastMatchedPlanIDs, binding.LastMatchedPlanIDs)) {
			next.UpdatedAt = nowRFC3339()
			meta := cloneAnyMap(session.ContextSummaryMeta)
			meta[sessionScheduleBindingMetaKey] = scheduleBindingToMap(next)
			if err := s.agentStore.UpdateSessionSummary(
				ctx,
				session.ID,
				session.ContextSummaryText,
				meta,
				session.ContextSummaryUpdatedAt,
				session.ContextSummaryMessageCount,
			); err != nil {
				logx.LoggerFromContext(ctx).Warn("ai session schedule binding persist failed",
					slog.String("event", "ai.agent.schedule_binding"),
					slog.String("session_id", session.ID),
					slog.String("error", err.Error()),
				)
			}
		}
		binding = next
	}
	segmentText := renderCurrentScheduleSegment(binding, items, autoTheme)
	if strings.TrimSpace(segmentText) == "" {
		return PromptRuntimePatch{}
	}
	return PromptRuntimePatch{
		SegmentUpdates: map[string]string{
			promptSegmentCurrentSchedule: segmentText,
		},
	}
}

func (s *Service) buildLearningSchedulePromptPatch(
	ctx context.Context,
	binding *ScheduleBinding,
	contextText string,
) PromptRuntimePatch {
	if binding == nil {
		return PromptRuntimePatch{}
	}
	normalized := normalizeScheduleBinding(*binding)
	items, autoTheme, _, err := s.resolveBoundSchedulePlans(ctx, normalized, contextText, false)
	if err != nil {
		logx.LoggerFromContext(ctx).Warn("ai learning schedule binding resolve failed",
			slog.String("event", "ai.learning.schedule_binding"),
			slog.String("error", err.Error()),
		)
		return PromptRuntimePatch{}
	}
	segmentText := renderCurrentScheduleSegment(normalized, items, autoTheme)
	if strings.TrimSpace(segmentText) == "" {
		return PromptRuntimePatch{}
	}
	return PromptRuntimePatch{
		SegmentUpdates: map[string]string{
			promptSegmentCurrentSchedule: segmentText,
		},
	}
}

func applyScheduleBindingUpdate(
	current ScheduleBinding,
	req UpdateSessionScheduleBindingRequest,
) (ScheduleBinding, error) {
	mode := strings.ToLower(strings.TrimSpace(req.Mode))
	if mode == "" {
		mode = current.Mode
	}
	if mode == "" {
		mode = scheduleBindingModeAuto
	}
	switch mode {
	case scheduleBindingModeAuto, scheduleBindingModeManual:
	default:
		return ScheduleBinding{}, errs.BadRequest("schedule binding mode must be auto or manual")
	}

	next := current
	next.Mode = mode
	next.Theme = strings.TrimSpace(req.Theme)
	next.ManualPlanIDs = normalizeStringSlice(req.ManualPlanIDs)
	if req.AutoEnabled == nil {
		next.AutoEnabled = mode == scheduleBindingModeAuto
	} else {
		next.AutoEnabled = *req.AutoEnabled
	}
	if mode != scheduleBindingModeAuto {
		next.LastAutoTheme = ""
		next.LastMatchedPlanIDs = []string{}
	}
	return normalizeScheduleBinding(next), nil
}

func scheduleBindingFromMeta(meta map[string]any) ScheduleBinding {
	out := ScheduleBinding{
		Mode:        scheduleBindingModeAuto,
		AutoEnabled: true,
	}
	if len(meta) == 0 {
		return out
	}
	raw, ok := meta[sessionScheduleBindingMetaKey]
	if !ok || raw == nil {
		return out
	}
	data, err := json.Marshal(raw)
	if err != nil {
		return out
	}
	_ = json.Unmarshal(data, &out)
	return normalizeScheduleBinding(out)
}

func scheduleBindingToMap(binding ScheduleBinding) map[string]any {
	data, _ := json.Marshal(normalizeScheduleBinding(binding))
	out := map[string]any{}
	_ = json.Unmarshal(data, &out)
	return out
}

func normalizeScheduleBinding(in ScheduleBinding) ScheduleBinding {
	out := in
	out.Mode = strings.ToLower(strings.TrimSpace(out.Mode))
	if out.Mode == "" {
		out.Mode = scheduleBindingModeAuto
	}
	if out.Mode != scheduleBindingModeAuto && out.Mode != scheduleBindingModeManual {
		out.Mode = scheduleBindingModeAuto
	}
	out.Theme = strings.TrimSpace(out.Theme)
	out.ManualPlanIDs = normalizeStringSlice(out.ManualPlanIDs)
	if out.Mode == scheduleBindingModeAuto && !out.AutoEnabled && strings.TrimSpace(out.UpdatedAt) == "" {
		out.AutoEnabled = true
	}
	out.UpdatedAt = strings.TrimSpace(out.UpdatedAt)
	out.LastAutoTheme = strings.TrimSpace(out.LastAutoTheme)
	out.LastMatchedPlanIDs = normalizeStringSlice(out.LastMatchedPlanIDs)
	return out
}

func (s *Service) resolveBoundSchedulePlans(
	ctx context.Context,
	binding ScheduleBinding,
	latestUserInput string,
	strictManualIDs bool,
) ([]plan.Item, string, []string, error) {
	if s.planService == nil {
		return []plan.Item{}, "", []string{}, nil
	}
	switch binding.Mode {
	case scheduleBindingModeManual:
		if len(binding.ManualPlanIDs) > 0 {
			items := make([]plan.Item, 0, len(binding.ManualPlanIDs))
			for _, id := range binding.ManualPlanIDs {
				item, err := s.planService.GetByID(ctx, id)
				if err != nil {
					if strictManualIDs {
						return nil, "", nil, errs.BadRequest(fmt.Sprintf("manual_plan_id not found: %s", id))
					}
					continue
				}
				items = append(items, item)
			}
			return items, "", extractPlanIDs(items), nil
		}
		keywords := extractScheduleKeywords(binding.Theme)
		items, err := s.matchPlansByKeywords(ctx, keywords)
		if err != nil {
			return nil, "", nil, err
		}
		return items, strings.TrimSpace(binding.Theme), extractPlanIDs(items), nil
	case scheduleBindingModeAuto:
		if !binding.AutoEnabled {
			return []plan.Item{}, "", []string{}, nil
		}
		autoKeywords := extractScheduleKeywords(latestUserInput)
		if len(autoKeywords) == 0 {
			autoKeywords = extractScheduleKeywords(binding.Theme)
		}
		if len(autoKeywords) == 0 {
			autoKeywords = extractScheduleKeywords(binding.LastAutoTheme)
		}
		items, err := s.matchPlansByKeywords(ctx, autoKeywords)
		if err != nil {
			return nil, "", nil, err
		}
		return items, strings.Join(autoKeywords, " "), extractPlanIDs(items), nil
	default:
		return []plan.Item{}, "", []string{}, nil
	}
}

func (s *Service) matchPlansByKeywords(ctx context.Context, keywords []string) ([]plan.Item, error) {
	if len(keywords) == 0 {
		return []plan.Item{}, nil
	}
	items, err := s.planService.List(ctx, "")
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	ranked := make([]rankedPlanItem, 0, len(items))
	for _, item := range items {
		keywordScore := keywordMatchScore(item, keywords)
		if keywordScore == 0 {
			continue
		}
		score := keywordScore*100 +
			scheduleStatusWeight(item.Status) +
			scheduleDateWeight(now, item.TargetDate) +
			schedulePriorityWeight(item.Priority)
		ranked = append(ranked, rankedPlanItem{
			Item:  item,
			Score: score,
		})
	}
	sort.SliceStable(ranked, func(i, j int) bool {
		if ranked[i].Score == ranked[j].Score {
			return strings.TrimSpace(ranked[i].Item.UpdatedAt.Format(time.RFC3339Nano)) >
				strings.TrimSpace(ranked[j].Item.UpdatedAt.Format(time.RFC3339Nano))
		}
		return ranked[i].Score > ranked[j].Score
	})
	out := make([]plan.Item, 0, minInt(len(ranked), 8))
	for i := 0; i < len(ranked) && i < 8; i++ {
		out = append(out, ranked[i].Item)
	}
	return out, nil
}

func keywordMatchScore(item plan.Item, keywords []string) int {
	title := strings.ToLower(strings.TrimSpace(item.Title))
	content := strings.ToLower(strings.TrimSpace(item.Content))
	score := 0
	for _, keyword := range keywords {
		k := strings.ToLower(strings.TrimSpace(keyword))
		if k == "" {
			continue
		}
		if strings.Contains(title, k) {
			score += 3
		}
		if strings.Contains(content, k) {
			score += 1
		}
	}
	return score
}

func scheduleStatusWeight(status string) int {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "in_progress":
		return 80
	case "pending":
		return 60
	case "rescheduled":
		return 30
	case "completed", "done":
		return 10
	default:
		return 20
	}
}

func scheduleDateWeight(now time.Time, targetDate string) int {
	targetDate = strings.TrimSpace(targetDate)
	if targetDate == "" {
		return 0
	}
	ts, err := time.Parse("2006-01-02", targetDate)
	if err != nil {
		return 0
	}
	days := int(ts.Sub(now).Hours() / 24)
	if days < 0 {
		return scheduleMaxInt(0, 5-absInt(days))
	}
	return scheduleMaxInt(0, 30-days)
}

func schedulePriorityWeight(priority int) int {
	if priority <= 0 {
		return 0
	}
	p := priority
	if p > 10 {
		p = 10
	}
	return 11 - p
}

func extractScheduleKeywords(text string) []string {
	text = strings.TrimSpace(text)
	if text == "" {
		return []string{}
	}
	re := regexp.MustCompile(`[A-Za-z0-9_]+|[\p{Han}]{2,}`)
	matches := re.FindAllString(text, -1)
	out := make([]string, 0, len(matches))
	seen := make(map[string]struct{}, len(matches))
	for _, item := range matches {
		key := strings.TrimSpace(strings.ToLower(item))
		if len([]rune(key)) < 2 {
			continue
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, key)
		if len(out) >= 8 {
			break
		}
	}
	return out
}

func renderCurrentScheduleSegment(binding ScheduleBinding, items []plan.Item, autoTheme string) string {
	if len(items) == 0 {
		return ""
	}
	mode := strings.ToLower(strings.TrimSpace(binding.Mode))
	if mode == "" {
		mode = scheduleBindingModeAuto
	}
	theme := strings.TrimSpace(binding.Theme)
	if mode == scheduleBindingModeAuto && strings.TrimSpace(autoTheme) != "" {
		theme = strings.TrimSpace(autoTheme)
	}
	lines := make([]string, 0, len(items)+4)
	lines = append(lines, "Linked schedule context:")
	lines = append(lines, "binding_mode="+mode)
	if theme != "" {
		lines = append(lines, "theme="+theme)
	}
	for idx, item := range items {
		targetDate := strings.TrimSpace(item.TargetDate)
		if targetDate == "" {
			targetDate = "-"
		}
		content := compactSpaces(item.Content)
		if len(content) > 90 {
			content = content[:90] + "..."
		}
		lines = append(lines, fmt.Sprintf(
			"%d) %s | date=%s | status=%s | priority=%d | source=%s | note=%s",
			idx+1,
			strings.TrimSpace(item.Title),
			targetDate,
			strings.TrimSpace(item.Status),
			item.Priority,
			strings.TrimSpace(string(item.Source)),
			content,
		))
	}
	return strings.TrimSpace(strings.Join(lines, "\n"))
}

func extractPlanIDs(items []plan.Item) []string {
	out := make([]string, 0, len(items))
	for _, item := range items {
		id := strings.TrimSpace(item.ID)
		if id == "" {
			continue
		}
		out = append(out, id)
	}
	return out
}

func equalStringSlice(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for idx := range left {
		if !strings.EqualFold(strings.TrimSpace(left[idx]), strings.TrimSpace(right[idx])) {
			return false
		}
	}
	return true
}

func cloneStringSlice(items []string) []string {
	if len(items) == 0 {
		return []string{}
	}
	out := make([]string, 0, len(items))
	for _, item := range items {
		out = append(out, strings.TrimSpace(item))
	}
	return out
}

func mergePromptRuntimePatch(base, extra PromptRuntimePatch) PromptRuntimePatch {
	out := normalizePromptRuntimePatch(base)
	next := normalizePromptRuntimePatch(extra)
	if next.ReplaceSegments {
		out.ReplaceSegments = true
		out.SegmentUpdates = map[string]string{}
		out.SegmentDeletes = []string{}
	}
	if out.SegmentUpdates == nil {
		out.SegmentUpdates = map[string]string{}
	}
	for key, value := range next.SegmentUpdates {
		out.SegmentUpdates[key] = value
	}
	if len(next.SegmentDeletes) > 0 {
		out.SegmentDeletes = append(out.SegmentDeletes, next.SegmentDeletes...)
	}
	return out
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func scheduleMaxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func absInt(v int) int {
	if v < 0 {
		return -v
	}
	return v
}
