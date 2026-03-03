package pomodoro

import (
	"context"
	"database/sql"
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

func (r *SQLiteRepository) Create(ctx context.Context, item Session) (Session, error) {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO pomodoro_sessions (
			id, task_title, plan_id, duration_minutes, break_minutes, status, started_at, ended_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		item.TaskTitle,
		nullableString(item.PlanID),
		item.DurationMinutes,
		item.BreakMinutes,
		string(item.Status),
		item.StartedAt.Format(time.RFC3339Nano),
		nullableTime(item.EndedAt),
	)
	if err != nil {
		return Session{}, errs.Internal(fmt.Sprintf("failed to create pomodoro session: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) GetByID(ctx context.Context, id string) (Session, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT id, task_title, plan_id, duration_minutes, break_minutes, status, started_at, ended_at
		FROM pomodoro_sessions
		WHERE id = ?
	`, id)

	item, err := scanSession(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return Session{}, errs.NotFound("pomodoro session not found")
		}
		return Session{}, errs.Internal(fmt.Sprintf("failed to get pomodoro session: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) List(ctx context.Context, status string) ([]Session, error) {
	baseSQL := `
		SELECT id, task_title, plan_id, duration_minutes, break_minutes, status, started_at, ended_at
		FROM pomodoro_sessions
	`

	var (
		rows *sql.Rows
		err  error
	)

	if status == "" {
		rows, err = r.db.QueryContext(ctx, baseSQL+` ORDER BY started_at DESC`)
	} else {
		rows, err = r.db.QueryContext(ctx, baseSQL+` WHERE status = ? ORDER BY started_at DESC`, status)
	}
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list pomodoro sessions: %v", err))
	}
	defer rows.Close()

	result := make([]Session, 0)
	for rows.Next() {
		item, scanErr := scanSession(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan pomodoro session: %v", scanErr))
		}
		result = append(result, item)
	}

	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate pomodoro sessions: %v", err))
	}
	return result, nil
}

func (r *SQLiteRepository) Update(ctx context.Context, item Session) (Session, error) {
	res, err := r.db.ExecContext(ctx, `
		UPDATE pomodoro_sessions
		SET task_title = ?, plan_id = ?, duration_minutes = ?, break_minutes = ?, status = ?, started_at = ?, ended_at = ?
		WHERE id = ?
	`,
		item.TaskTitle,
		nullableString(item.PlanID),
		item.DurationMinutes,
		item.BreakMinutes,
		string(item.Status),
		item.StartedAt.Format(time.RFC3339Nano),
		nullableTime(item.EndedAt),
		item.ID,
	)
	if err != nil {
		return Session{}, errs.Internal(fmt.Sprintf("failed to update pomodoro session: %v", err))
	}

	affected, _ := res.RowsAffected()
	if affected == 0 {
		return Session{}, errs.NotFound("pomodoro session not found")
	}
	return item, nil
}

func (r *SQLiteRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM pomodoro_sessions WHERE id = ?`, id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete pomodoro session: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("pomodoro session not found")
	}
	return nil
}

type sessionScanner interface {
	Scan(dest ...any) error
}

func scanSession(s sessionScanner) (Session, error) {
	var (
		item       Session
		status     string
		planID     sql.NullString
		startedRaw string
		endedRaw   sql.NullString
	)

	if err := s.Scan(
		&item.ID,
		&item.TaskTitle,
		&planID,
		&item.DurationMinutes,
		&item.BreakMinutes,
		&status,
		&startedRaw,
		&endedRaw,
	); err != nil {
		return Session{}, err
	}

	item.Status = SessionStatus(status)
	if planID.Valid {
		item.PlanID = planID.String
	}

	startedAt, err := time.Parse(time.RFC3339Nano, startedRaw)
	if err != nil {
		return Session{}, err
	}
	item.StartedAt = startedAt

	if endedRaw.Valid {
		endedAt, err := time.Parse(time.RFC3339Nano, endedRaw.String)
		if err != nil {
			return Session{}, err
		}
		item.EndedAt = &endedAt
	}

	return item, nil
}

func nullableString(v string) any {
	if v == "" {
		return nil
	}
	return v
}

func nullableTime(v *time.Time) any {
	if v == nil {
		return nil
	}
	return v.Format(time.RFC3339Nano)
}
