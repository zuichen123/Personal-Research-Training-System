package schedule

import (
	"context"
	"self-study-tool/internal/modules/ai"
)

type AIAdapter struct {
	aiService *ai.Service
}

func NewAIAdapter(aiService *ai.Service) *AIAdapter {
	return &AIAdapter{aiService: aiService}
}

func (a *AIAdapter) GenerateSchedule(ctx context.Context, userProfile map[string]interface{}) ([]Schedule, error) {
	subject, _ := userProfile["subject"].(string)
	duration, _ := userProfile["duration"].(int)
	if duration == 0 {
		duration = 7
	}

	lessons, err := a.aiService.GenerateSchedule(ctx, ai.GenerateScheduleRequest{
		UserID:   userProfile["user_id"].(int64),
		Subject:  subject,
		Duration: duration,
	})
	if err != nil {
		return nil, err
	}

	schedules := make([]Schedule, len(lessons))
	for i, lesson := range lessons {
		schedules[i] = Schedule{
			Date:            lesson.Date,
			Subject:         lesson.Subject,
			Topic:           lesson.Topic,
			DurationMinutes: 60,
			StartTime:       lesson.StartTime,
			Status:          lesson.Status,
		}
	}
	return schedules, nil
}
