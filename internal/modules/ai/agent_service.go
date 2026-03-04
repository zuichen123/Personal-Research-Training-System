package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"self-study-tool/internal/modules/plan"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/platform/observability/logx"
	"self-study-tool/internal/shared/errs"
)

const (
	agentIntentAutoThreshold    = 0.75
	agentIntentConfirmThreshold = 0.45
	agentContextKeepRecent      = 20

	agentAutoCompressMinNewMessages = 30
	agentAutoCompressCooldown       = 30 * time.Minute
	agentAutoCompressStaleAfter     = 7 * 24 * time.Hour
)

type UpsertAgentRequest struct {
	Name               string              `json:"name"`
	Protocol           AgentProtocol       `json:"protocol"`
	Primary            AgentProviderConfig `json:"primary"`
	Fallback           AgentProviderConfig `json:"fallback"`
	SystemPrompt       string              `json:"system_prompt"`
	IntentCapabilities []string            `json:"intent_capabilities"`
	Enabled            *bool               `json:"enabled"`
}

type CreateSessionRequest struct {
	Title string `json:"title"`
}

type SendSessionMessageRequest struct {
	Content string `json:"content"`
}

type ConfirmActionRequest struct {
	MessageID string         `json:"message_id"`
	Action    string         `json:"action"`
	Params    map[string]any `json:"params"`
}

type ImportQuestionsRequest struct {
	SelectedIndexes    []int  `json:"selected_indexes"`
	SubjectOverride    string `json:"subject_override"`
	DifficultyOverride int    `json:"difficulty_override"`
}

type ImportPlanRequest struct {
	Append bool `json:"append"`
}

type CompressSessionRequest struct {
	Force   bool   `json:"force"`
	Trigger string `json:"trigger"`
}

type CompressSessionResult struct {
	Status           string `json:"status"`
	SessionID        string `json:"session_id"`
	Trigger          string `json:"trigger"`
	SummarizedCount  int    `json:"summarized_count"`
	KeptRecentCount  int    `json:"kept_recent_count"`
	SummaryUpdatedAt string `json:"summary_updated_at,omitempty"`
	SummaryPreview   string `json:"summary_preview,omitempty"`
}

type ImportQuestionsResult struct {
	ImportedCount int      `json:"imported_count"`
	QuestionIDs   []string `json:"question_ids"`
}

type ImportPlanResult struct {
	ImportedCount int      `json:"imported_count"`
	PlanIDs       []string `json:"plan_ids"`
}

type SessionMessageResponse struct {
	AssistantMessage    AgentMessage         `json:"assistant_message"`
	Intent              IntentResult         `json:"intent"`
	PendingConfirmation *PendingConfirmation `json:"pending_confirmation,omitempty"`
	Artifact            *AgentArtifact       `json:"artifact,omitempty"`
}

type agentCallMeta struct {
	ProviderUsed string
	ModelUsed    string
	FallbackUsed bool
	LatencyMS    int64
}

type actionExecutionResult struct {
	Content         string
	ArtifactType    string
	ArtifactPayload map[string]any
	Meta            agentCallMeta
}

func (s *Service) ListAgents(ctx context.Context) ([]Agent, error) {
	if s.agentStore == nil {
		return []Agent{}, nil
	}
	items, err := s.agentStore.ListAgents(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]Agent, 0, len(items))
	for _, item := range items {
		out = append(out, redactAgentSecrets(item))
	}
	return out, nil
}

func (s *Service) CreateAgent(ctx context.Context, req UpsertAgentRequest) (Agent, error) {
	if s.agentStore == nil {
		return Agent{}, errs.BadRequest("ai agent store is not ready")
	}
	item, err := normalizeAgentRequest(req, "")
	if err != nil {
		return Agent{}, err
	}
	item.ID = uuid.NewString()
	item.CreatedAt = nowRFC3339()
	item.UpdatedAt = item.CreatedAt
	created, err := s.agentStore.CreateAgent(ctx, item)
	if err != nil {
		return Agent{}, err
	}
	return redactAgentSecrets(created), nil
}

func (s *Service) UpdateAgent(ctx context.Context, id string, req UpsertAgentRequest) (Agent, error) {
	if s.agentStore == nil {
		return Agent{}, errs.BadRequest("ai agent store is not ready")
	}
	id = strings.TrimSpace(id)
	if id == "" {
		return Agent{}, errs.BadRequest("agent id is required")
	}
	existing, err := s.agentStore.GetAgentByID(ctx, id)
	if err != nil {
		return Agent{}, err
	}
	merged := mergeAgentRequest(existing, req)
	normalized, err := normalizeAgentRequest(merged, id)
	if err != nil {
		return Agent{}, err
	}
	normalized.CreatedAt = existing.CreatedAt
	normalized.UpdatedAt = nowRFC3339()
	updated, err := s.agentStore.UpdateAgent(ctx, normalized)
	if err != nil {
		return Agent{}, err
	}
	return redactAgentSecrets(updated), nil
}

func (s *Service) DeleteAgent(ctx context.Context, id string) error {
	if s.agentStore == nil {
		return errs.BadRequest("ai agent store is not ready")
	}
	id = strings.TrimSpace(id)
	if id == "" {
		return errs.BadRequest("agent id is required")
	}
	return s.agentStore.DeleteAgent(ctx, id)
}

func (s *Service) ListAgentSessions(
	ctx context.Context,
	agentID string,
	limit int,
	cursor string,
) ([]AgentSession, error) {
	if s.agentStore == nil {
		return []AgentSession{}, nil
	}
	agentID = strings.TrimSpace(agentID)
	if agentID == "" {
		return nil, errs.BadRequest("agent id is required")
	}
	if _, err := s.agentStore.GetAgentByID(ctx, agentID); err != nil {
		return nil, err
	}
	return s.agentStore.ListSessions(ctx, agentID, limit, cursor)
}

func (s *Service) CreateAgentSession(
	ctx context.Context,
	agentID string,
	req CreateSessionRequest,
) (AgentSession, error) {
	if s.agentStore == nil {
		return AgentSession{}, errs.BadRequest("ai agent store is not ready")
	}
	agentID = strings.TrimSpace(agentID)
	if agentID == "" {
		return AgentSession{}, errs.BadRequest("agent id is required")
	}
	if _, err := s.agentStore.GetAgentByID(ctx, agentID); err != nil {
		return AgentSession{}, err
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = "New Session"
	}
	now := nowRFC3339()
	session := AgentSession{
		ID:        uuid.NewString(),
		AgentID:   agentID,
		Title:     title,
		CreatedAt: now,
		UpdatedAt: now,
	}
	return s.agentStore.CreateSession(ctx, session)
}

func (s *Service) DeleteAgentSession(ctx context.Context, sessionID string) error {
	if s.agentStore == nil {
		return errs.BadRequest("ai agent store is not ready")
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return errs.BadRequest("session id is required")
	}
	return s.agentStore.DeleteSession(ctx, sessionID)
}

func (s *Service) ListSessionMessages(
	ctx context.Context,
	sessionID string,
	limit int,
	beforeID string,
) ([]AgentMessage, error) {
	if s.agentStore == nil {
		return []AgentMessage{}, nil
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return nil, errs.BadRequest("session id is required")
	}
	if _, err := s.agentStore.GetSessionByID(ctx, sessionID); err != nil {
		return nil, err
	}
	items, err := s.agentStore.ListMessages(ctx, sessionID, limit, beforeID)
	if err != nil {
		return nil, err
	}
	reverseAgentMessages(items)
	return items, nil
}

func (s *Service) ListSessionArtifacts(
	ctx context.Context,
	sessionID string,
	status string,
) ([]AgentArtifact, error) {
	if s.agentStore == nil {
		return []AgentArtifact{}, nil
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return nil, errs.BadRequest("session id is required")
	}
	if _, err := s.agentStore.GetSessionByID(ctx, sessionID); err != nil {
		return nil, err
	}
	return s.agentStore.ListArtifacts(ctx, sessionID, status)
}

func (s *Service) CompressSessionMessages(
	ctx context.Context,
	sessionID string,
	req CompressSessionRequest,
) (CompressSessionResult, error) {
	if s.agentStore == nil {
		return CompressSessionResult{}, errs.BadRequest("ai agent store is not ready")
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return CompressSessionResult{}, errs.BadRequest("session id is required")
	}
	trigger := normalizeCompressTrigger(req.Trigger)
	session, err := s.agentStore.GetSessionByID(ctx, sessionID)
	if err != nil {
		return CompressSessionResult{}, err
	}
	totalMessages, err := s.agentStore.CountMessages(ctx, sessionID)
	if err != nil {
		return CompressSessionResult{}, err
	}

	result := CompressSessionResult{
		Status:           "skipped",
		SessionID:        sessionID,
		Trigger:          trigger,
		KeptRecentCount:  agentContextKeepRecent,
		SummaryUpdatedAt: session.ContextSummaryUpdatedAt,
		SummaryPreview:   truncateText(strings.TrimSpace(session.ContextSummaryText), 180),
	}
	if totalMessages <= agentContextKeepRecent {
		return result, nil
	}

	targetSummaryCount := totalMessages - agentContextKeepRecent
	currentSummaryCount := clampInt(session.ContextSummaryMessageCount, 0, targetSummaryCount)
	if req.Force {
		currentSummaryCount = 0
	}
	pendingCount := targetSummaryCount - currentSummaryCount
	if pendingCount <= 0 {
		return result, nil
	}
	if trigger == "auto" && !req.Force {
		ok, reason := shouldRunAutoCompression(session, totalMessages, currentSummaryCount, targetSummaryCount)
		if !ok {
			logx.LoggerFromContext(ctx).Info("ai session auto compress skipped",
				slog.String("event", "ai.agent.compress"),
				slog.String("agent_id", session.AgentID),
				slog.String("session_id", sessionID),
				slog.String("trigger", trigger),
				slog.String("reason", reason),
				slog.Int("total_messages", totalMessages),
			)
			return result, nil
		}
	}

	pendingMessages, err := s.agentStore.ListMessagesByOffset(ctx, sessionID, currentSummaryCount, pendingCount)
	if err != nil {
		return CompressSessionResult{}, err
	}
	if len(pendingMessages) == 0 {
		return result, nil
	}

	agent, err := s.agentStore.GetAgentByID(ctx, session.AgentID)
	if err != nil {
		return CompressSessionResult{}, err
	}
	existingSummary := ""
	if !req.Force {
		existingSummary = strings.TrimSpace(session.ContextSummaryText)
	}
	summaryText, fallbackUsed, reason, callMeta := s.buildSessionSummary(ctx, agent, existingSummary, pendingMessages)

	summaryUpdatedAt := nowRFC3339()
	meta := cloneAnyMap(session.ContextSummaryMeta)
	meta["last_trigger"] = trigger
	meta["last_reason"] = reason
	meta["last_fallback_used"] = fallbackUsed
	meta["last_updated_at"] = summaryUpdatedAt
	meta["last_summarized_count"] = len(pendingMessages)
	meta["summary_message_count"] = targetSummaryCount
	if trigger == "auto" {
		meta["last_auto_compress_at"] = summaryUpdatedAt
	}
	if err := s.agentStore.UpdateSessionSummary(
		ctx,
		sessionID,
		summaryText,
		meta,
		summaryUpdatedAt,
		targetSummaryCount,
	); err != nil {
		return CompressSessionResult{}, err
	}

	logx.LoggerFromContext(ctx).Info("ai session compressed",
		slog.String("event", "ai.agent.compress"),
		slog.String("agent_id", session.AgentID),
		slog.String("session_id", sessionID),
		slog.String("trigger", trigger),
		slog.Int("summarized_count", len(pendingMessages)),
		slog.Int("kept_recent_count", agentContextKeepRecent),
		slog.Bool("fallback_used", fallbackUsed),
		slog.String("reason", reason),
		slog.String("provider_used", callMeta.ProviderUsed),
		slog.String("model_used", callMeta.ModelUsed),
	)

	return CompressSessionResult{
		Status:           "compressed",
		SessionID:        sessionID,
		Trigger:          trigger,
		SummarizedCount:  len(pendingMessages),
		KeptRecentCount:  agentContextKeepRecent,
		SummaryUpdatedAt: summaryUpdatedAt,
		SummaryPreview:   truncateText(summaryText, 180),
	}, nil
}

func (s *Service) SendSessionMessage(
	ctx context.Context,
	sessionID string,
	req SendSessionMessageRequest,
) (SessionMessageResponse, error) {
	if s.agentStore == nil {
		return SessionMessageResponse{}, errs.BadRequest("ai agent store is not ready")
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return SessionMessageResponse{}, errs.BadRequest("session id is required")
	}
	content := strings.TrimSpace(req.Content)
	if content == "" {
		return SessionMessageResponse{}, errs.BadRequest("content is required")
	}
	session, err := s.agentStore.GetSessionByID(ctx, sessionID)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	agent, err := s.agentStore.GetAgentByID(ctx, session.AgentID)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	if !agent.Enabled {
		return SessionMessageResponse{}, errs.BadRequest("agent is disabled")
	}

	userMessage := AgentMessage{
		ID:        uuid.NewString(),
		SessionID: sessionID,
		Role:      "user",
		Content:   content,
		CreatedAt: nowRFC3339(),
	}
	if _, err := s.agentStore.CreateMessage(ctx, userMessage); err != nil {
		return SessionMessageResponse{}, err
	}

	history, err := s.agentStore.ListMessages(ctx, sessionID, agentContextKeepRecent, "")
	if err != nil {
		return SessionMessageResponse{}, err
	}
	reverseAgentMessages(history)
	messages := buildSessionChatMessages(session, history)

	intentResp, intentMeta, err := s.chatWithFallback(ctx, agent, ChatRequest{
		SystemPrompt: agent.SystemPrompt,
		Messages:     messages,
		Mode:         "detect_intent",
	})
	if err != nil {
		return SessionMessageResponse{}, err
	}
	logx.LoggerFromContext(ctx).Info("ai agent intent analyzed",
		slog.String("event", "ai.agent.intent"),
		slog.String("agent_id", agent.ID),
		slog.String("session_id", sessionID),
		slog.String("action", intentResp.Intent.Action),
		slog.Float64("confidence", intentResp.Intent.Confidence),
	)

	intent := normalizeIntent(intentResp.Intent)
	if shouldAutoExecute(intent) {
		executed, err := s.executeAgentAction(ctx, session, agent, intent.Action, intent.Params)
		if err != nil {
			return SessionMessageResponse{}, err
		}
		assistant, artifact, err := s.persistAssistantWithArtifact(ctx, sessionID, intent, nil, executed)
		if err != nil {
			return SessionMessageResponse{}, err
		}
		s.runAutoCompressionBestEffort(ctx, sessionID)
		return SessionMessageResponse{
			AssistantMessage: assistant,
			Intent:           intent,
			Artifact:         artifact,
		}, nil
	}

	if shouldAskConfirmation(intent) {
		pending := &PendingConfirmation{
			Action:  intent.Action,
			Prompt:  confirmationPromptForAction(intent.Action),
			Params:  intent.Params,
			Created: nowRFC3339(),
		}
		assistant := AgentMessage{
			ID:                  uuid.NewString(),
			SessionID:           sessionID,
			Role:                "assistant",
			Content:             pending.Prompt,
			Intent:              &intent,
			PendingConfirmation: pending,
			ProviderUsed:        intentMeta.ProviderUsed,
			ModelUsed:           intentMeta.ModelUsed,
			FallbackUsed:        intentMeta.FallbackUsed,
			LatencyMS:           intentMeta.LatencyMS,
			CreatedAt:           nowRFC3339(),
		}
		created, err := s.agentStore.CreateMessage(ctx, assistant)
		if err != nil {
			return SessionMessageResponse{}, err
		}
		s.runAutoCompressionBestEffort(ctx, sessionID)
		return SessionMessageResponse{
			AssistantMessage:    created,
			Intent:              intent,
			PendingConfirmation: pending,
		}, nil
	}

	chatResp, chatMeta, err := s.chatWithFallback(ctx, agent, ChatRequest{
		SystemPrompt: agent.SystemPrompt,
		Messages:     messages,
		Mode:         "chat",
	})
	if err != nil {
		return SessionMessageResponse{}, err
	}
	assistant := AgentMessage{
		ID:           uuid.NewString(),
		SessionID:    sessionID,
		Role:         "assistant",
		Content:      strings.TrimSpace(chatResp.Content),
		Intent:       &intent,
		ProviderUsed: chatMeta.ProviderUsed,
		ModelUsed:    chatMeta.ModelUsed,
		FallbackUsed: chatMeta.FallbackUsed,
		LatencyMS:    chatMeta.LatencyMS,
		CreatedAt:    nowRFC3339(),
	}
	created, err := s.agentStore.CreateMessage(ctx, assistant)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	s.runAutoCompressionBestEffort(ctx, sessionID)
	return SessionMessageResponse{
		AssistantMessage: created,
		Intent:           intent,
	}, nil
}

func (s *Service) ConfirmSessionAction(
	ctx context.Context,
	sessionID string,
	req ConfirmActionRequest,
) (SessionMessageResponse, error) {
	if s.agentStore == nil {
		return SessionMessageResponse{}, errs.BadRequest("ai agent store is not ready")
	}
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return SessionMessageResponse{}, errs.BadRequest("session id is required")
	}
	session, err := s.agentStore.GetSessionByID(ctx, sessionID)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	agent, err := s.agentStore.GetAgentByID(ctx, session.AgentID)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	messageID := strings.TrimSpace(req.MessageID)
	if messageID == "" {
		return SessionMessageResponse{}, errs.BadRequest("message_id is required")
	}
	msg, err := s.agentStore.GetMessageByID(ctx, messageID)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	if msg.SessionID != sessionID {
		return SessionMessageResponse{}, errs.BadRequest("message does not belong to session")
	}

	action := strings.TrimSpace(req.Action)
	params := req.Params
	if msg.PendingConfirmation != nil {
		if action == "" {
			action = msg.PendingConfirmation.Action
		}
		if len(params) == 0 {
			params = msg.PendingConfirmation.Params
		}
	}
	if action == "" {
		return SessionMessageResponse{}, errs.BadRequest("action is required")
	}
	action = strings.ToLower(action)

	executed, err := s.executeAgentAction(ctx, session, agent, action, params)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	intent := IntentResult{
		Action:     action,
		Confidence: 1,
		Reason:     "confirmed_by_user",
		Params:     params,
	}
	assistant, artifact, err := s.persistAssistantWithArtifact(ctx, sessionID, intent, nil, executed)
	if err != nil {
		return SessionMessageResponse{}, err
	}
	s.runAutoCompressionBestEffort(ctx, sessionID)
	return SessionMessageResponse{
		AssistantMessage: assistant,
		Intent:           intent,
		Artifact:         artifact,
	}, nil
}

func (s *Service) ImportQuestionsFromArtifact(
	ctx context.Context,
	artifactID string,
	req ImportQuestionsRequest,
) (ImportQuestionsResult, error) {
	if s.agentStore == nil {
		return ImportQuestionsResult{}, errs.BadRequest("ai agent store is not ready")
	}
	artifact, err := s.agentStore.GetArtifactByID(ctx, strings.TrimSpace(artifactID))
	if err != nil {
		return ImportQuestionsResult{}, err
	}
	if artifact.Type != "question_set" {
		return ImportQuestionsResult{}, errs.BadRequest("artifact type is not question_set")
	}
	rawItems, ok := artifact.Payload["items"]
	if !ok {
		return ImportQuestionsResult{}, errs.BadRequest("artifact has no question items")
	}
	items := []question.CreateInput{}
	data, _ := json.Marshal(rawItems)
	_ = json.Unmarshal(data, &items)
	if len(items) == 0 {
		return ImportQuestionsResult{}, errs.BadRequest("artifact has no question items")
	}

	selected := req.SelectedIndexes
	if len(selected) == 0 {
		selected = make([]int, 0, len(items))
		for i := range items {
			selected = append(selected, i)
		}
	}

	subjectOverride := strings.TrimSpace(req.SubjectOverride)
	difficultyOverride := req.DifficultyOverride
	if difficultyOverride < 0 {
		difficultyOverride = 0
	}
	questionIDs := make([]string, 0, len(selected))
	for _, idx := range selected {
		if idx < 0 || idx >= len(items) {
			continue
		}
		item := items[idx]
		item.Source = question.SourceAIGenerated
		if subjectOverride != "" {
			item.Subject = subjectOverride
		}
		if difficultyOverride > 0 {
			item.Difficulty = difficultyOverride
		}
		if item.Difficulty < 1 {
			item.Difficulty = 1
		}
		if item.Difficulty > 5 {
			item.Difficulty = 5
		}
		created, createErr := s.questionService.Create(ctx, item)
		if createErr != nil {
			_ = s.agentStore.UpdateArtifactImportStatus(ctx, artifact.ID, "failed", "")
			return ImportQuestionsResult{}, createErr
		}
		questionIDs = append(questionIDs, created.ID)
	}
	if len(questionIDs) == 0 {
		return ImportQuestionsResult{}, errs.BadRequest("no valid selected_indexes")
	}
	if err := s.agentStore.UpdateArtifactImportStatus(ctx, artifact.ID, "imported", nowRFC3339()); err != nil {
		return ImportQuestionsResult{}, err
	}
	logx.LoggerFromContext(ctx).Info("ai artifact question import success",
		slog.String("event", "ai.agent.import"),
		slog.String("artifact_id", artifact.ID),
		slog.Int("imported_count", len(questionIDs)),
	)
	return ImportQuestionsResult{
		ImportedCount: len(questionIDs),
		QuestionIDs:   questionIDs,
	}, nil
}

func (s *Service) ImportPlanFromArtifact(
	ctx context.Context,
	artifactID string,
	req ImportPlanRequest,
) (ImportPlanResult, error) {
	if s.agentStore == nil {
		return ImportPlanResult{}, errs.BadRequest("ai agent store is not ready")
	}
	if s.planService == nil {
		return ImportPlanResult{}, errs.Internal("plan service is not configured")
	}
	if !req.Append {
		return ImportPlanResult{}, errs.BadRequest("append must be true")
	}
	artifact, err := s.agentStore.GetArtifactByID(ctx, strings.TrimSpace(artifactID))
	if err != nil {
		return ImportPlanResult{}, err
	}
	if artifact.Type != "learning_plan" {
		return ImportPlanResult{}, errs.BadRequest("artifact type is not learning_plan")
	}
	planPayload := artifact.Payload
	if nested, ok := artifact.Payload["plan"].(map[string]any); ok {
		planPayload = nested
	}
	data, _ := json.Marshal(planPayload)
	var lr LearnResult
	_ = json.Unmarshal(data, &lr)
	if len(lr.PlanItems) == 0 {
		return ImportPlanResult{}, errs.BadRequest("artifact has no plan_items")
	}

	planIDs := make([]string, 0, len(lr.PlanItems))
	for _, item := range lr.PlanItems {
		created, createErr := s.planService.Create(ctx, plan.CreateInput{
			PlanType:   plan.PlanType(strings.TrimSpace(item.PlanType)),
			Title:      strings.TrimSpace(item.Title),
			Content:    strings.TrimSpace(item.Content),
			TargetDate: strings.TrimSpace(item.TargetDate),
			Status:     strings.TrimSpace(item.Status),
			Priority:   item.Priority,
			Source:     plan.SourceAIAgent,
		})
		if createErr != nil {
			_ = s.agentStore.UpdateArtifactImportStatus(ctx, artifact.ID, "failed", "")
			return ImportPlanResult{}, createErr
		}
		planIDs = append(planIDs, created.ID)
	}
	if len(planIDs) == 0 {
		return ImportPlanResult{}, errs.BadRequest("artifact has no valid plan_items")
	}
	if err := s.agentStore.UpdateArtifactImportStatus(ctx, artifact.ID, "imported", nowRFC3339()); err != nil {
		return ImportPlanResult{}, err
	}
	logx.LoggerFromContext(ctx).Info("ai artifact plan import success",
		slog.String("event", "ai.agent.import"),
		slog.String("artifact_id", artifact.ID),
		slog.Int("imported_count", len(planIDs)),
	)
	return ImportPlanResult{
		ImportedCount: len(planIDs),
		PlanIDs:       planIDs,
	}, nil
}

func (s *Service) persistAssistantWithArtifact(
	ctx context.Context,
	sessionID string,
	intent IntentResult,
	pending *PendingConfirmation,
	executed actionExecutionResult,
) (AgentMessage, *AgentArtifact, error) {
	assistant := AgentMessage{
		ID:                  uuid.NewString(),
		SessionID:           sessionID,
		Role:                "assistant",
		Content:             executed.Content,
		Intent:              &intent,
		PendingConfirmation: pending,
		ProviderUsed:        executed.Meta.ProviderUsed,
		ModelUsed:           executed.Meta.ModelUsed,
		FallbackUsed:        executed.Meta.FallbackUsed,
		LatencyMS:           executed.Meta.LatencyMS,
		CreatedAt:           nowRFC3339(),
	}
	created, err := s.agentStore.CreateMessage(ctx, assistant)
	if err != nil {
		return AgentMessage{}, nil, err
	}
	var artifact *AgentArtifact
	if executed.ArtifactType != "" {
		item := AgentArtifact{
			ID:           uuid.NewString(),
			SessionID:    sessionID,
			MessageID:    created.ID,
			Type:         executed.ArtifactType,
			Payload:      executed.ArtifactPayload,
			ImportStatus: "pending",
			CreatedAt:    nowRFC3339(),
		}
		stored, createErr := s.agentStore.CreateArtifact(ctx, item)
		if createErr != nil {
			return AgentMessage{}, nil, createErr
		}
		created.ArtifactID = stored.ID
		artifact = &stored
	}
	return created, artifact, nil
}

func (s *Service) executeAgentAction(
	ctx context.Context,
	session AgentSession,
	agent Agent,
	action string,
	params map[string]any,
) (actionExecutionResult, error) {
	switch strings.ToLower(strings.TrimSpace(action)) {
	case "generate_questions":
		req := buildGenerateRequest(params)
		items, meta, err := s.generateQuestionsWithFallback(ctx, agent, req)
		if err != nil {
			return actionExecutionResult{}, err
		}
		logx.LoggerFromContext(ctx).Info("ai agent tool execution success",
			slog.String("event", "ai.agent.tool_call"),
			slog.String("session_id", session.ID),
			slog.String("agent_id", agent.ID),
			slog.String("action", "generate_questions"),
			slog.Int("count", len(items)),
		)
		payload := map[string]any{
			"request": req,
			"items":   items,
		}
		return actionExecutionResult{
			Content:         fmt.Sprintf("Generated %d questions for topic \"%s\".", len(items), req.Topic),
			ArtifactType:    "question_set",
			ArtifactPayload: payload,
			Meta:            meta,
		}, nil
	case "build_plan":
		req := buildLearnRequest(params)
		planResult, meta, err := s.buildPlanWithFallback(ctx, agent, req)
		if err != nil {
			return actionExecutionResult{}, err
		}
		logx.LoggerFromContext(ctx).Info("ai agent tool execution success",
			slog.String("event", "ai.agent.tool_call"),
			slog.String("session_id", session.ID),
			slog.String("agent_id", agent.ID),
			slog.String("action", "build_plan"),
		)
		payload := map[string]any{
			"request": req,
			"plan":    planResult,
		}
		return actionExecutionResult{
			Content:         fmt.Sprintf("Built a learning plan (%s -> %s).", planResult.PlanStartDate, planResult.PlanEndDate),
			ArtifactType:    "learning_plan",
			ArtifactPayload: payload,
			Meta:            meta,
		}, nil
	default:
		return actionExecutionResult{}, errs.BadRequest("unsupported action")
	}
}

func (s *Service) chatWithFallback(
	ctx context.Context,
	agent Agent,
	req ChatRequest,
) (ChatResponse, agentCallMeta, error) {
	var meta agentCallMeta
	primaryClient, err := s.buildAgentClient(agent.Protocol, agent.Primary)
	if err == nil && primaryClient.IsReady() {
		start := time.Now()
		resp, callErr := primaryClient.Chat(ctx, req)
		meta = agentCallMeta{
			ProviderUsed: primaryClient.ProviderName(),
			ModelUsed:    primaryClient.ModelName(),
			FallbackUsed: false,
			LatencyMS:    time.Since(start).Milliseconds(),
		}
		if callErr == nil {
			return resp, meta, nil
		}
		logx.LoggerFromContext(ctx).Warn("ai agent primary failed",
			slog.String("event", "ai.agent.fallback"),
			slog.String("agent_id", agent.ID),
			slog.String("reason", classifyFallbackReason(callErr)),
			slog.String("error", callErr.Error()),
		)
	} else if err != nil {
		logx.LoggerFromContext(ctx).Warn("ai agent primary not ready",
			slog.String("event", "ai.agent.fallback"),
			slog.String("agent_id", agent.ID),
			slog.String("reason", "invalid_primary_config"),
			slog.String("error", err.Error()),
		)
	}

	fallbackClient, fallbackErr := s.buildAgentClient(agent.Protocol, agent.Fallback)
	if fallbackErr != nil || !fallbackClient.IsReady() {
		if err != nil {
			return ChatResponse{}, meta, err
		}
		return ChatResponse{}, meta, errs.BadRequest("fallback provider is not ready")
	}
	start := time.Now()
	resp, callErr := fallbackClient.Chat(ctx, req)
	meta = agentCallMeta{
		ProviderUsed: fallbackClient.ProviderName(),
		ModelUsed:    fallbackClient.ModelName(),
		FallbackUsed: true,
		LatencyMS:    time.Since(start).Milliseconds(),
	}
	if callErr != nil {
		return ChatResponse{}, meta, callErr
	}
	return resp, meta, nil
}

func (s *Service) generateQuestionsWithFallback(
	ctx context.Context,
	agent Agent,
	req GenerateRequest,
) ([]question.CreateInput, agentCallMeta, error) {
	primaryClient, err := s.buildAgentClient(agent.Protocol, agent.Primary)
	if err == nil && primaryClient.IsReady() {
		start := time.Now()
		items, callErr := primaryClient.GenerateQuestions(ctx, req)
		meta := agentCallMeta{
			ProviderUsed: primaryClient.ProviderName(),
			ModelUsed:    primaryClient.ModelName(),
			FallbackUsed: false,
			LatencyMS:    time.Since(start).Milliseconds(),
		}
		if callErr == nil {
			return items, meta, nil
		}
		logx.LoggerFromContext(ctx).Warn("ai agent primary failed",
			slog.String("event", "ai.agent.fallback"),
			slog.String("agent_id", agent.ID),
			slog.String("reason", classifyFallbackReason(callErr)),
			slog.String("error", callErr.Error()),
		)
	}
	fallbackClient, fallbackErr := s.buildAgentClient(agent.Protocol, agent.Fallback)
	if fallbackErr != nil || !fallbackClient.IsReady() {
		if err != nil {
			return nil, agentCallMeta{}, err
		}
		return nil, agentCallMeta{}, errs.BadRequest("fallback provider is not ready")
	}
	start := time.Now()
	items, callErr := fallbackClient.GenerateQuestions(ctx, req)
	meta := agentCallMeta{
		ProviderUsed: fallbackClient.ProviderName(),
		ModelUsed:    fallbackClient.ModelName(),
		FallbackUsed: true,
		LatencyMS:    time.Since(start).Milliseconds(),
	}
	if callErr != nil {
		return nil, meta, callErr
	}
	return items, meta, nil
}

func (s *Service) buildPlanWithFallback(
	ctx context.Context,
	agent Agent,
	req LearnRequest,
) (LearnResult, agentCallMeta, error) {
	primaryClient, err := s.buildAgentClient(agent.Protocol, agent.Primary)
	if err == nil && primaryClient.IsReady() {
		start := time.Now()
		planResult, callErr := primaryClient.BuildLearningPlan(ctx, req)
		meta := agentCallMeta{
			ProviderUsed: primaryClient.ProviderName(),
			ModelUsed:    primaryClient.ModelName(),
			FallbackUsed: false,
			LatencyMS:    time.Since(start).Milliseconds(),
		}
		if callErr == nil {
			return planResult, meta, nil
		}
		logx.LoggerFromContext(ctx).Warn("ai agent primary failed",
			slog.String("event", "ai.agent.fallback"),
			slog.String("agent_id", agent.ID),
			slog.String("reason", classifyFallbackReason(callErr)),
			slog.String("error", callErr.Error()),
		)
	}
	fallbackClient, fallbackErr := s.buildAgentClient(agent.Protocol, agent.Fallback)
	if fallbackErr != nil || !fallbackClient.IsReady() {
		if err != nil {
			return LearnResult{}, agentCallMeta{}, err
		}
		return LearnResult{}, agentCallMeta{}, errs.BadRequest("fallback provider is not ready")
	}
	start := time.Now()
	planResult, callErr := fallbackClient.BuildLearningPlan(ctx, req)
	meta := agentCallMeta{
		ProviderUsed: fallbackClient.ProviderName(),
		ModelUsed:    fallbackClient.ModelName(),
		FallbackUsed: true,
		LatencyMS:    time.Since(start).Milliseconds(),
	}
	if callErr != nil {
		return LearnResult{}, meta, callErr
	}
	return planResult, meta, nil
}

func (s *Service) buildAgentClient(protocol AgentProtocol, cfg AgentProviderConfig) (Client, error) {
	timeout := s.runtime.AIHTTPTimeout
	if timeout <= 0 {
		timeout = 60 * time.Second
	}
	switch protocol {
	case AgentProtocolMock:
		return NewMockClient(s.runtime.MockLatency), nil
	case AgentProtocolOpenAICompatible:
		client := NewOpenAIClient(OpenAIConfig{
			BaseURL: strings.TrimSpace(cfg.BaseURL),
			APIKey:  strings.TrimSpace(cfg.APIKey),
			Model:   strings.TrimSpace(cfg.Model),
			Timeout: timeout,
		})
		return client, nil
	case AgentProtocolGeminiNative:
		client := NewGeminiClient(GeminiConfig{
			APIKey:  strings.TrimSpace(cfg.APIKey),
			Model:   strings.TrimSpace(cfg.Model),
			Timeout: timeout,
		})
		return client, nil
	case AgentProtocolClaudeNative:
		client := NewClaudeClient(ClaudeConfig{
			APIKey:  strings.TrimSpace(cfg.APIKey),
			Model:   strings.TrimSpace(cfg.Model),
			Timeout: timeout,
		})
		return client, nil
	default:
		return nil, errs.BadRequest("protocol must be one of: mock/openai_compatible/gemini_native/claude_native")
	}
}

func normalizeAgentRequest(req UpsertAgentRequest, id string) (Agent, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return Agent{}, errs.BadRequest("name is required")
	}
	protocol := AgentProtocol(strings.ToLower(strings.TrimSpace(string(req.Protocol))))
	if protocol == "" {
		protocol = AgentProtocolOpenAICompatible
	}
	switch protocol {
	case AgentProtocolMock, AgentProtocolOpenAICompatible, AgentProtocolGeminiNative, AgentProtocolClaudeNative:
	default:
		return Agent{}, errs.BadRequest("protocol must be one of: mock/openai_compatible/gemini_native/claude_native")
	}
	primary := normalizeProviderConfig(req.Primary)
	if protocol != AgentProtocolMock && (primary.Model == "" || primary.APIKey == "") {
		return Agent{}, errs.BadRequest("primary model/api_key are required")
	}
	fallback := normalizeProviderConfig(req.Fallback)
	caps := normalizeStringSlice(req.IntentCapabilities)
	if len(caps) == 0 {
		caps = []string{"chat", "generate_questions", "build_plan"}
	}
	enabled := true
	if req.Enabled != nil {
		enabled = *req.Enabled
	}
	return Agent{
		ID:                 id,
		Name:               name,
		Protocol:           protocol,
		Primary:            primary,
		Fallback:           fallback,
		SystemPrompt:       strings.TrimSpace(req.SystemPrompt),
		IntentCapabilities: caps,
		Enabled:            enabled,
	}, nil
}

func mergeAgentRequest(existing Agent, req UpsertAgentRequest) UpsertAgentRequest {
	out := req
	if strings.TrimSpace(out.Name) == "" {
		out.Name = existing.Name
	}
	if strings.TrimSpace(string(out.Protocol)) == "" {
		out.Protocol = existing.Protocol
	}
	if out.Primary == (AgentProviderConfig{}) {
		out.Primary = existing.Primary
	} else {
		if strings.TrimSpace(out.Primary.BaseURL) == "" {
			out.Primary.BaseURL = existing.Primary.BaseURL
		}
		if strings.TrimSpace(out.Primary.APIKey) == "" {
			out.Primary.APIKey = existing.Primary.APIKey
		}
		if strings.TrimSpace(out.Primary.Model) == "" {
			out.Primary.Model = existing.Primary.Model
		}
	}
	if out.Fallback == (AgentProviderConfig{}) {
		out.Fallback = existing.Fallback
	} else {
		if strings.TrimSpace(out.Fallback.BaseURL) == "" {
			out.Fallback.BaseURL = existing.Fallback.BaseURL
		}
		if strings.TrimSpace(out.Fallback.APIKey) == "" {
			out.Fallback.APIKey = existing.Fallback.APIKey
		}
		if strings.TrimSpace(out.Fallback.Model) == "" {
			out.Fallback.Model = existing.Fallback.Model
		}
	}
	if strings.TrimSpace(out.SystemPrompt) == "" {
		out.SystemPrompt = existing.SystemPrompt
	}
	if len(out.IntentCapabilities) == 0 {
		out.IntentCapabilities = existing.IntentCapabilities
	}
	if out.Enabled == nil {
		v := existing.Enabled
		out.Enabled = &v
	}
	return out
}

func redactAgentSecrets(item Agent) Agent {
	item.Primary.APIKey = ""
	item.Fallback.APIKey = ""
	return item
}

func normalizeProviderConfig(in AgentProviderConfig) AgentProviderConfig {
	return AgentProviderConfig{
		BaseURL: strings.TrimSpace(in.BaseURL),
		APIKey:  strings.TrimSpace(in.APIKey),
		Model:   strings.TrimSpace(in.Model),
	}
}

func normalizeStringSlice(items []string) []string {
	out := make([]string, 0, len(items))
	for _, item := range items {
		trimmed := strings.TrimSpace(item)
		if trimmed == "" {
			continue
		}
		out = append(out, trimmed)
	}
	return out
}

func reverseAgentMessages(items []AgentMessage) {
	for i, j := 0, len(items)-1; i < j; i, j = i+1, j-1 {
		items[i], items[j] = items[j], items[i]
	}
}

func buildSessionChatMessages(session AgentSession, items []AgentMessage) []ChatMessage {
	out := make([]ChatMessage, 0, len(items)+1)
	if summary := strings.TrimSpace(session.ContextSummaryText); summary != "" {
		out = append(out, ChatMessage{
			Role:    "system",
			Content: "Session summary (compressed history):\n" + summary,
		})
	}
	out = append(out, toChatMessages(items)...)
	return out
}

func toChatMessages(items []AgentMessage) []ChatMessage {
	out := make([]ChatMessage, 0, len(items))
	for _, item := range items {
		out = append(out, ChatMessage{
			Role:    item.Role,
			Content: item.Content,
		})
	}
	return out
}

func (s *Service) runAutoCompressionBestEffort(ctx context.Context, sessionID string) {
	compressCtx, cancel := context.WithTimeout(ctx, 12*time.Second)
	defer cancel()

	_, err := s.CompressSessionMessages(compressCtx, sessionID, CompressSessionRequest{
		Trigger: "auto",
	})
	if err != nil {
		logx.LoggerFromContext(ctx).Warn("ai session auto compress failed",
			slog.String("event", "ai.agent.compress"),
			slog.String("session_id", sessionID),
			slog.String("trigger", "auto"),
			slog.String("reason", classifyFallbackReason(err)),
			slog.String("error", err.Error()),
		)
	}
}

func normalizeCompressTrigger(v string) string {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "auto":
		return "auto"
	default:
		return "manual"
	}
}

func shouldRunAutoCompression(
	session AgentSession,
	totalMessages int,
	currentSummaryCount int,
	targetSummaryCount int,
) (bool, string) {
	newSummaryMessages := targetSummaryCount - currentSummaryCount
	meetNewMessageThreshold := newSummaryMessages >= agentAutoCompressMinNewMessages

	meetStaleSummaryThreshold := false
	if totalMessages > agentContextKeepRecent {
		if ts, ok := parseRFC3339Time(firstNonEmpty(
			session.ContextSummaryUpdatedAt,
			session.SummaryUpdatedAt,
		)); ok {
			meetStaleSummaryThreshold = time.Since(ts) > agentAutoCompressStaleAfter
		}
	}
	if !meetNewMessageThreshold && !meetStaleSummaryThreshold {
		return false, "threshold_not_met"
	}

	lastAutoAt, hasLastAuto := parseRFC3339Time(metaString(session.ContextSummaryMeta, "last_auto_compress_at"))
	if hasLastAuto && time.Since(lastAutoAt) < agentAutoCompressCooldown {
		return false, "cooldown"
	}
	if meetNewMessageThreshold {
		return true, "new_messages_threshold"
	}
	return true, "stale_summary"
}

func (s *Service) buildSessionSummary(
	ctx context.Context,
	agent Agent,
	existingSummary string,
	pendingMessages []AgentMessage,
) (string, bool, string, agentCallMeta) {
	summary, meta, err := s.buildSessionSummaryWithModel(ctx, agent, existingSummary, pendingMessages)
	if err == nil {
		return summary, false, "model", meta
	}

	reason := classifyFallbackReason(err)
	logx.LoggerFromContext(ctx).Warn("ai session summary fallback",
		slog.String("event", "ai.agent.compress"),
		slog.String("agent_id", agent.ID),
		slog.String("reason", reason),
		slog.String("error", err.Error()),
	)
	return buildLocalSessionSummary(existingSummary, pendingMessages), true, reason, meta
}

func (s *Service) buildSessionSummaryWithModel(
	ctx context.Context,
	agent Agent,
	existingSummary string,
	pendingMessages []AgentMessage,
) (string, agentCallMeta, error) {
	lines := make([]string, 0, len(pendingMessages)+4)
	if text := strings.TrimSpace(existingSummary); text != "" {
		lines = append(lines, "Existing summary:")
		lines = append(lines, text)
	}
	lines = append(lines, "New messages to summarize:")
	for idx, msg := range pendingMessages {
		role := strings.TrimSpace(msg.Role)
		if role == "" {
			role = "unknown"
		}
		content := compactSpaces(msg.Content)
		if content == "" {
			continue
		}
		lines = append(lines, fmt.Sprintf("%d. [%s] %s", idx+1, role, truncateText(content, 260)))
	}
	input := strings.Join(lines, "\n")
	if strings.TrimSpace(input) == "" {
		return "", agentCallMeta{}, errs.BadRequest("summary input is empty")
	}

	resp, meta, err := s.chatWithFallback(ctx, agent, ChatRequest{
		SystemPrompt: agent.SystemPrompt,
		Messages: []ChatMessage{
			{Role: "user", Content: input},
		},
		Mode: "compress_session",
	})
	if err != nil {
		return "", meta, err
	}
	summary := strings.TrimSpace(resp.Content)
	if summary == "" {
		return "", meta, errs.Internal("empty session summary")
	}
	return summary, meta, nil
}

func buildLocalSessionSummary(existingSummary string, pendingMessages []AgentMessage) string {
	parts := make([]string, 0, 12)
	if text := strings.TrimSpace(existingSummary); text != "" {
		parts = append(parts, "Previous summary:")
		parts = append(parts, truncateText(compactSpaces(text), 480))
	}
	parts = append(parts, fmt.Sprintf("Compressed %d new messages.", len(pendingMessages)))

	if len(pendingMessages) == 0 {
		return strings.Join(parts, "\n")
	}
	preview := pendingMessages
	if len(preview) > 8 {
		preview = append(preview[:4], preview[len(preview)-4:]...)
		parts = append(parts, fmt.Sprintf("... omitted %d middle messages ...", len(pendingMessages)-8))
	}
	for _, msg := range preview {
		role := strings.TrimSpace(msg.Role)
		if role == "" {
			role = "unknown"
		}
		content := compactSpaces(msg.Content)
		if content == "" {
			continue
		}
		parts = append(parts, fmt.Sprintf("[%s] %s", role, truncateText(content, 180)))
	}
	return truncateText(strings.Join(parts, "\n"), 2000)
}

func cloneAnyMap(in map[string]any) map[string]any {
	out := make(map[string]any, len(in))
	for k, v := range in {
		out[k] = v
	}
	return out
}

func metaString(meta map[string]any, key string) string {
	if len(meta) == 0 {
		return ""
	}
	raw, ok := meta[key]
	if !ok {
		return ""
	}
	return strings.TrimSpace(fmt.Sprintf("%v", raw))
}

func parseRFC3339Time(raw string) (time.Time, bool) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return time.Time{}, false
	}
	if t, err := time.Parse(time.RFC3339Nano, trimmed); err == nil {
		return t, true
	}
	if t, err := time.Parse(time.RFC3339, trimmed); err == nil {
		return t, true
	}
	return time.Time{}, false
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func compactSpaces(text string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
}

func truncateText(text string, max int) string {
	trimmed := strings.TrimSpace(text)
	if max <= 0 || len(trimmed) <= max {
		return trimmed
	}
	if max <= 3 {
		return trimmed[:max]
	}
	return trimmed[:max-3] + "..."
}

func normalizeIntent(intent IntentResult) IntentResult {
	intent.Action = strings.ToLower(strings.TrimSpace(intent.Action))
	if intent.Confidence < 0 {
		intent.Confidence = 0
	}
	if intent.Confidence > 1 {
		intent.Confidence = 1
	}
	if intent.Params == nil {
		intent.Params = map[string]any{}
	}
	return intent
}

func shouldAutoExecute(intent IntentResult) bool {
	if intent.Confidence < agentIntentAutoThreshold {
		return false
	}
	return isSupportedIntentAction(intent.Action)
}

func shouldAskConfirmation(intent IntentResult) bool {
	if intent.Confidence < agentIntentConfirmThreshold || intent.Confidence >= agentIntentAutoThreshold {
		return false
	}
	return isSupportedIntentAction(intent.Action)
}

func isSupportedIntentAction(action string) bool {
	switch strings.ToLower(strings.TrimSpace(action)) {
	case "generate_questions", "build_plan":
		return true
	default:
		return false
	}
}

func confirmationPromptForAction(action string) string {
	switch strings.ToLower(strings.TrimSpace(action)) {
	case "generate_questions":
		return "I detected a question-generation request. Confirm to generate questions now?"
	case "build_plan":
		return "I detected a learning-plan request. Confirm to build the plan now?"
	default:
		return "Please confirm the action."
	}
}

func classifyFallbackReason(err error) string {
	msg := strings.ToLower(strings.TrimSpace(err.Error()))
	switch {
	case strings.Contains(msg, "timeout"):
		return "timeout"
	case strings.Contains(msg, "status"):
		return "http_error"
	case strings.Contains(msg, "format"):
		return "invalid_response"
	default:
		return "runtime_error"
	}
}

func buildGenerateRequest(params map[string]any) GenerateRequest {
	topic := firstNonEmptyAsString(params, "topic", "topic_practice")
	subject := firstNonEmptyAsString(params, "subject", "general")
	scope := firstNonEmptyAsString(params, "scope", "agent_chat")
	count := clampInt(asInt(params["count"], 5), 1, 20)
	difficulty := clampInt(asInt(params["difficulty"], 3), 1, 5)
	return GenerateRequest{
		Topic:      topic,
		Subject:    subject,
		Scope:      scope,
		Count:      count,
		Difficulty: difficulty,
	}
}

func buildLearnRequest(params map[string]any) LearnRequest {
	now := time.Now().UTC()
	startDate := firstNonEmptyAsString(params, "start_date", now.Format("2006-01-02"))
	endDate := firstNonEmptyAsString(params, "end_date", now.AddDate(0, 3, 0).Format("2006-01-02"))
	themes := asStringList(params["themes"])
	goals := asStringList(params["goals"])
	return LearnRequest{
		Mode:          firstNonEmptyAsString(params, "mode", "long_term_learning"),
		Subject:       firstNonEmptyAsString(params, "subject", "general"),
		Unit:          firstNonEmptyAsString(params, "unit", ""),
		Goals:         goals,
		FinalGoal:     firstNonEmptyAsString(params, "final_goal", ""),
		TotalHours:    asInt(params["total_hours"], 0),
		StartDate:     startDate,
		EndDate:       endDate,
		CurrentStatus: firstNonEmptyAsString(params, "current_status", "pending"),
		Themes:        themes,
		Supplement:    firstNonEmptyAsString(params, "supplement", ""),
		UserID:        firstNonEmptyAsString(params, "user_id", "default"),
	}
}

func firstNonEmptyAsString(params map[string]any, key, fallback string) string {
	v, ok := params[key]
	if !ok {
		return fallback
	}
	text := strings.TrimSpace(fmt.Sprintf("%v", v))
	if text == "" || text == "<nil>" {
		return fallback
	}
	return text
}

func asStringList(raw any) []string {
	if raw == nil {
		return []string{}
	}
	if arr, ok := raw.([]string); ok {
		return normalizeStringSlice(arr)
	}
	if arr, ok := raw.([]any); ok {
		items := make([]string, 0, len(arr))
		for _, v := range arr {
			items = append(items, strings.TrimSpace(fmt.Sprintf("%v", v)))
		}
		return normalizeStringSlice(items)
	}
	text := strings.TrimSpace(fmt.Sprintf("%v", raw))
	if text == "" || text == "<nil>" {
		return []string{}
	}
	return []string{text}
}

func asInt(raw any, fallback int) int {
	switch v := raw.(type) {
	case int:
		return v
	case int32:
		return int(v)
	case int64:
		return int(v)
	case float64:
		return int(math.Round(v))
	case float32:
		return int(math.Round(float64(v)))
	case string:
		n, err := strconv.Atoi(strings.TrimSpace(v))
		if err == nil {
			return n
		}
	}
	return fallback
}

func clampInt(v, min, max int) int {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}
