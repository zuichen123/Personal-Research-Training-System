package agent

import (
	"context"
	"database/sql"
	"fmt"
)

type Service struct {
	repo         *Repository
	db           *sql.DB
	orchestrator *Orchestrator
}

func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
		db:   db,
	}
}

func (s *Service) SetOrchestrator(orchestrator *Orchestrator) {
	s.orchestrator = orchestrator
}

func (s *Service) CreateAgent(ctx context.Context, userID int64, agentType, subject, name string, promptTemplateID int64) (*Agent, error) {
	agent := &Agent{
		UserID:           userID,
		Type:             agentType,
		Subject:          subject,
		Name:             name,
		PromptTemplateID: promptTemplateID,
	}
	if err := s.repo.Create(ctx, agent); err != nil {
		return nil, err
	}
	return agent, nil
}

func (s *Service) GetAgent(ctx context.Context, userID int64, agentType string) (*Agent, error) {
	return s.repo.GetByUserAndType(ctx, userID, agentType)
}

func (s *Service) DispatchTask(ctx context.Context, agentID int64, task string) error {
	return s.repo.SaveChat(ctx, &ChatMessage{
		AgentID: agentID,
		Role:    "system",
		Content: fmt.Sprintf("Task: %s", task),
	})
}

func (s *Service) GetChatHistory(ctx context.Context, agentID int64, limit int) ([]ChatMessage, error) {
	if limit <= 0 {
		limit = 50
	}
	return s.repo.GetChatHistory(ctx, agentID, limit)
}

func (s *Service) CreateHeadTeacher(ctx context.Context, userID int64) (*Agent, error) {
	if s.orchestrator == nil {
		return nil, fmt.Errorf("orchestrator not initialized")
	}
	return s.orchestrator.CreateHeadTeacher(ctx, userID)
}

func (s *Service) CreateSubjectAgent(ctx context.Context, userID int64, subject string) (*Agent, error) {
	if s.orchestrator == nil {
		return nil, fmt.Errorf("orchestrator not initialized")
	}
	return s.orchestrator.CreateSubjectAgent(ctx, userID, subject)
}

func (s *Service) BindScheduleToAgent(ctx context.Context, agentID, scheduleID int64) error {
	if s.orchestrator == nil {
		return fmt.Errorf("orchestrator not initialized")
	}
	return s.orchestrator.BindSchedule(ctx, agentID, scheduleID)
}

func (s *Service) ListAgents(ctx context.Context, userID int64) ([]Agent, error) {
	return s.repo.ListByUser(ctx, userID)
}
