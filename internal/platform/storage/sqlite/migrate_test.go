package sqlite

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
)

func TestMigrateLegacyPlansWithoutSource(t *testing.T) {
	t.Helper()

	db := openTestDB(t)
	defer db.Close()

	_, err := db.Exec(`
		CREATE TABLE plans (
			id TEXT PRIMARY KEY,
			plan_type TEXT NOT NULL,
			title TEXT NOT NULL,
			content TEXT NOT NULL,
			target_date TEXT,
			status TEXT NOT NULL,
			priority INTEGER NOT NULL,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);
	`)
	if err != nil {
		t.Fatalf("create legacy plans table: %v", err)
	}

	if err := Migrate(context.Background(), db); err != nil {
		t.Fatalf("migrate should succeed for legacy plans table: %v", err)
	}

	if !hasColumn(t, db, "plans", "source") {
		t.Fatalf("expected plans.source column to exist after migration")
	}

	var indexName string
	row := db.QueryRow(`SELECT name FROM sqlite_master WHERE type='index' AND name='idx_plans_source_updated'`)
	if err := row.Scan(&indexName); err != nil {
		t.Fatalf("expected idx_plans_source_updated index to exist: %v", err)
	}
}

func openTestDB(t *testing.T) *sql.DB {
	t.Helper()

	dbPath := filepath.Join(t.TempDir(), "migrate-test.db")
	db, err := Open(dbPath)
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}
	return db
}

func hasColumn(t *testing.T, db *sql.DB, table, column string) bool {
	t.Helper()

	rows, err := db.Query(`PRAGMA table_info(` + table + `)`)
	if err != nil {
		t.Fatalf("query table info for %s: %v", table, err)
	}
	defer rows.Close()

	for rows.Next() {
		var (
			cid       int
			name      string
			colType   string
			notNull   int
			dfltValue sql.NullString
			pk        int
		)
		if err := rows.Scan(&cid, &name, &colType, &notNull, &dfltValue, &pk); err != nil {
			t.Fatalf("scan table info for %s: %v", table, err)
		}
		if name == column {
			return true
		}
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("iterate table info for %s: %v", table, err)
	}
	return false
}
