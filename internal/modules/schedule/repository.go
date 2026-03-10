package schedule

import (
	"context"
	"database/sql"
	"time"
)

type Repository struct {
	db *sql.DB
}

type Schedule struct {
	ID              int64     `json:"id"`
	UserID          int64     `json:"user_id"`
	Date            string    `json:"date"`
	Subject         string    `json:"subject"`
	Topic           string    `json:"topic"`
	DurationMinutes int       `json:"duration_minutes"`
	StartTime       string    `json:"start_time"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"created_at"`
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(ctx context.Context, s *Schedule) error {
	query := `INSERT INTO schedules (user_id, date, subject, topic, duration_minutes, start_time, status)
		VALUES (?, ?, ?, ?, ?, ?, ?)`
	result, err := r.db.ExecContext(ctx, query, s.UserID, s.Date, s.Subject, s.Topic, s.DurationMinutes, s.StartTime, s.Status)
	if err != nil {
		return err
	}
	s.ID, _ = result.LastInsertId()
	return nil
}

func (r *Repository) GetDailySchedule(ctx context.Context, userID int64, date string) ([]Schedule, error) {
	query := `SELECT id, user_id, date, subject, topic, duration_minutes, start_time, status, created_at
		FROM schedules WHERE user_id = ? AND date = ? ORDER BY start_time`

	rows, err := r.db.QueryContext(ctx, query, userID, date)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var schedules []Schedule
	for rows.Next() {
		var s Schedule
		if err := rows.Scan(&s.ID, &s.UserID, &s.Date, &s.Subject, &s.Topic, &s.DurationMinutes, &s.StartTime, &s.Status, &s.CreatedAt); err != nil {
			return nil, err
		}
		schedules = append(schedules, s)
	}
	return schedules, nil
}

func (r *Repository) UpdateStatus(ctx context.Context, id int64, status string) error {
	query := `UPDATE schedules SET status = ? WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, status, id)
	return err
}

func (r *Repository) GetByID(ctx context.Context, id int64) (*Schedule, error) {
	query := `SELECT id, user_id, date, subject, topic, duration_minutes, start_time, status, created_at
		FROM schedules WHERE id = ?`
	var s Schedule
	err := r.db.QueryRowContext(ctx, query, id).Scan(&s.ID, &s.UserID, &s.Date, &s.Subject, &s.Topic, &s.DurationMinutes, &s.StartTime, &s.Status, &s.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *Repository) Update(ctx context.Context, s *Schedule) error {
	query := `UPDATE schedules SET date = ?, subject = ?, topic = ?, duration_minutes = ?, start_time = ?, status = ? WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, s.Date, s.Subject, s.Topic, s.DurationMinutes, s.StartTime, s.Status, s.ID)
	return err
}

func (r *Repository) Delete(ctx context.Context, id int64) error {
	query := `DELETE FROM schedules WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}
