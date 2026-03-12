package ai

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"prts/internal/shared/errs"
)

type AgentProtocol string

const (
	AgentProtocolMock             AgentProtocol = "mock"
	AgentProtocolOpenAICompatible AgentProtocol = "openai_compatible"
	AgentProtocolGeminiNative     AgentProtocol = "gemini_native"
	AgentProtocolClaudeNative     AgentProtocol = "claude_native"
)

type AgentProviderConfig struct {
	BaseURL string `json:"base_url,omitempty"`
	APIKey  string `json:"api_key,omitempty"`
	Model   string `json:"model,omitempty"`
}

type Agent struct {
	ID                 string              `json:"id"`
	Name               string              `json:"name"`
	Protocol           AgentProtocol       `json:"protocol"`
	Primary            AgentProviderConfig `json:"primary"`
	Fallback           AgentProviderConfig `json:"fallback"`
	SystemPrompt       string              `json:"system_prompt"`
	IntentCapabilities []string            `json:"intent_capabilities"`
	Enabled            bool                `json:"enabled"`
	CreatedAt          string              `json:"created_at"`
	UpdatedAt          string              `json:"updated_at"`
}

type AgentSession struct {
	ID                         string         `json:"id"`
	AgentID                    string         `json:"agent_id"`
	Title                      string         `json:"title"`
	LastMessageAt              string         `json:"last_message_at,omitempty"`
	SummaryUpdatedAt           string         `json:"summary_updated_at,omitempty"`
	SummaryMessageCount        int            `json:"summary_message_count"`
	ContextSummaryText         string         `json:"context_summary_text,omitempty"`
	ContextSummaryMeta         map[string]any `json:"context_summary_meta,omitempty"`
	ContextSummaryUpdatedAt    string         `json:"context_summary_updated_at,omitempty"`
	ContextSummaryMessageCount int            `json:"context_summary_message_count"`
	CreatedAt                  string         `json:"created_at"`
	UpdatedAt                  string         `json:"updated_at"`
	ArchivedAt                 string         `json:"archived_at,omitempty"`
}

type AgentMessage struct {
	ID                  string               `json:"id"`
	SessionID           string               `json:"session_id"`
	Role                string               `json:"role"`
	Content             string               `json:"content"`
	Intent              *IntentResult        `json:"intent,omitempty"`
	PendingConfirmation *PendingConfirmation `json:"pending_confirmation,omitempty"`
	ProviderUsed        string               `json:"provider_used,omitempty"`
	ModelUsed           string               `json:"model_used,omitempty"`
	FallbackUsed        bool                 `json:"fallback_used"`
	LatencyMS           int64                `json:"latency_ms"`
	ArtifactID          string               `json:"artifact_id,omitempty"`
	CreatedAt           string               `json:"created_at"`
}

type AgentChatStore interface {
	ListAgents(ctx context.Context) ([]Agent, error)
	GetAgentByID(ctx context.Context, id string) (Agent, error)
	CreateAgent(ctx context.Context, item Agent) (Agent, error)
	UpdateAgent(ctx context.Context, item Agent) (Agent, error)
	DeleteAgent(ctx context.Context, id string) error

	ListSessions(ctx context.Context, agentID string, limit int, cursor string) ([]AgentSession, error)
	CreateSession(ctx context.Context, item AgentSession) (AgentSession, error)
	GetSessionByID(ctx context.Context, sessionID string) (AgentSession, error)
	DeleteSession(ctx context.Context, sessionID string) error

	ListMessages(ctx context.Context, sessionID string, limit int, beforeID string) ([]AgentMessage, error)
	ListMessagesByOffset(ctx context.Context, sessionID string, offset int, limit int) ([]AgentMessage, error)
	CountMessages(ctx context.Context, sessionID string) (int, error)
	GetMessageByID(ctx context.Context, messageID string) (AgentMessage, error)
	CreateMessage(ctx context.Context, item AgentMessage) (AgentMessage, error)
	UpdateSessionSummary(
		ctx context.Context,
		sessionID string,
		summaryText string,
		summaryMeta map[string]any,
		summaryUpdatedAt string,
		summaryMessageCount int,
	) error

	ListArtifacts(ctx context.Context, sessionID, status string) ([]AgentArtifact, error)
	GetArtifactByID(ctx context.Context, artifactID string) (AgentArtifact, error)
	CreateArtifact(ctx context.Context, item AgentArtifact) (AgentArtifact, error)
	UpdateArtifactImportStatus(ctx context.Context, artifactID, status, importedAt string) error
}

type SQLiteAgentRepository struct {
	db *sql.DB
}

func NewSQLiteAgentRepository(db *sql.DB) *SQLiteAgentRepository {
	return &SQLiteAgentRepository{db: db}
}

func (r *SQLiteAgentRepository) ListAgents(ctx context.Context) ([]Agent, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, name, protocol, primary_config_json, fallback_config_json, system_prompt, intent_capabilities_json, enabled, created_at, updated_at
		FROM ai_agents
		ORDER BY updated_at DESC
	`)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list ai agents: %v", err))
	}
	defer rows.Close()

	items := make([]Agent, 0)
	for rows.Next() {
		item, scanErr := scanAgent(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan ai agent: %v", scanErr))
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate ai agents: %v", err))
	}
	return items, nil
}

func (r *SQLiteAgentRepository) GetAgentByID(ctx context.Context, id string) (Agent, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT id, name, protocol, primary_config_json, fallback_config_json, system_prompt, intent_capabilities_json, enabled, created_at, updated_at
		FROM ai_agents
		WHERE id = ?
	`, id)
	item, err := scanAgent(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return Agent{}, errs.NotFound("ai agent not found")
		}
		return Agent{}, errs.Internal(fmt.Sprintf("failed to get ai agent: %v", err))
	}
	return item, nil
}

func (r *SQLiteAgentRepository) CreateAgent(ctx context.Context, item Agent) (Agent, error) {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO ai_agents (
			id, name, protocol, primary_config_json, fallback_config_json, system_prompt, intent_capabilities_json, enabled, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.Name,
		string(item.Protocol),
		mustJSON(item.Primary, "{}"),
		mustJSON(item.Fallback, "{}"),
		item.SystemPrompt,
		mustJSON(item.IntentCapabilities, "[]"),
		boolToInt(item.Enabled),
		item.CreatedAt,
		item.UpdatedAt,
	)
	if err != nil {
		return Agent{}, errs.Internal(fmt.Sprintf("failed to create ai agent: %v", err))
	}
	return item, nil
}

func (r *SQLiteAgentRepository) UpdateAgent(ctx context.Context, item Agent) (Agent, error) {
	res, err := r.db.ExecContext(ctx, `
		UPDATE ai_agents
		SET name = ?, protocol = ?, primary_config_json = ?, fallback_config_json = ?, system_prompt = ?, intent_capabilities_json = ?, enabled = ?, updated_at = ?
		WHERE id = ?
	`,
		item.Name,
		string(item.Protocol),
		mustJSON(item.Primary, "{}"),
		mustJSON(item.Fallback, "{}"),
		item.SystemPrompt,
		mustJSON(item.IntentCapabilities, "[]"),
		boolToInt(item.Enabled),
		item.UpdatedAt,
		item.ID,
	)
	if err != nil {
		return Agent{}, errs.Internal(fmt.Sprintf("failed to update ai agent: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return Agent{}, errs.NotFound("ai agent not found")
	}
	return item, nil
}

func (r *SQLiteAgentRepository) DeleteAgent(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM ai_agents WHERE id = ?`, id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete ai agent: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("ai agent not found")
	}
	return nil
}

func (r *SQLiteAgentRepository) ListSessions(
	ctx context.Context,
	agentID string,
	limit int,
	cursor string,
) ([]AgentSession, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	baseSQL := `
		SELECT
			s.id,
			s.agent_id,
			s.title,
			COALESCE(MAX(m.created_at), '') AS last_message_at,
			COALESCE(s.context_summary_updated_at, '') AS summary_updated_at,
			COALESCE(s.context_summary_message_count, 0) AS summary_message_count,
			s.created_at,
			s.updated_at,
			COALESCE(s.archived_at, '')
		FROM ai_agent_sessions s
		LEFT JOIN ai_agent_messages m ON m.session_id = s.id
		WHERE s.agent_id = ? AND s.archived_at IS NULL
	`
	args := []any{agentID}
	if strings.TrimSpace(cursor) != "" {
		baseSQL += `
			AND s.updated_at < (
				SELECT updated_at FROM ai_agent_sessions WHERE id = ?
			)
		`
		args = append(args, strings.TrimSpace(cursor))
	}
	baseSQL += `
		GROUP BY s.id, s.agent_id, s.title, s.context_summary_updated_at, s.context_summary_message_count, s.created_at, s.updated_at, s.archived_at
		ORDER BY s.updated_at DESC
		LIMIT ?
	`
	args = append(args, limit)

	rows, err := r.db.QueryContext(ctx, baseSQL, args...)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list ai sessions: %v", err))
	}
	defer rows.Close()

	items := make([]AgentSession, 0)
	for rows.Next() {
		var item AgentSession
		if err := rows.Scan(
			&item.ID,
			&item.AgentID,
			&item.Title,
			&item.LastMessageAt,
			&item.SummaryUpdatedAt,
			&item.SummaryMessageCount,
			&item.CreatedAt,
			&item.UpdatedAt,
			&item.ArchivedAt,
		); err != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan ai session: %v", err))
		}
		item.ContextSummaryUpdatedAt = item.SummaryUpdatedAt
		item.ContextSummaryMessageCount = item.SummaryMessageCount
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate ai sessions: %v", err))
	}
	return items, nil
}

func (r *SQLiteAgentRepository) CreateSession(ctx context.Context, item AgentSession) (AgentSession, error) {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO ai_agent_sessions (
			id, agent_id, title, context_summary_text, context_summary_meta_json, context_summary_updated_at, context_summary_message_count, created_at, updated_at, archived_at
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
	`,
		item.ID,
		item.AgentID,
		item.Title,
		strings.TrimSpace(item.ContextSummaryText),
		mustJSON(item.ContextSummaryMeta, "{}"),
		nullableStringValue(strings.TrimSpace(item.ContextSummaryUpdatedAt)),
		item.ContextSummaryMessageCount,
		item.CreatedAt,
		item.UpdatedAt,
	)
	if err != nil {
		return AgentSession{}, errs.Internal(fmt.Sprintf("failed to create ai session: %v", err))
	}
	return item, nil
}

func (r *SQLiteAgentRepository) GetSessionByID(ctx context.Context, sessionID string) (AgentSession, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT
			s.id,
			s.agent_id,
			s.title,
			COALESCE(MAX(m.created_at), '') AS last_message_at,
			COALESCE(s.context_summary_text, '') AS context_summary_text,
			COALESCE(s.context_summary_meta_json, '{}') AS context_summary_meta_json,
			COALESCE(s.context_summary_updated_at, '') AS context_summary_updated_at,
			COALESCE(s.context_summary_message_count, 0) AS context_summary_message_count,
			s.created_at,
			s.updated_at,
			COALESCE(s.archived_at, '')
		FROM ai_agent_sessions s
		LEFT JOIN ai_agent_messages m ON m.session_id = s.id
		WHERE s.id = ?
		GROUP BY s.id, s.agent_id, s.title, s.context_summary_text, s.context_summary_meta_json, s.context_summary_updated_at, s.context_summary_message_count, s.created_at, s.updated_at, s.archived_at
	`, sessionID)

	var item AgentSession
	var summaryMetaJSON string
	if err := row.Scan(
		&item.ID,
		&item.AgentID,
		&item.Title,
		&item.LastMessageAt,
		&item.ContextSummaryText,
		&summaryMetaJSON,
		&item.ContextSummaryUpdatedAt,
		&item.ContextSummaryMessageCount,
		&item.CreatedAt,
		&item.UpdatedAt,
		&item.ArchivedAt,
	); err != nil {
		if err == sql.ErrNoRows {
			return AgentSession{}, errs.NotFound("ai session not found")
		}
		return AgentSession{}, errs.Internal(fmt.Sprintf("failed to get ai session: %v", err))
	}
	item.SummaryUpdatedAt = item.ContextSummaryUpdatedAt
	item.SummaryMessageCount = item.ContextSummaryMessageCount
	item.ContextSummaryMeta = map[string]any{}
	_ = json.Unmarshal([]byte(strings.TrimSpace(summaryMetaJSON)), &item.ContextSummaryMeta)
	return item, nil
}

func (r *SQLiteAgentRepository) DeleteSession(ctx context.Context, sessionID string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM ai_agent_sessions WHERE id = ?`, sessionID)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete ai session: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("ai session not found")
	}
	return nil
}

func (r *SQLiteAgentRepository) ListMessages(
	ctx context.Context,
	sessionID string,
	limit int,
	beforeID string,
) ([]AgentMessage, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}

	baseSQL := `
		SELECT
			m.id,
			m.session_id,
			m.role,
			m.content,
			m.intent_json,
			m.pending_confirmation_json,
			m.provider_used,
			m.model_used,
			m.fallback_used,
			m.latency_ms,
			m.created_at,
			COALESCE(a.id, '')
		FROM ai_agent_messages m
		LEFT JOIN ai_agent_artifacts a ON a.message_id = m.id
		WHERE m.session_id = ?
	`
	args := []any{sessionID}
	if strings.TrimSpace(beforeID) != "" {
		baseSQL += `
			AND m.created_at < (
				SELECT created_at FROM ai_agent_messages WHERE id = ?
			)
		`
		args = append(args, strings.TrimSpace(beforeID))
	}
	baseSQL += ` ORDER BY m.created_at DESC LIMIT ?`
	args = append(args, limit)

	rows, err := r.db.QueryContext(ctx, baseSQL, args...)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list ai messages: %v", err))
	}
	defer rows.Close()

	items := make([]AgentMessage, 0)
	for rows.Next() {
		item, scanErr := scanAgentMessage(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan ai message: %v", scanErr))
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate ai messages: %v", err))
	}
	return items, nil
}

func (r *SQLiteAgentRepository) ListMessagesByOffset(
	ctx context.Context,
	sessionID string,
	offset int,
	limit int,
) ([]AgentMessage, error) {
	if offset < 0 {
		offset = 0
	}
	if limit <= 0 {
		return []AgentMessage{}, nil
	}
	if limit > 1000 {
		limit = 1000
	}

	rows, err := r.db.QueryContext(ctx, `
		SELECT
			m.id,
			m.session_id,
			m.role,
			m.content,
			m.intent_json,
			m.pending_confirmation_json,
			m.provider_used,
			m.model_used,
			m.fallback_used,
			m.latency_ms,
			m.created_at,
			COALESCE(a.id, '')
		FROM ai_agent_messages m
		LEFT JOIN ai_agent_artifacts a ON a.message_id = m.id
		WHERE m.session_id = ?
		ORDER BY m.created_at ASC
		LIMIT ? OFFSET ?
	`, sessionID, limit, offset)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list ai messages by offset: %v", err))
	}
	defer rows.Close()

	items := make([]AgentMessage, 0, limit)
	for rows.Next() {
		item, scanErr := scanAgentMessage(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan ai message: %v", scanErr))
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate ai messages: %v", err))
	}
	return items, nil
}

func (r *SQLiteAgentRepository) CountMessages(ctx context.Context, sessionID string) (int, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT COUNT(1)
		FROM ai_agent_messages
		WHERE session_id = ?
	`, sessionID)

	var count int
	if err := row.Scan(&count); err != nil {
		return 0, errs.Internal(fmt.Sprintf("failed to count ai messages: %v", err))
	}
	return count, nil
}

func (r *SQLiteAgentRepository) GetMessageByID(ctx context.Context, messageID string) (AgentMessage, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT
			m.id,
			m.session_id,
			m.role,
			m.content,
			m.intent_json,
			m.pending_confirmation_json,
			m.provider_used,
			m.model_used,
			m.fallback_used,
			m.latency_ms,
			m.created_at,
			COALESCE(a.id, '')
		FROM ai_agent_messages m
		LEFT JOIN ai_agent_artifacts a ON a.message_id = m.id
		WHERE m.id = ?
	`, messageID)

	item, err := scanAgentMessage(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return AgentMessage{}, errs.NotFound("ai message not found")
		}
		return AgentMessage{}, errs.Internal(fmt.Sprintf("failed to get ai message: %v", err))
	}
	return item, nil
}

func (r *SQLiteAgentRepository) CreateMessage(ctx context.Context, item AgentMessage) (AgentMessage, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return AgentMessage{}, errs.Internal(fmt.Sprintf("failed to begin tx for ai message: %v", err))
	}
	defer func() {
		_ = tx.Rollback()
	}()

	_, err = tx.ExecContext(ctx, `
		INSERT INTO ai_agent_messages (
			id, session_id, role, content, intent_json, pending_confirmation_json, provider_used, model_used, fallback_used, latency_ms, created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.SessionID,
		item.Role,
		item.Content,
		mustJSONString(item.Intent),
		mustJSONString(item.PendingConfirmation),
		item.ProviderUsed,
		item.ModelUsed,
		boolToInt(item.FallbackUsed),
		item.LatencyMS,
		item.CreatedAt,
	)
	if err != nil {
		return AgentMessage{}, errs.Internal(fmt.Sprintf("failed to create ai message: %v", err))
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE ai_agent_sessions
		SET updated_at = ?
		WHERE id = ?
	`, item.CreatedAt, item.SessionID)
	if err != nil {
		return AgentMessage{}, errs.Internal(fmt.Sprintf("failed to touch ai session: %v", err))
	}
	if err := tx.Commit(); err != nil {
		return AgentMessage{}, errs.Internal(fmt.Sprintf("failed to commit ai message tx: %v", err))
	}
	return item, nil
}

func (r *SQLiteAgentRepository) UpdateSessionSummary(
	ctx context.Context,
	sessionID string,
	summaryText string,
	summaryMeta map[string]any,
	summaryUpdatedAt string,
	summaryMessageCount int,
) error {
	res, err := r.db.ExecContext(ctx, `
		UPDATE ai_agent_sessions
		SET
			context_summary_text = ?,
			context_summary_meta_json = ?,
			context_summary_updated_at = ?,
			context_summary_message_count = ?
		WHERE id = ?
	`,
		strings.TrimSpace(summaryText),
		mustJSON(summaryMeta, "{}"),
		nullableStringValue(strings.TrimSpace(summaryUpdatedAt)),
		summaryMessageCount,
		sessionID,
	)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to update ai session summary: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("ai session not found")
	}
	return nil
}

func (r *SQLiteAgentRepository) ListArtifacts(
	ctx context.Context,
	sessionID,
	status string,
) ([]AgentArtifact, error) {
	sqlText := `
		SELECT id, session_id, message_id, type, payload_json, import_status, created_at, COALESCE(imported_at, '')
		FROM ai_agent_artifacts
		WHERE session_id = ?
	`
	args := []any{sessionID}
	if strings.TrimSpace(status) != "" {
		sqlText += ` AND import_status = ?`
		args = append(args, strings.TrimSpace(status))
	}
	sqlText += ` ORDER BY created_at DESC`

	rows, err := r.db.QueryContext(ctx, sqlText, args...)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list ai artifacts: %v", err))
	}
	defer rows.Close()

	items := make([]AgentArtifact, 0)
	for rows.Next() {
		item, scanErr := scanAgentArtifact(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan ai artifact: %v", scanErr))
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate ai artifacts: %v", err))
	}
	return items, nil
}

func (r *SQLiteAgentRepository) GetArtifactByID(ctx context.Context, artifactID string) (AgentArtifact, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT id, session_id, message_id, type, payload_json, import_status, created_at, COALESCE(imported_at, '')
		FROM ai_agent_artifacts
		WHERE id = ?
	`, artifactID)
	item, err := scanAgentArtifact(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return AgentArtifact{}, errs.NotFound("ai artifact not found")
		}
		return AgentArtifact{}, errs.Internal(fmt.Sprintf("failed to get ai artifact: %v", err))
	}
	return item, nil
}

func (r *SQLiteAgentRepository) CreateArtifact(ctx context.Context, item AgentArtifact) (AgentArtifact, error) {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO ai_agent_artifacts (
			id, session_id, message_id, type, payload_json, import_status, created_at, imported_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.SessionID,
		item.MessageID,
		item.Type,
		mustJSON(item.Payload, "{}"),
		item.ImportStatus,
		item.CreatedAt,
		nullableStringValue(item.ImportedAt),
	)
	if err != nil {
		return AgentArtifact{}, errs.Internal(fmt.Sprintf("failed to create ai artifact: %v", err))
	}
	return item, nil
}

func (r *SQLiteAgentRepository) UpdateArtifactImportStatus(
	ctx context.Context,
	artifactID,
	status,
	importedAt string,
) error {
	res, err := r.db.ExecContext(ctx, `
		UPDATE ai_agent_artifacts
		SET import_status = ?, imported_at = ?
		WHERE id = ?
	`, strings.TrimSpace(status), nullableStringValue(strings.TrimSpace(importedAt)), artifactID)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to update ai artifact import status: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("ai artifact not found")
	}
	return nil
}

type agentScanner interface {
	Scan(dest ...any) error
}

func scanAgent(s agentScanner) (Agent, error) {
	var (
		item           Agent
		protocol       string
		primaryJSON    string
		fallbackJSON   string
		capabilityJSON string
		enabledInt     int
	)
	if err := s.Scan(
		&item.ID,
		&item.Name,
		&protocol,
		&primaryJSON,
		&fallbackJSON,
		&item.SystemPrompt,
		&capabilityJSON,
		&enabledInt,
		&item.CreatedAt,
		&item.UpdatedAt,
	); err != nil {
		return Agent{}, err
	}
	item.Protocol = AgentProtocol(strings.TrimSpace(protocol))
	_ = json.Unmarshal([]byte(primaryJSON), &item.Primary)
	_ = json.Unmarshal([]byte(fallbackJSON), &item.Fallback)
	_ = json.Unmarshal([]byte(capabilityJSON), &item.IntentCapabilities)
	item.IntentCapabilities = withDefaultManageAppCapability(item.IntentCapabilities)
	item.Enabled = enabledInt > 0
	return item, nil
}

func scanAgentMessage(s agentScanner) (AgentMessage, error) {
	var (
		item            AgentMessage
		intentJSON      string
		pendingJSON     string
		fallbackUsedInt int
	)
	if err := s.Scan(
		&item.ID,
		&item.SessionID,
		&item.Role,
		&item.Content,
		&intentJSON,
		&pendingJSON,
		&item.ProviderUsed,
		&item.ModelUsed,
		&fallbackUsedInt,
		&item.LatencyMS,
		&item.CreatedAt,
		&item.ArtifactID,
	); err != nil {
		return AgentMessage{}, err
	}
	item.FallbackUsed = fallbackUsedInt > 0
	intentJSON = strings.TrimSpace(intentJSON)
	if intentJSON != "" && !strings.EqualFold(intentJSON, "null") {
		intent := IntentResult{}
		if err := json.Unmarshal([]byte(intentJSON), &intent); err == nil {
			if intent.Params == nil {
				intent.Params = map[string]any{}
			}
			item.Intent = &intent
		}
	}
	pendingJSON = strings.TrimSpace(pendingJSON)
	if pendingJSON != "" && !strings.EqualFold(pendingJSON, "null") {
		pending := PendingConfirmation{}
		if err := json.Unmarshal([]byte(pendingJSON), &pending); err == nil {
			if pending.Params == nil {
				pending.Params = map[string]any{}
			}
			item.PendingConfirmation = &pending
		}
	}
	return item, nil
}

func scanAgentArtifact(s agentScanner) (AgentArtifact, error) {
	var (
		item        AgentArtifact
		payloadJSON string
	)
	if err := s.Scan(
		&item.ID,
		&item.SessionID,
		&item.MessageID,
		&item.Type,
		&payloadJSON,
		&item.ImportStatus,
		&item.CreatedAt,
		&item.ImportedAt,
	); err != nil {
		return AgentArtifact{}, err
	}
	item.Payload = map[string]any{}
	_ = json.Unmarshal([]byte(payloadJSON), &item.Payload)
	return item, nil
}

func mustJSON(v any, fallback string) string {
	if v == nil {
		return fallback
	}
	data, err := json.Marshal(v)
	if err != nil {
		return fallback
	}
	return string(data)
}

func mustJSONString(v any) string {
	if v == nil {
		return ""
	}
	data, err := json.Marshal(v)
	if err != nil {
		return ""
	}
	serialized := strings.TrimSpace(string(data))
	if strings.EqualFold(serialized, "null") {
		return ""
	}
	return serialized
}

func boolToInt(v bool) int {
	if v {
		return 1
	}
	return 0
}

func nowRFC3339() string {
	return time.Now().UTC().Format(time.RFC3339Nano)
}

func nullableStringValue(v string) any {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return strings.TrimSpace(v)
}
