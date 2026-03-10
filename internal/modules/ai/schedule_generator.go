package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

type GenerateScheduleRequest struct {
	UserID   int64  `json:"user_id"`
	Subject  string `json:"subject,omitempty"`
	Duration int    `json:"duration"` // days
}

func (s *Service) GenerateSchedule(ctx context.Context, req GenerateScheduleRequest) ([]CourseScheduleLesson, error) {
	if req.Duration <= 0 {
		req.Duration = 7
	}

	prompt := fmt.Sprintf(`根据用户需求生成课程表。要求：
- 科目：%s（如为空则生成多科目）
- 时长：%d天
- 每天安排2-3节课
- 每节课60分钟
- 时间段：19:00-22:00

返回JSON数组格式：
[{"date":"2026-03-11","period":1,"subject":"数学","topic":"基础知识","start_time":"19:00","end_time":"20:00"}]`,
		req.Subject, req.Duration)

	resp, err := s.client.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return nil, err
	}

	var schedules []struct {
		Date      string `json:"date"`
		Period    int    `json:"period"`
		Subject   string `json:"subject"`
		Topic     string `json:"topic"`
		StartTime string `json:"start_time"`
		EndTime   string `json:"end_time"`
	}

	content := strings.TrimSpace(resp.Content)
	if idx := strings.Index(content, "["); idx >= 0 {
		content = content[idx:]
	}
	if idx := strings.LastIndex(content, "]"); idx >= 0 {
		content = content[:idx+1]
	}

	if err := json.Unmarshal([]byte(content), &schedules); err != nil {
		return nil, fmt.Errorf("parse schedule: %w", err)
	}

	var lessons []CourseScheduleLesson
	for _, sch := range schedules {
		lesson, err := s.CreateCourseScheduleLesson(ctx, CourseScheduleLessonRequest{
			Date:      sch.Date,
			Period:    sch.Period,
			Subject:   sch.Subject,
			Topic:     sch.Topic,
			StartTime: sch.StartTime,
			EndTime:   sch.EndTime,
			Status:    "pending",
			Priority:  3,
		})
		if err != nil {
			continue
		}
		lessons = append(lessons, lesson)
	}

	return lessons, nil
}
