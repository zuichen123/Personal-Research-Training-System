package question

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

func (r *SQLiteRepository) Create(ctx context.Context, item Question) (Question, error) {
	optionsJSON, err := json.Marshal(item.Options)
	if err != nil {
		return Question{}, errs.Internal("failed to encode options")
	}
	answerJSON, err := json.Marshal(item.AnswerKey)
	if err != nil {
		return Question{}, errs.Internal("failed to encode answer key")
	}
	tagsJSON, err := json.Marshal(item.Tags)
	if err != nil {
		return Question{}, errs.Internal("failed to encode tags")
	}

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO questions (
			id, title, stem, type, subject, source, options_json, answer_key_json, tags_json,
			difficulty, mastery_level, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.Title,
		item.Stem,
		string(item.Type),
		item.Subject,
		string(item.Source),
		string(optionsJSON),
		string(answerJSON),
		string(tagsJSON),
		item.Difficulty,
		item.MasteryLevel,
		item.CreatedAt.Format(time.RFC3339Nano),
		item.UpdatedAt.Format(time.RFC3339Nano),
	)
	if err != nil {
		return Question{}, errs.Internal(fmt.Sprintf("failed to create question: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) GetByID(ctx context.Context, id string) (Question, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT id, title, stem, type, subject, source, options_json, answer_key_json, tags_json,
			difficulty, mastery_level, created_at, updated_at
		FROM questions WHERE id = ?
	`, id)

	item, err := scanQuestion(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return Question{}, errs.NotFound("question not found")
		}
		return Question{}, errs.Internal(fmt.Sprintf("failed to get question: %v", err))
	}

	return item, nil
}

func (r *SQLiteRepository) List(ctx context.Context) ([]Question, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, title, stem, type, subject, source, options_json, answer_key_json, tags_json,
			difficulty, mastery_level, created_at, updated_at
		FROM questions
		ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list questions: %v", err))
	}
	defer rows.Close()

	items := make([]Question, 0)
	for rows.Next() {
		item, scanErr := scanQuestion(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan question: %v", scanErr))
		}
		items = append(items, item)
	}

	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate questions: %v", err))
	}

	return items, nil
}

func (r *SQLiteRepository) Update(ctx context.Context, item Question) (Question, error) {
	optionsJSON, err := json.Marshal(item.Options)
	if err != nil {
		return Question{}, errs.Internal("failed to encode options")
	}
	answerJSON, err := json.Marshal(item.AnswerKey)
	if err != nil {
		return Question{}, errs.Internal("failed to encode answer key")
	}
	tagsJSON, err := json.Marshal(item.Tags)
	if err != nil {
		return Question{}, errs.Internal("failed to encode tags")
	}

	res, err := r.db.ExecContext(ctx, `
		UPDATE questions
		SET title = ?, stem = ?, type = ?, subject = ?, source = ?, options_json = ?,
			answer_key_json = ?, tags_json = ?, difficulty = ?, mastery_level = ?, updated_at = ?
		WHERE id = ?
	`,
		item.Title,
		item.Stem,
		string(item.Type),
		item.Subject,
		string(item.Source),
		string(optionsJSON),
		string(answerJSON),
		string(tagsJSON),
		item.Difficulty,
		item.MasteryLevel,
		item.UpdatedAt.Format(time.RFC3339Nano),
		item.ID,
	)
	if err != nil {
		return Question{}, errs.Internal(fmt.Sprintf("failed to update question: %v", err))
	}

	affected, _ := res.RowsAffected()
	if affected == 0 {
		return Question{}, errs.NotFound("question not found")
	}

	return item, nil
}

func (r *SQLiteRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM questions WHERE id = ?`, id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete question: %v", err))
	}

	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("question not found")
	}

	return nil
}

type questionScanner interface {
	Scan(dest ...any) error
}

func scanQuestion(s questionScanner) (Question, error) {
	var (
		item       Question
		typeValue  string
		source     string
		optionsRaw string
		answerRaw  string
		tagsRaw    string
		createdRaw string
		updatedRaw string
	)

	if err := s.Scan(
		&item.ID,
		&item.Title,
		&item.Stem,
		&typeValue,
		&item.Subject,
		&source,
		&optionsRaw,
		&answerRaw,
		&tagsRaw,
		&item.Difficulty,
		&item.MasteryLevel,
		&createdRaw,
		&updatedRaw,
	); err != nil {
		return Question{}, err
	}

	item.Type = QuestionType(typeValue)
	item.Source = QuestionSource(source)
	if err := json.Unmarshal([]byte(optionsRaw), &item.Options); err != nil {
		return Question{}, err
	}
	if err := json.Unmarshal([]byte(answerRaw), &item.AnswerKey); err != nil {
		return Question{}, err
	}
	if err := json.Unmarshal([]byte(tagsRaw), &item.Tags); err != nil {
		return Question{}, err
	}

	createdAt, err := time.Parse(time.RFC3339Nano, createdRaw)
	if err != nil {
		return Question{}, err
	}
	updatedAt, err := time.Parse(time.RFC3339Nano, updatedRaw)
	if err != nil {
		return Question{}, err
	}

	item.CreatedAt = createdAt
	item.UpdatedAt = updatedAt
	return item, nil
}
