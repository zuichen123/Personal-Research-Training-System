package resource

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"self-study-tool/internal/shared/errs"
)

type SQLiteRepository struct {
	db *sql.DB
}

func NewSQLiteRepository(db *sql.DB) *SQLiteRepository {
	return &SQLiteRepository{db: db}
}

func (r *SQLiteRepository) Create(ctx context.Context, item Material) (Material, error) {
	tagsJSON, err := json.Marshal(item.Tags)
	if err != nil {
		return Material{}, errs.Internal("failed to encode tags")
	}

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO resources (
			id, filename, content_type, size_bytes, category, tags_json,
			question_id, uploaded_at, sha256, data
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.Filename,
		item.ContentType,
		item.SizeBytes,
		item.Category,
		string(tagsJSON),
		nullableString(item.QuestionID),
		item.UploadedAt.Format(time.RFC3339Nano),
		item.SHA256,
		item.Data,
	)
	if err != nil {
		return Material{}, errs.Internal(fmt.Sprintf("failed to create resource: %v", err))
	}

	return item, nil
}

func (r *SQLiteRepository) GetByID(ctx context.Context, id string) (Material, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT id, filename, content_type, size_bytes, category, tags_json,
			question_id, uploaded_at, sha256, data
		FROM resources
		WHERE id = ?
	`, id)

	item, err := scanMaterial(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return Material{}, errs.NotFound("resource not found")
		}
		return Material{}, errs.Internal(fmt.Sprintf("failed to get resource: %v", err))
	}

	return item, nil
}

func (r *SQLiteRepository) List(ctx context.Context, questionID string) ([]Material, error) {
	baseSQL := `
		SELECT id, filename, content_type, size_bytes, category, tags_json,
			question_id, uploaded_at, sha256, NULL
		FROM resources
	`

	var (
		rows *sql.Rows
		err  error
	)

	if questionID == "" {
		rows, err = r.db.QueryContext(ctx, baseSQL+` ORDER BY uploaded_at DESC`)
	} else {
		rows, err = r.db.QueryContext(ctx, baseSQL+` WHERE question_id = ? ORDER BY uploaded_at DESC`, questionID)
	}
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list resources: %v", err))
	}
	defer rows.Close()

	result := make([]Material, 0)
	for rows.Next() {
		item, scanErr := scanMaterial(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan resource: %v", scanErr))
		}
		item.Data = nil
		result = append(result, item)
	}

	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate resources: %v", err))
	}

	return result, nil
}

func (r *SQLiteRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM resources WHERE id = ?`, id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete resource: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("resource not found")
	}
	return nil
}

type materialScanner interface {
	Scan(dest ...any) error
}

func scanMaterial(s materialScanner) (Material, error) {
	var (
		item          Material
		tagsRaw       string
		questionIDRaw sql.NullString
		timeRaw       string
		data          []byte
	)

	if err := s.Scan(
		&item.ID,
		&item.Filename,
		&item.ContentType,
		&item.SizeBytes,
		&item.Category,
		&tagsRaw,
		&questionIDRaw,
		&timeRaw,
		&item.SHA256,
		&data,
	); err != nil {
		return Material{}, err
	}

	if err := json.Unmarshal([]byte(tagsRaw), &item.Tags); err != nil {
		return Material{}, err
	}
	uploadedAt, err := time.Parse(time.RFC3339Nano, timeRaw)
	if err != nil {
		return Material{}, err
	}
	item.UploadedAt = uploadedAt
	if questionIDRaw.Valid {
		item.QuestionID = questionIDRaw.String
	}
	if len(data) > 0 {
		item.Data = data
	}

	return item, nil
}

func nullableString(v string) any {
	if v == "" {
		return nil
	}
	return v
}
