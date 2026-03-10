package material

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"self-study-tool/internal/shared/errs"
)

type SQLiteRepository struct {
	db *sql.DB
}

func NewSQLiteRepository(db *sql.DB) *SQLiteRepository {
	return &SQLiteRepository{db: db}
}

func (r *SQLiteRepository) Create(ctx context.Context, item Material) (Material, error) {
	if item.ID == "" {
		item.ID = uuid.NewString()
	}
	tagsJSON, _ := json.Marshal(item.Tags)
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO materials (id, user_id, title, file_path, file_type, content_text, subject, tags_json, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, item.ID, item.UserID, item.Title, item.FilePath, item.FileType, item.ContentText, item.Subject, string(tagsJSON), item.CreatedAt.Format(time.RFC3339Nano), item.UpdatedAt.Format(time.RFC3339Nano))
	if err != nil {
		return Material{}, errs.Internal(fmt.Sprintf("create material: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) GetByID(ctx context.Context, id string) (Material, error) {
	var item Material
	var tagsJSON string
	var createdAt, updatedAt string
	err := r.db.QueryRowContext(ctx, `
		SELECT id, user_id, title, file_path, file_type, COALESCE(content_text, ''), COALESCE(subject, ''), COALESCE(tags_json, '[]'), created_at, updated_at
		FROM materials WHERE id = ?
	`, id).Scan(&item.ID, &item.UserID, &item.Title, &item.FilePath, &item.FileType, &item.ContentText, &item.Subject, &tagsJSON, &createdAt, &updatedAt)
	if err == sql.ErrNoRows {
		return Material{}, errs.NotFound("material not found")
	}
	if err != nil {
		return Material{}, errs.Internal(fmt.Sprintf("get material: %v", err))
	}
	json.Unmarshal([]byte(tagsJSON), &item.Tags)
	item.CreatedAt, _ = time.Parse(time.RFC3339Nano, createdAt)
	item.UpdatedAt, _ = time.Parse(time.RFC3339Nano, updatedAt)
	return item, nil
}

func (r *SQLiteRepository) List(ctx context.Context, filter ListFilter) ([]Material, error) {
	query := `SELECT id, user_id, title, file_path, file_type, COALESCE(content_text, ''), COALESCE(subject, ''), COALESCE(tags_json, '[]'), created_at, updated_at FROM materials WHERE 1=1`
	args := []interface{}{}
	if filter.UserID != "" {
		query += " AND user_id = ?"
		args = append(args, filter.UserID)
	}
	if filter.Subject != "" {
		query += " AND subject = ?"
		args = append(args, filter.Subject)
	}
	if filter.FileType != "" {
		query += " AND file_type = ?"
		args = append(args, filter.FileType)
	}
	if filter.Keyword != "" {
		query += " AND (title LIKE ? OR content_text LIKE ?)"
		keyword := "%" + filter.Keyword + "%"
		args = append(args, keyword, keyword)
	}
	query += " ORDER BY created_at DESC"
	if filter.Limit > 0 {
		query += " LIMIT ?"
		args = append(args, filter.Limit)
	}
	if filter.Offset > 0 {
		query += " OFFSET ?"
		args = append(args, filter.Offset)
	}
	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("list materials: %v", err))
	}
	defer rows.Close()
	var items []Material
	for rows.Next() {
		var item Material
		var tagsJSON, createdAt, updatedAt string
		if err := rows.Scan(&item.ID, &item.UserID, &item.Title, &item.FilePath, &item.FileType, &item.ContentText, &item.Subject, &tagsJSON, &createdAt, &updatedAt); err != nil {
			return nil, errs.Internal(fmt.Sprintf("scan material: %v", err))
		}
		json.Unmarshal([]byte(tagsJSON), &item.Tags)
		item.CreatedAt, _ = time.Parse(time.RFC3339Nano, createdAt)
		item.UpdatedAt, _ = time.Parse(time.RFC3339Nano, updatedAt)
		items = append(items, item)
	}
	return items, nil
}

func (r *SQLiteRepository) Update(ctx context.Context, id string, item Material) (Material, error) {
	tagsJSON, _ := json.Marshal(item.Tags)
	_, err := r.db.ExecContext(ctx, `
		UPDATE materials SET title = ?, subject = ?, tags_json = ?, updated_at = ? WHERE id = ?
	`, item.Title, item.Subject, string(tagsJSON), item.UpdatedAt.Format(time.RFC3339Nano), id)
	if err != nil {
		return Material{}, errs.Internal(fmt.Sprintf("update material: %v", err))
	}
	return r.GetByID(ctx, id)
}

func (r *SQLiteRepository) Delete(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM materials WHERE id = ?", id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("delete material: %v", err))
	}
	return nil
}
