package plan

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

func (r *SQLiteRepository) Create(ctx context.Context, item Item) (Item, error) {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO plans (
			id, plan_type, title, content, target_date, status, priority, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		item.ID,
		string(item.PlanType),
		item.Title,
		item.Content,
		nullableString(item.TargetDate),
		item.Status,
		item.Priority,
		item.CreatedAt.Format(time.RFC3339Nano),
		item.UpdatedAt.Format(time.RFC3339Nano),
	)
	if err != nil {
		return Item{}, errs.Internal(fmt.Sprintf("failed to create plan: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) GetByID(ctx context.Context, id string) (Item, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT id, plan_type, title, content, target_date, status, priority, created_at, updated_at
		FROM plans
		WHERE id = ?
	`, id)

	item, err := scanPlan(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return Item{}, errs.NotFound("plan not found")
		}
		return Item{}, errs.Internal(fmt.Sprintf("failed to get plan: %v", err))
	}
	return item, nil
}

func (r *SQLiteRepository) List(ctx context.Context, planType string) ([]Item, error) {
	baseSQL := `
		SELECT id, plan_type, title, content, target_date, status, priority, created_at, updated_at
		FROM plans
	`

	var (
		rows *sql.Rows
		err  error
	)

	if planType == "" {
		rows, err = r.db.QueryContext(ctx, baseSQL+` ORDER BY updated_at DESC`)
	} else {
		rows, err = r.db.QueryContext(ctx, baseSQL+` WHERE plan_type = ? ORDER BY updated_at DESC`, planType)
	}
	if err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to list plans: %v", err))
	}
	defer rows.Close()

	result := make([]Item, 0)
	for rows.Next() {
		item, scanErr := scanPlan(rows)
		if scanErr != nil {
			return nil, errs.Internal(fmt.Sprintf("failed to scan plan: %v", scanErr))
		}
		result = append(result, item)
	}

	if err := rows.Err(); err != nil {
		return nil, errs.Internal(fmt.Sprintf("failed to iterate plans: %v", err))
	}
	return result, nil
}

func (r *SQLiteRepository) Update(ctx context.Context, item Item) (Item, error) {
	res, err := r.db.ExecContext(ctx, `
		UPDATE plans
		SET plan_type = ?, title = ?, content = ?, target_date = ?, status = ?, priority = ?, updated_at = ?
		WHERE id = ?
	`,
		string(item.PlanType),
		item.Title,
		item.Content,
		nullableString(item.TargetDate),
		item.Status,
		item.Priority,
		item.UpdatedAt.Format(time.RFC3339Nano),
		item.ID,
	)
	if err != nil {
		return Item{}, errs.Internal(fmt.Sprintf("failed to update plan: %v", err))
	}

	affected, _ := res.RowsAffected()
	if affected == 0 {
		return Item{}, errs.NotFound("plan not found")
	}
	return item, nil
}

func (r *SQLiteRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM plans WHERE id = ?`, id)
	if err != nil {
		return errs.Internal(fmt.Sprintf("failed to delete plan: %v", err))
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		return errs.NotFound("plan not found")
	}
	return nil
}

type planScanner interface {
	Scan(dest ...any) error
}

func scanPlan(s planScanner) (Item, error) {
	var (
		item      Item
		typeValue string
		targetRaw sql.NullString
		created   string
		updated   string
	)

	if err := s.Scan(
		&item.ID,
		&typeValue,
		&item.Title,
		&item.Content,
		&targetRaw,
		&item.Status,
		&item.Priority,
		&created,
		&updated,
	); err != nil {
		return Item{}, err
	}

	item.PlanType = PlanType(typeValue)
	if targetRaw.Valid {
		item.TargetDate = targetRaw.String
	}

	createdAt, err := time.Parse(time.RFC3339Nano, created)
	if err != nil {
		return Item{}, err
	}
	updatedAt, err := time.Parse(time.RFC3339Nano, updated)
	if err != nil {
		return Item{}, err
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
