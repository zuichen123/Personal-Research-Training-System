package sqlite

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
)

func Migrate(ctx context.Context, db *sql.DB) error {
	baseStmts := []string{
		`CREATE TABLE IF NOT EXISTS questions (
			id TEXT PRIMARY KEY,
			title TEXT NOT NULL,
			stem TEXT NOT NULL,
			type TEXT NOT NULL,
			subject TEXT NOT NULL DEFAULT 'general',
			source TEXT NOT NULL DEFAULT 'unit_test',
			options_json TEXT NOT NULL,
			answer_key_json TEXT NOT NULL,
			tags_json TEXT NOT NULL,
			difficulty INTEGER NOT NULL,
			mastery_level INTEGER NOT NULL DEFAULT 0,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS mistakes (
			id TEXT PRIMARY KEY,
			question_id TEXT NOT NULL,
			subject TEXT NOT NULL DEFAULT 'general',
			difficulty INTEGER NOT NULL DEFAULT 1,
			mastery_level INTEGER NOT NULL DEFAULT 0,
			user_answer_json TEXT NOT NULL,
			feedback TEXT NOT NULL,
			reason TEXT NOT NULL,
			created_at TEXT NOT NULL,
			FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS practice_attempts (
			id TEXT PRIMARY KEY,
			question_id TEXT NOT NULL,
			user_answer_json TEXT NOT NULL,
			elapsed_seconds INTEGER NOT NULL DEFAULT 0,
			score REAL NOT NULL,
			correct INTEGER NOT NULL,
			feedback TEXT NOT NULL,
			submitted_at TEXT NOT NULL,
			FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS resources (
			id TEXT PRIMARY KEY,
			filename TEXT NOT NULL,
			content_type TEXT NOT NULL,
			size_bytes INTEGER NOT NULL,
			category TEXT NOT NULL,
			tags_json TEXT NOT NULL,
			question_id TEXT,
			uploaded_at TEXT NOT NULL,
			sha256 TEXT NOT NULL,
			data BLOB NOT NULL,
			FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE SET NULL
		);`,
		`CREATE TABLE IF NOT EXISTS plans (
			id TEXT PRIMARY KEY,
			plan_type TEXT NOT NULL,
			title TEXT NOT NULL,
			content TEXT NOT NULL,
			target_date TEXT,
			status TEXT NOT NULL,
			priority INTEGER NOT NULL,
			source TEXT NOT NULL DEFAULT 'manual',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS pomodoro_sessions (
			id TEXT PRIMARY KEY,
			task_title TEXT NOT NULL,
			plan_id TEXT,
			duration_minutes INTEGER NOT NULL,
			break_minutes INTEGER NOT NULL,
			status TEXT NOT NULL,
			started_at TEXT NOT NULL,
			ended_at TEXT,
			FOREIGN KEY(plan_id) REFERENCES plans(id) ON DELETE SET NULL
		);`,
		`CREATE TABLE IF NOT EXISTS ai_provider_config (
			id INTEGER PRIMARY KEY CHECK (id = 1),
			provider TEXT NOT NULL DEFAULT 'mock',
			openai_base_url TEXT NOT NULL DEFAULT 'https://api.openai.com/v1',
			openai_api_key TEXT NOT NULL DEFAULT '',
			openai_model TEXT NOT NULL DEFAULT 'gpt-4o-mini',
			gemini_api_key TEXT NOT NULL DEFAULT '',
			gemini_model TEXT NOT NULL DEFAULT 'gemini-1.5-flash',
			claude_api_key TEXT NOT NULL DEFAULT '',
			claude_model TEXT NOT NULL DEFAULT 'claude-3-5-sonnet-20241022',
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS ai_prompt_templates (
			prompt_key TEXT PRIMARY KEY,
			custom_prompt TEXT NOT NULL DEFAULT '',
			output_format_prompt TEXT NOT NULL DEFAULT '',
			segment_overrides_json TEXT NOT NULL DEFAULT '{}',
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS ai_agents (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			protocol TEXT NOT NULL,
			primary_config_json TEXT NOT NULL,
			fallback_config_json TEXT NOT NULL,
			system_prompt TEXT NOT NULL DEFAULT '',
			intent_capabilities_json TEXT NOT NULL DEFAULT '[]',
			enabled INTEGER NOT NULL DEFAULT 1,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS ai_agent_sessions (
			id TEXT PRIMARY KEY,
			agent_id TEXT NOT NULL,
			title TEXT NOT NULL,
			context_summary_text TEXT NOT NULL DEFAULT '',
			context_summary_meta_json TEXT NOT NULL DEFAULT '{}',
			context_summary_updated_at TEXT,
			context_summary_message_count INTEGER NOT NULL DEFAULT 0,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			archived_at TEXT,
			FOREIGN KEY(agent_id) REFERENCES ai_agents(id) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS ai_agent_messages (
			id TEXT PRIMARY KEY,
			session_id TEXT NOT NULL,
			role TEXT NOT NULL,
			content TEXT NOT NULL,
			intent_json TEXT NOT NULL DEFAULT '',
			pending_confirmation_json TEXT NOT NULL DEFAULT '',
			provider_used TEXT NOT NULL DEFAULT '',
			model_used TEXT NOT NULL DEFAULT '',
			fallback_used INTEGER NOT NULL DEFAULT 0,
			latency_ms INTEGER NOT NULL DEFAULT 0,
			created_at TEXT NOT NULL,
			FOREIGN KEY(session_id) REFERENCES ai_agent_sessions(id) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS ai_agent_artifacts (
			id TEXT PRIMARY KEY,
			session_id TEXT NOT NULL,
			message_id TEXT NOT NULL,
			type TEXT NOT NULL,
			payload_json TEXT NOT NULL,
			import_status TEXT NOT NULL DEFAULT 'pending',
			created_at TEXT NOT NULL,
			imported_at TEXT,
			FOREIGN KEY(session_id) REFERENCES ai_agent_sessions(id) ON DELETE CASCADE,
			FOREIGN KEY(message_id) REFERENCES ai_agent_messages(id) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS user_profiles (
			user_id TEXT PRIMARY KEY,
			nickname TEXT NOT NULL DEFAULT '',
			age INTEGER NOT NULL DEFAULT 0,
			academic_status TEXT NOT NULL DEFAULT '',
			goals_json TEXT NOT NULL DEFAULT '[]',
			goal_target_date TEXT,
			daily_study_minutes INTEGER NOT NULL DEFAULT 0,
			weak_subjects_json TEXT NOT NULL DEFAULT '[]',
			target_destination TEXT NOT NULL DEFAULT '',
			notes TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`INSERT OR IGNORE INTO user_profiles (
			user_id, nickname, age, academic_status, goals_json, goal_target_date,
			daily_study_minutes, weak_subjects_json, target_destination, notes, created_at, updated_at
		) VALUES (
			'default', '', 0, '', '[]', NULL, 0, '[]', '', '',
			strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
			strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
		);`,
		`CREATE INDEX IF NOT EXISTS idx_mistakes_question_id ON mistakes(question_id);`,
		`CREATE INDEX IF NOT EXISTS idx_practice_attempts_question_id ON practice_attempts(question_id);`,
		`CREATE INDEX IF NOT EXISTS idx_resources_question_id ON resources(question_id);`,
		`CREATE INDEX IF NOT EXISTS idx_plans_type_date ON plans(plan_type, target_date);`,
		`CREATE INDEX IF NOT EXISTS idx_pomodoro_status_start ON pomodoro_sessions(status, started_at);`,
		`CREATE INDEX IF NOT EXISTS idx_ai_sessions_agent_updated ON ai_agent_sessions(agent_id, updated_at DESC);`,
		`CREATE INDEX IF NOT EXISTS idx_ai_messages_session_created ON ai_agent_messages(session_id, created_at DESC);`,
		`CREATE INDEX IF NOT EXISTS idx_ai_artifacts_session_status ON ai_agent_artifacts(session_id, import_status, created_at DESC);`,
	}

	for _, stmt := range baseStmts {
		if _, err := db.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("migrate sqlite: %w", err)
		}
	}

	optionalStmts := []string{
		`ALTER TABLE questions ADD COLUMN subject TEXT NOT NULL DEFAULT 'general';`,
		`ALTER TABLE questions ADD COLUMN source TEXT NOT NULL DEFAULT 'unit_test';`,
		`ALTER TABLE questions ADD COLUMN mastery_level INTEGER NOT NULL DEFAULT 0;`,
		`ALTER TABLE mistakes ADD COLUMN subject TEXT NOT NULL DEFAULT 'general';`,
		`ALTER TABLE mistakes ADD COLUMN difficulty INTEGER NOT NULL DEFAULT 1;`,
		`ALTER TABLE mistakes ADD COLUMN mastery_level INTEGER NOT NULL DEFAULT 0;`,
		`ALTER TABLE practice_attempts ADD COLUMN elapsed_seconds INTEGER NOT NULL DEFAULT 0;`,
		`ALTER TABLE plans ADD COLUMN source TEXT NOT NULL DEFAULT 'manual';`,
		`ALTER TABLE ai_agent_sessions ADD COLUMN context_summary_text TEXT NOT NULL DEFAULT '';`,
		`ALTER TABLE ai_agent_sessions ADD COLUMN context_summary_meta_json TEXT NOT NULL DEFAULT '{}';`,
		`ALTER TABLE ai_agent_sessions ADD COLUMN context_summary_updated_at TEXT;`,
		`ALTER TABLE ai_agent_sessions ADD COLUMN context_summary_message_count INTEGER NOT NULL DEFAULT 0;`,
		`ALTER TABLE ai_prompt_templates ADD COLUMN segment_overrides_json TEXT NOT NULL DEFAULT '{}';`,
	}

	for _, stmt := range optionalStmts {
		if err := execOptional(ctx, db, stmt); err != nil {
			return err
		}
	}

	postOptionalStmts := []string{
		`CREATE INDEX IF NOT EXISTS idx_plans_source_updated ON plans(source, updated_at DESC);`,
	}

	for _, stmt := range postOptionalStmts {
		if _, err := db.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("migrate sqlite: %w", err)
		}
	}

	return nil
}

func execOptional(ctx context.Context, db *sql.DB, stmt string) error {
	_, err := db.ExecContext(ctx, stmt)
	if err == nil {
		return nil
	}
	msg := strings.ToLower(err.Error())
	if strings.Contains(msg, "duplicate column name") || strings.Contains(msg, "already exists") {
		return nil
	}
	return fmt.Errorf("optional migrate sqlite: %w", err)
}
