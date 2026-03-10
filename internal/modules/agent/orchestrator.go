package agent

import (
	"context"
	"database/sql"
	"fmt"
)

type Orchestrator struct {
	repo            *Repository
	db              *sql.DB
	promptTemplates PromptTemplateProvider
}

type PromptTemplateProvider interface {
	GetTemplateForSubject(ctx context.Context, subject string) (int64, error)
}

func NewOrchestrator(db *sql.DB, promptProvider PromptTemplateProvider) *Orchestrator {
	return &Orchestrator{
		repo:            NewRepository(db),
		db:              db,
		promptTemplates: promptProvider,
	}
}

func (o *Orchestrator) CreateHeadTeacher(ctx context.Context, userID int64) (*Agent, error) {
	agent := &Agent{
		UserID:  userID,
		Type:    "head_teacher",
		Name:    "班主任",
		Context: GetHeadTeacherPrompt(),
	}
	if err := o.repo.Create(ctx, agent); err != nil {
		return nil, err
	}
	return agent, nil
}

func (o *Orchestrator) CreateSubjectAgent(ctx context.Context, userID int64, subject string) (*Agent, error) {
	templateID, err := o.promptTemplates.GetTemplateForSubject(ctx, subject)
	if err != nil {
		templateID = 0
	}

	prompt := GetSubjectTeacherPrompt(
		subject,
		"学生",
		"待评估",
		"提升成绩，掌握知识",
		"待分析",
		"待发现",
		"综合型",
		fmt.Sprintf("系统讲解%s知识，培养学科思维，提升应试能力", subject),
		"严谨专业，深入浅出，注重方法指导",
		"高考",
		"30-45",
		"亲切耐心",
	)

	agent := &Agent{
		UserID:           userID,
		Type:             "subject_teacher",
		Subject:          subject,
		Name:             fmt.Sprintf("%s教师", subject),
		PromptTemplateID: templateID,
		Context:          prompt,
	}
	if err := o.repo.Create(ctx, agent); err != nil {
		return nil, err
	}
	return agent, nil
}

func (o *Orchestrator) BindSchedule(ctx context.Context, agentID, scheduleID int64) error {
	query := `UPDATE agents SET context = context || ' [绑定课程表:' || ? || ']' WHERE id = ?`
	_, err := o.db.ExecContext(ctx, query, scheduleID, agentID)
	return err
}

func (o *Orchestrator) DispatchScheduledTask(ctx context.Context, agentID int64, task, dueDate string) error {
	return o.repo.SaveChat(ctx, &ChatMessage{
		AgentID: agentID,
		Role:    "system",
		Content: fmt.Sprintf("[定时任务] %s (截止: %s)", task, dueDate),
	})
}
