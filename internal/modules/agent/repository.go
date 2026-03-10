package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"
)

type Repository struct {
	db *sql.DB
}

type Agent struct {
	ID                int64     `json:"id"`
	UserID            int64     `json:"user_id"`
	Type              string    `json:"type"`
	Subject           string    `json:"subject"`
	Name              string    `json:"name"`
	PromptTemplateID  int64     `json:"prompt_template_id"`
	Context           string    `json:"context"`
	CreatedAt         time.Time `json:"created_at"`
}

type ChatMessage struct {
	ID        int64     `json:"id"`
	AgentID   int64     `json:"agent_id"`
	Role      string    `json:"role"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(ctx context.Context, agent *Agent) error {
	query := `INSERT INTO agents (user_id, type, subject, name, prompt_template_id, context)
		VALUES (?, ?, ?, ?, ?, ?)`
	result, err := r.db.ExecContext(ctx, query, agent.UserID, agent.Type, agent.Subject, agent.Name, agent.PromptTemplateID, agent.Context)
	if err != nil {
		return err
	}
	agent.ID, _ = result.LastInsertId()
	return nil
}

func (r *Repository) GetByUserAndType(ctx context.Context, userID int64, agentType string) (*Agent, error) {
	query := `SELECT id, user_id, type, subject, name, prompt_template_id, context, created_at
		FROM agents WHERE user_id = ? AND type = ? LIMIT 1`

	var agent Agent
	err := r.db.QueryRowContext(ctx, query, userID, agentType).Scan(
		&agent.ID, &agent.UserID, &agent.Type, &agent.Subject, &agent.Name,
		&agent.PromptTemplateID, &agent.Context, &agent.CreatedAt,
	)
	return &agent, err
}

func (r *Repository) SaveChat(ctx context.Context, msg *ChatMessage) error {
	query := `INSERT INTO agent_chats (agent_id, role, content) VALUES (?, ?, ?)`
	result, err := r.db.ExecContext(ctx, query, msg.AgentID, msg.Role, msg.Content)
	if err != nil {
		return err
	}
	msg.ID, _ = result.LastInsertId()
	return nil
}

func (r *Repository) GetChatHistory(ctx context.Context, agentID int64, limit int) ([]ChatMessage, error) {
	query := `SELECT id, agent_id, role, content, created_at FROM agent_chats
		WHERE agent_id = ? ORDER BY created_at DESC LIMIT ?`

	rows, err := r.db.QueryContext(ctx, query, agentID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []ChatMessage
	for rows.Next() {
		var msg ChatMessage
		if err := rows.Scan(&msg.ID, &msg.AgentID, &msg.Role, &msg.Content, &msg.CreatedAt); err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}
	return messages, nil
}
