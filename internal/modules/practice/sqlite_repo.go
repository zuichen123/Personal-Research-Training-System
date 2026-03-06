package practice

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

func (r *SQLiteRepository) Create(ctx context.Context, item Attempt) (Attempt, error) {
	answerJSON, err := json.Marshal(item.UserAnswer)
	if err != nil {
		return Attempt{}, errs.Internal("failed to encode user answer")
	}

	correctValue := 0
	if item.Correct {
		correctValue = 1
	}

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO practice_attempts (
			id, question_id, user_answer_json, elapsed_seconds, score, correct, feedback, submitted_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.QuestionID,
		string(answerJSON),
		item.ElapsedSeconds,
		item.Score,
		correctValue,
		item.Feedback,
		item.SubmittedAt.Format(time.RFC3339Nano),
	)
	if err != nil {
		return Attempt{}, errs.Internal(fmt.Sprintf("failed to create attempt: %v", err))
	}

	return item, nil
}

func (r *SQLiteRepository) List(ctx context.Context) ([]Attempt, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, question_id, user_answer_json, elapsed_seconds, score, correct, feedback, submitted_at
		FROM practice_attempts
		ORDER BY submitted_at DESC
	`)
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list attempts: %v", err))
	}
	defer rows.Close()

	result := make([]Attempt, 0)
	for rows.Next() {
		item, scanErr := scanAttempt(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan attempt: %v", scanErr))
		}
		result = append(result, item)
	}

	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate attempts: %v", err))
	}

	return result, nil
}

func (r *SQLiteRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM practice_attempts WHERE id = ?`, id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete attempt: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("practice attempt not found")
	}
	return nil
}

type attemptScanner interface {
	Scan(dest ...any) error
}

func scanAttempt(s attemptScanner) (Attempt, error) {
	var (
		item         Attempt
		answerRaw    string
		correctValue int
		timeRaw      string
	)

	if err := s.Scan(
		&item.ID,
		&item.QuestionID,
		&answerRaw,
		&item.ElapsedSeconds,
		&item.Score,
		&correctValue,
		&item.Feedback,
		&timeRaw,
	); err != nil {
		return Attempt{}, err
	}

	if err := json.Unmarshal([]byte(answerRaw), &item.UserAnswer); err != nil {
		return Attempt{}, err
	}
	submittedAt, err := time.Parse(time.RFC3339Nano, timeRaw)
	if err != nil {
		return Attempt{}, err
	}

	item.SubmittedAt = submittedAt
	item.Correct = correctValue == 1
	return item, nil
}
