package schedule

import (
	"context"
	"fmt"
	"time"
)

type Service struct {
	repo      *Repository
	aiService AIService
}

type AIService interface {
	GenerateSchedule(ctx context.Context, userProfile map[string]interface{}) ([]Schedule, error)
}

func NewService(repo *Repository, aiService AIService) *Service {
	return &Service{
		repo:      repo,
		aiService: aiService,
	}
}

func (s *Service) GenerateSchedule(ctx context.Context, userID int64, userProfile map[string]interface{}) error {
	schedules, err := s.aiService.GenerateSchedule(ctx, userProfile)
	if err != nil {
		return err
	}

	for i := range schedules {
		schedules[i].UserID = userID
		if err := s.repo.Create(ctx, &schedules[i]); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) GetDailySchedule(ctx context.Context, userID int64, date string) ([]Schedule, error) {
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	return s.repo.GetDailySchedule(ctx, userID, date)
}

func (s *Service) RequestAdjustment(ctx context.Context, scheduleID int64, reason string) error {
	// Simplified: just mark as pending adjustment
	return s.repo.UpdateStatus(ctx, scheduleID, "pending_adjustment")
}

type mockAIService struct{}

func (m *mockAIService) GenerateSchedule(ctx context.Context, userProfile map[string]interface{}) ([]Schedule, error) {
	// Minimal mock implementation
	subjects := []string{"数学", "英语", "物理"}
	var schedules []Schedule

	startDate := time.Now()
	for i := 0; i < 7; i++ {
		date := startDate.AddDate(0, 0, i).Format("2006-01-02")
		for j, subject := range subjects {
			schedules = append(schedules, Schedule{
				Date:            date,
				Subject:         subject,
				Topic:           fmt.Sprintf("%s基础知识", subject),
				DurationMinutes: 60,
				StartTime:       fmt.Sprintf("%02d:00", 19+j),
				Status:          "pending",
			})
		}
	}
	return schedules, nil
}

func NewMockAIService() AIService {
	return &mockAIService{}
}
