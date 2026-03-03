package profile

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

func (r *SQLiteRepository) GetByUserID(ctx context.Context, userID string) (UserProfile, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT user_id, nickname, age, academic_status, goals_json, goal_target_date,
		       daily_study_minutes, weak_subjects_json, target_destination, notes, created_at, updated_at
		FROM user_profiles
		WHERE user_id = ?
	`, userID)

	item, err := scanProfile(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return UserProfile{}, errs.NotFound("user profile not found")
		}
		return UserProfile{}, errs.Internal(fmt.Sprintf("failed to get user profile: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) Upsert(ctx context.Context, item UserProfile) (UserProfile, error) {
	goalsJSON, err := json.Marshal(item.Goals)
	if err != nil {
		return UserProfile{}, errs.Internal("failed to encode goals")
	}
	weakSubjectsJSON, err := json.Marshal(item.WeakSubjects)
	if err != nil {
		return UserProfile{}, errs.Internal("failed to encode weak_subjects")
	}

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO user_profiles (
			user_id, nickname, age, academic_status, goals_json, goal_target_date,
			daily_study_minutes, weak_subjects_json, target_destination, notes, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(user_id) DO UPDATE SET
			nickname = excluded.nickname,
			age = excluded.age,
			academic_status = excluded.academic_status,
			goals_json = excluded.goals_json,
			goal_target_date = excluded.goal_target_date,
			daily_study_minutes = excluded.daily_study_minutes,
			weak_subjects_json = excluded.weak_subjects_json,
			target_destination = excluded.target_destination,
			notes = excluded.notes,
			updated_at = excluded.updated_at
	`,
		item.UserID,
		item.Nickname,
		item.Age,
		item.AcademicStatus,
		string(goalsJSON),
		nullableString(item.GoalTargetDate),
		item.DailyStudyMinutes,
		string(weakSubjectsJSON),
		item.TargetDestination,
		item.Notes,
		item.CreatedAt.Format(time.RFC3339Nano),
		item.UpdatedAt.Format(time.RFC3339Nano),
	)
	if err != nil {
		return UserProfile{}, errs.Internal(fmt.Sprintf("failed to upsert user profile: %v", err))
	}
	return item, nil
}

type profileScanner interface {
	Scan(dest ...any) error
}

func scanProfile(s profileScanner) (UserProfile, error) {
	var (
		item            UserProfile
		goalsRaw        string
		weakSubjectsRaw string
		goalTargetDate  sql.NullString
		createdRaw      string
		updatedRaw      string
	)

	if err := s.Scan(
		&item.UserID,
		&item.Nickname,
		&item.Age,
		&item.AcademicStatus,
		&goalsRaw,
		&goalTargetDate,
		&item.DailyStudyMinutes,
		&weakSubjectsRaw,
		&item.TargetDestination,
		&item.Notes,
		&createdRaw,
		&updatedRaw,
	); err != nil {
		return UserProfile{}, err
	}

	if err := json.Unmarshal([]byte(goalsRaw), &item.Goals); err != nil {
		return UserProfile{}, err
	}
	if err := json.Unmarshal([]byte(weakSubjectsRaw), &item.WeakSubjects); err != nil {
		return UserProfile{}, err
	}
	if goalTargetDate.Valid {
		item.GoalTargetDate = goalTargetDate.String
	}

	createdAt, err := time.Parse(time.RFC3339Nano, createdRaw)
	if err != nil {
		return UserProfile{}, err
	}
	updatedAt, err := time.Parse(time.RFC3339Nano, updatedRaw)
	if err != nil {
		return UserProfile{}, err
	}
	item.CreatedAt = createdAt
	item.UpdatedAt = updatedAt
	return item, nil
}

func nullableString(v string) any {
	if v == "" {
		return nil
	}
	return v
}
