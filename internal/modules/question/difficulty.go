package question

import (
	"context"
	"database/sql"
)

type DifficultyService struct {
	db *sql.DB
}

func NewDifficultyService(db *sql.DB) *DifficultyService {
	return &DifficultyService{db: db}
}

func (s *DifficultyService) GetRubric(ctx context.Context, subject string) (*DifficultyRubric, error) {
	query := `SELECT id, subject, level, description, criteria FROM difficulty_rubrics WHERE subject = ? ORDER BY level`
	rows, err := s.db.QueryContext(ctx, query, subject)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	rubric := &DifficultyRubric{Subject: subject, Levels: make([]DifficultyLevel, 0, 10)}
	for rows.Next() {
		var level DifficultyLevel
		if err := rows.Scan(&level.ID, &level.Subject, &level.Level, &level.Description, &level.Criteria); err != nil {
			return nil, err
		}
		rubric.Levels = append(rubric.Levels, level)
	}
	return rubric, nil
}

func (s *DifficultyService) AssessDifficulty(ctx context.Context, questionID int64, subject string) (int, error) {
	// Simplified: return middle difficulty for now
	// In production, this would use AI to assess based on rubric
	return 5, nil
}

type DifficultyRubric struct {
	Subject string
	Levels  []DifficultyLevel
}

type DifficultyLevel struct {
	ID          int64
	Subject     string
	Level       int
	Description string
	Criteria    string
}
