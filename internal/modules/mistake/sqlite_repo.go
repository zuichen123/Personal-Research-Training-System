package mistake

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

func (r *SQLiteRepository) Create(ctx context.Context, item Record) (Record, error) {
	answerJSON, err := json.Marshal(item.UserAnswer)
	if err != nil {
		return Record{}, errs.Internal("failed to encode user answer")
	}

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO mistakes (
			id, question_id, subject, unit, difficulty, mastery_level, user_answer_json, feedback, reason, created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.QuestionID,
		item.Subject,
		item.Unit,
		item.Difficulty,
		item.MasteryLevel,
		string(answerJSON),
		item.Feedback,
		item.Reason,
		item.CreatedAt.Format(time.RFC3339Nano),
	)
	if err != nil {
		return Record{}, errs.Internal(fmt.Sprintf("failed to create mistake: %v", err))
	}

	return item, nil
}

func (r *SQLiteRepository) GetByID(ctx context.Context, id string) (Record, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT id, question_id, subject, COALESCE(unit, ''), difficulty, mastery_level, user_answer_json, feedback, reason, created_at
		FROM mistakes
		WHERE id = ?
	`, id)
	item, err := scanMistake(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return Record{}, errs.NotFound("mistake not found")
		}
		return Record{}, errs.Internal(fmt.Sprintf("failed to get mistake: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) List(ctx context.Context) ([]Record, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, question_id, subject, COALESCE(unit, ''), difficulty, mastery_level, user_answer_json, feedback, reason, created_at
		FROM mistakes
		ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list mistakes: %v", err))
	}
	defer rows.Close()

	result := make([]Record, 0)
	for rows.Next() {
		item, scanErr := scanMistake(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan mistake: %v", scanErr))
		}
		result = append(result, item)
	}

	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate mistakes: %v", err))
	}

	return result, nil
}

func (r *SQLiteRepository) ListByQuestionID(ctx context.Context, questionID string) ([]Record, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, question_id, subject, COALESCE(unit, ''), difficulty, mastery_level, user_answer_json, feedback, reason, created_at
		FROM mistakes
		WHERE question_id = ?
		ORDER BY created_at DESC
	`, questionID)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list mistakes by question id: %v", err))
	}
	defer rows.Close()

	result := make([]Record, 0)
	for rows.Next() {
		item, scanErr := scanMistake(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan mistake: %v", scanErr))
		}
		result = append(result, item)
	}

	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate mistakes: %v", err))
	}

	return result, nil
}

func (r *SQLiteRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM mistakes WHERE id = ?`, id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete mistake: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("mistake not found")
	}
	return nil
}

type mistakeScanner interface {
	Scan(dest ...any) error
}

func scanMistake(s mistakeScanner) (Record, error) {
	var (
		item       Record
		answerRaw  string
		createdRaw string
	)

	if err := s.Scan(
		&item.ID,
		&item.QuestionID,
		&item.Subject,
		&item.Unit,
		&item.Difficulty,
		&item.MasteryLevel,
		&answerRaw,
		&item.Feedback,
		&item.Reason,
		&createdRaw,
	); err != nil {
		return Record{}, err
	}

	if err := json.Unmarshal([]byte(answerRaw), &item.UserAnswer); err != nil {
		return Record{}, err
	}
	createdAt, err := time.Parse(time.RFC3339Nano, createdRaw)
	if err != nil {
		return Record{}, err
	}
	item.CreatedAt = createdAt

	return item, nil
}
