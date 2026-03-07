package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"self-study-tool/internal/modules/plan"
	"self-study-tool/internal/shared/errs"
)

const courseScheduleContentMarker = "[course_schedule]"

type courseSchedulePayload struct {
	Date      string `json:"date"`
	Period    int    `json:"period"`
	Subject   string `json:"subject"`
	Topic     string `json:"topic"`
	Classroom string `json:"classroom,omitempty"`
	StartTime string `json:"start_time,omitempty"`
	EndTime   string `json:"end_time,omitempty"`
	Notes     string `json:"notes,omitempty"`
}

func (s *Service) CreateCourseScheduleLesson(
	ctx context.Context,
	req CourseScheduleLessonRequest,
) (CourseScheduleLesson, error) {
	if s.planService == nil {
		return CourseScheduleLesson{}, errs.BadRequest("course schedule is not enabled")
	}
	date := strings.TrimSpace(req.Date)
	subject := strings.TrimSpace(req.Subject)
	topic := strings.TrimSpace(req.Topic)
	if date == "" {
		return CourseScheduleLesson{}, errs.BadRequest("date is required")
	}
	if subject == "" {
		return CourseScheduleLesson{}, errs.BadRequest("subject is required")
	}
	if topic == "" {
		return CourseScheduleLesson{}, errs.BadRequest("topic is required")
	}

	period := req.Period
	if period <= 0 {
		period = 1
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = fmt.Sprintf("课程表：%s 第%d节", subject, period)
	}
	status := strings.TrimSpace(req.Status)
	if status == "" {
		status = string(plan.StatusPending)
	}
	priority := req.Priority
	if priority <= 0 {
		priority = 3
	}
	payload := courseSchedulePayload{
		Date:      date,
		Period:    period,
		Subject:   subject,
		Topic:     topic,
		Classroom: strings.TrimSpace(req.Classroom),
		StartTime: strings.TrimSpace(req.StartTime),
		EndTime:   strings.TrimSpace(req.EndTime),
		Notes:     strings.TrimSpace(req.Notes),
	}
	content, err := encodeCourseScheduleContent(payload)
	if err != nil {
		return CourseScheduleLesson{}, errs.Internal(fmt.Sprintf("encode course schedule payload: %v", err))
	}

	item, err := s.planService.Create(ctx, plan.CreateInput{
		PlanType:   plan.DayPlan,
		Title:      title,
		Content:    content,
		TargetDate: date,
		Status:     status,
		Priority:   priority,
		Source:     plan.SourceAIAgent,
	})
	if err != nil {
		return CourseScheduleLesson{}, err
	}
	return mapCourseScheduleLesson(item), nil
}

func (s *Service) ListCourseScheduleLessons(
	ctx context.Context,
	targetDate string,
) ([]CourseScheduleLesson, error) {
	return s.ListCourseScheduleLessonsWithQuery(ctx, CourseScheduleLessonListQuery{
		Date: targetDate,
	})
}

func (s *Service) ListCourseScheduleLessonsWithQuery(
	ctx context.Context,
	query CourseScheduleLessonListQuery,
) ([]CourseScheduleLesson, error) {
	if s.planService == nil {
		return nil, errs.BadRequest("course schedule is not enabled")
	}
	date := strings.TrimSpace(query.Date)
	dateFrom := strings.TrimSpace(query.DateFrom)
	dateTo := strings.TrimSpace(query.DateTo)
	subject := strings.ToLower(strings.TrimSpace(query.Subject))
	topic := strings.ToLower(strings.TrimSpace(query.Topic))
	granularity := strings.ToLower(strings.TrimSpace(query.Granularity))
	if date != "" && (dateFrom == "" && dateTo == "") {
		switch granularity {
		case "week":
			if parsed, ok := parseDateOnly(date); ok {
				weekdayOffset := int(parsed.Weekday()) - int(time.Monday)
				if weekdayOffset < 0 {
					weekdayOffset += 7
				}
				start := parsed.AddDate(0, 0, -weekdayOffset)
				end := start.AddDate(0, 0, 6)
				dateFrom = formatDateOnly(start)
				dateTo = formatDateOnly(end)
			}
		case "month":
			if parsed, ok := parseDateOnly(date); ok {
				start := time.Date(parsed.Year(), parsed.Month(), 1, 0, 0, 0, 0, time.UTC)
				end := start.AddDate(0, 1, -1)
				dateFrom = formatDateOnly(start)
				dateTo = formatDateOnly(end)
			}
		default:
			dateFrom = date
			dateTo = date
		}
	}
	items, err := s.planService.List(ctx, string(plan.DayPlan))
	if err != nil {
		return nil, err
	}
	out := make([]CourseScheduleLesson, 0, len(items))
	for _, item := range items {
		if !isCourseSchedulePlan(item) {
			continue
		}
		lesson := mapCourseScheduleLesson(item)
		if dateFrom != "" && lesson.Date < dateFrom {
			continue
		}
		if dateTo != "" && lesson.Date > dateTo {
			continue
		}
		if subject != "" {
			candidate := strings.ToLower(strings.TrimSpace(lesson.Subject))
			if !strings.Contains(candidate, subject) {
				continue
			}
		}
		if topic != "" {
			candidate := strings.ToLower(strings.TrimSpace(lesson.Topic))
			if !strings.Contains(candidate, topic) {
				continue
			}
		}
		out = append(out, lesson)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Date == out[j].Date {
			if out[i].Period == out[j].Period {
				return out[i].CreatedAt.Before(out[j].CreatedAt)
			}
			return out[i].Period < out[j].Period
		}
		return out[i].Date < out[j].Date
	})
	return out, nil
}

func parseDateOnly(raw string) (time.Time, bool) {
	parsed, err := time.Parse("2006-01-02", strings.TrimSpace(raw))
	if err != nil {
		return time.Time{}, false
	}
	return parsed, true
}

func formatDateOnly(date time.Time) string {
	return date.Format("2006-01-02")
}

func (s *Service) UpdateCourseScheduleLesson(
	ctx context.Context,
	id string,
	req CourseScheduleLessonUpdateRequest,
) (CourseScheduleLesson, error) {
	if s.planService == nil {
		return CourseScheduleLesson{}, errs.BadRequest("course schedule is not enabled")
	}
	item, err := s.planService.GetByID(ctx, strings.TrimSpace(id))
	if err != nil {
		return CourseScheduleLesson{}, err
	}
	if !isCourseSchedulePlan(item) {
		return CourseScheduleLesson{}, errs.BadRequest("target plan is not a course schedule item")
	}
	current := mapCourseScheduleLesson(item)

	next := current
	if text := strings.TrimSpace(req.Title); text != "" {
		next.Title = text
	}
	if text := strings.TrimSpace(req.Date); text != "" {
		next.Date = text
	}
	if req.Period > 0 {
		next.Period = req.Period
	}
	if text := strings.TrimSpace(req.Subject); text != "" {
		next.Subject = text
	}
	if text := strings.TrimSpace(req.Topic); text != "" {
		next.Topic = text
	}
	if text := strings.TrimSpace(req.Classroom); text != "" {
		next.Classroom = text
	}
	if text := strings.TrimSpace(req.StartTime); text != "" {
		next.StartTime = text
	}
	if text := strings.TrimSpace(req.EndTime); text != "" {
		next.EndTime = text
	}
	if text := strings.TrimSpace(req.Status); text != "" {
		next.Status = text
	}
	if req.Priority > 0 {
		next.Priority = req.Priority
	}
	if text := strings.TrimSpace(req.Notes); text != "" {
		next.Notes = text
	}

	if strings.TrimSpace(next.Title) == "" {
		next.Title = fmt.Sprintf("课程表：%s 第%d节", next.Subject, next.Period)
	}
	payload := courseSchedulePayload{
		Date:      next.Date,
		Period:    next.Period,
		Subject:   next.Subject,
		Topic:     next.Topic,
		Classroom: next.Classroom,
		StartTime: next.StartTime,
		EndTime:   next.EndTime,
		Notes:     next.Notes,
	}
	content, err := encodeCourseScheduleContent(payload)
	if err != nil {
		return CourseScheduleLesson{}, errs.Internal(fmt.Sprintf("encode course schedule payload: %v", err))
	}
	updated, err := s.planService.Update(ctx, item.ID, plan.UpdateInput{
		PlanType:   item.PlanType,
		Title:      next.Title,
		Content:    content,
		TargetDate: next.Date,
		Status:     next.Status,
		Priority:   next.Priority,
		Source:     item.Source,
	})
	if err != nil {
		return CourseScheduleLesson{}, err
	}
	return mapCourseScheduleLesson(updated), nil
}

func (s *Service) DeleteCourseScheduleLesson(ctx context.Context, id string) error {
	if s.planService == nil {
		return errs.BadRequest("course schedule is not enabled")
	}
	item, err := s.planService.GetByID(ctx, strings.TrimSpace(id))
	if err != nil {
		return err
	}
	if !isCourseSchedulePlan(item) {
		return errs.BadRequest("target plan is not a course schedule item")
	}
	return s.planService.Delete(ctx, item.ID)
}

func isCourseSchedulePlan(item plan.Item) bool {
	if item.Source != plan.SourceAIAgent {
		return false
	}
	content := strings.TrimSpace(item.Content)
	return strings.HasPrefix(content, courseScheduleContentMarker)
}

func mapCourseScheduleLesson(item plan.Item) CourseScheduleLesson {
	payload := courseSchedulePayload{
		Date: item.TargetDate,
	}
	if parsed, ok := decodeCourseScheduleContent(item.Content); ok {
		payload = parsed
	}
	date := strings.TrimSpace(payload.Date)
	if date == "" {
		date = strings.TrimSpace(item.TargetDate)
	}
	return CourseScheduleLesson{
		ID:        item.ID,
		Title:     item.Title,
		Date:      date,
		Period:    payload.Period,
		Subject:   payload.Subject,
		Topic:     payload.Topic,
		Classroom: payload.Classroom,
		StartTime: payload.StartTime,
		EndTime:   payload.EndTime,
		Status:    item.Status,
		Priority:  item.Priority,
		Notes:     payload.Notes,
		CreatedAt: item.CreatedAt,
		UpdatedAt: item.UpdatedAt,
	}
}

func encodeCourseScheduleContent(payload courseSchedulePayload) (string, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return courseScheduleContentMarker + "\n" + string(body), nil
}

func decodeCourseScheduleContent(content string) (courseSchedulePayload, bool) {
	trimmed := strings.TrimSpace(content)
	if !strings.HasPrefix(trimmed, courseScheduleContentMarker) {
		return courseSchedulePayload{}, false
	}
	lines := strings.SplitN(trimmed, "\n", 2)
	if len(lines) < 2 {
		return courseSchedulePayload{}, false
	}
	rawJSON := strings.TrimSpace(lines[1])
	if rawJSON == "" {
		return courseSchedulePayload{}, false
	}
	var payload courseSchedulePayload
	if err := json.Unmarshal([]byte(rawJSON), &payload); err != nil {
		return courseSchedulePayload{}, false
	}
	return payload, true
}
