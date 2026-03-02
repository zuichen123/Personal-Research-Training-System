package sqlite

import (
	"context"
	"database/sql"
	"fmt"
)

func Migrate(ctx context.Context, db *sql.DB) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS questions (
			id TEXT PRIMARY KEY,
			title TEXT NOT NULL,
			stem TEXT NOT NULL,
			type TEXT NOT NULL,
			options_json TEXT NOT NULL,
			answer_key_json TEXT NOT NULL,
			tags_json TEXT NOT NULL,
			difficulty INTEGER NOT NULL,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS mistakes (
			id TEXT PRIMARY KEY,
			question_id TEXT NOT NULL,
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
		`CREATE INDEX IF NOT EXISTS idx_mistakes_question_id ON mistakes(question_id);`,
		`CREATE INDEX IF NOT EXISTS idx_practice_attempts_question_id ON practice_attempts(question_id);`,
		`CREATE INDEX IF NOT EXISTS idx_resources_question_id ON resources(question_id);`,
	}

	for _, stmt := range stmts {
		if _, err := db.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("migrate sqlite: %w", err)
		}
	}

	return nil
}
