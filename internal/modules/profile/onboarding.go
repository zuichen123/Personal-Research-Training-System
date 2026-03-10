package profile

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
)

type OnboardingService struct {
	repo *Repository
}

type OnboardingQuestion struct {
	Question string `json:"question"`
	Step     int    `json:"step"`
	IsFinal  bool   `json:"is_final"`
}

type OnboardingState struct {
	UserID      int64             `json:"user_id"`
	CurrentStep int               `json:"current_step"`
	Responses   map[string]string `json:"responses"`
	Completed   bool              `json:"completed"`
}

func NewOnboardingService(repo *Repository) *OnboardingService {
	return &OnboardingService{repo: repo}
}

func (s *OnboardingService) GetNextQuestion(ctx context.Context, userID int64, step int) (*OnboardingQuestion, error) {
	questions := []string{
		"你好！我是你的学习助手。首先，我想了解一下你的基本情况。请问你叫什么名字？",
		"很高兴认识你！你今年多大了？",
		"你目前的教育水平是什么？（初中/高中/大学）",
		"你想学习哪些科目？可以告诉我你最关注的3-5个科目。",
		"你的学习目标是什么？比如准备高考、提升某科成绩、或者学习新知识？",
		"在这些科目中，你觉得自己哪些方面比较擅长？",
		"有哪些方面你觉得需要加强或者学习起来比较困难？",
		"你更喜欢哪种学习方式？视觉型（看图表、视频）、听觉型（听讲解）、还是动手型（做练习）？",
		"你每天有多少时间可以用来学习？通常在什么时间段学习效果最好？",
		"最后一个问题：你更喜欢循序渐进的学习，还是愿意接受有挑战性的内容？",
	}

	if step < 0 || step >= len(questions) {
		return nil, fmt.Errorf("invalid step: %d", step)
	}

	return &OnboardingQuestion{
		Question: questions[step],
		Step:     step,
		IsFinal:  step == len(questions)-1,
	}, nil
}

func (s *OnboardingService) SaveResponse(ctx context.Context, userID int64, step int, response string) error {
	state, err := s.GetState(ctx, userID)
	if err != nil && err != sql.ErrNoRows {
		return err
	}

	if state == nil {
		state = &OnboardingState{
			UserID:      userID,
			CurrentStep: 0,
			Responses:   make(map[string]string),
			Completed:   false,
		}
	}

	state.Responses[fmt.Sprintf("step_%d", step)] = response
	state.CurrentStep = step + 1

	responsesJSON, err := json.Marshal(state.Responses)
	if err != nil {
		return err
	}

	query := `INSERT INTO onboarding_state (user_id, current_step, responses, completed)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(user_id) DO UPDATE SET
			current_step = excluded.current_step,
			responses = excluded.responses,
			updated_at = CURRENT_TIMESTAMP`

	_, err = s.repo.db.ExecContext(ctx, query, userID, state.CurrentStep, string(responsesJSON), state.Completed)
	return err
}

func (s *OnboardingService) GetState(ctx context.Context, userID int64) (*OnboardingState, error) {
	query := `SELECT user_id, current_step, responses, completed FROM onboarding_state WHERE user_id = ?`

	var state OnboardingState
	var responsesJSON string

	err := s.repo.db.QueryRowContext(ctx, query, userID).Scan(
		&state.UserID,
		&state.CurrentStep,
		&responsesJSON,
		&state.Completed,
	)

	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal([]byte(responsesJSON), &state.Responses); err != nil {
		return nil, err
	}

	return &state, nil
}

func (s *OnboardingService) CompleteOnboarding(ctx context.Context, userID int64) error {
	tx, err := s.repo.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	query := `UPDATE onboarding_state SET completed = 1, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?`
	if _, err := tx.ExecContext(ctx, query, userID); err != nil {
		return err
	}

	profileQuery := `UPDATE user_profiles SET onboarding_completed = 1 WHERE id = ?`
	if _, err := tx.ExecContext(ctx, profileQuery, userID); err != nil {
		return err
	}

	return tx.Commit()
}
