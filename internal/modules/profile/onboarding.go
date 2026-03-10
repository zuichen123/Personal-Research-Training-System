package profile

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
)

type OnboardingService struct {
	db *sql.DB
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

func NewOnboardingService(db *sql.DB) *OnboardingService {
	return &OnboardingService{db: db}
}

func (s *OnboardingService) GetNextQuestion(ctx context.Context, userID int64, step int) (*OnboardingQuestion, error) {
	questions := []string{
		"你好！我是你的AI学习助手班主任。为了给你提供最优质的个性化教学服务，我需要详细了解你的情况。首先，请问你叫什么名字？",
		"很高兴认识你！你今年多大了？目前在读几年级？",
		"你目前的教育阶段是？（初一/初二/初三/高一/高二/高三/大学/其他）",
		"你的学习目标是什么？请详细描述（例如：准备2026年高考，目标985院校；提升数学成绩从80分到120分；学习编程准备竞赛等）",
		"你想重点学习哪些科目？请列出所有需要学习的科目，并标注优先级（1-最重要，2-重要，3-一般）",
		"针对每个科目，请详细评估你当前的水平：\n- 数学：基础/中等/良好/优秀，当前分数范围\n- 语文：基础/中等/良好/优秀，当前分数范围\n- 英语：基础/中等/良好/优秀，当前分数范围\n（其他科目同样格式）",
		"在你列出的科目中，哪些是你的强项？请具体说明你在这些科目上的优势（例如：数学逻辑思维强，几何题型擅长；英语阅读理解好，词汇量大等）",
		"哪些科目或知识点是你的薄弱环节？请详细说明具体的困难（例如：物理电学部分理解困难，公式记不住；英语语法时态总是混淆；数学立体几何空间想象力弱等）",
		"你的学习风格是什么？请选择并说明：\n1. 视觉型（喜欢看图表、视频、思维导图）\n2. 听觉型（喜欢听讲解、讨论、录音）\n3. 阅读型（喜欢看文字、做笔记、总结）\n4. 动手型（喜欢做练习、实验、实践）\n可以多选，并说明每种方式的占比",
		"你每天可以用于学习的时间是多少？请详细说明：\n- 工作日：几点到几点有空？总共几小时？\n- 周末：几点到几点有空？总共几小时？\n- 你在什么时间段学习效率最高？（早晨/上午/下午/晚上/深夜）\n- 你在什么时间段容易疲劳或注意力不集中？",
		"你的学习习惯如何？请回答：\n- 你习惯一次学习多长时间？（25分钟/45分钟/1小时/2小时以上）\n- 你需要休息多久？（5分钟/10分钟/15分钟/更长）\n- 你喜欢连续学习同一科目，还是交替学习不同科目？\n- 你做题时喜欢先思考再动笔，还是边做边想？",
		"你对学习难度的偏好是什么？\n- 你更喜欢循序渐进、稳扎稳打的学习方式？\n- 还是愿意接受有挑战性的内容，快速提升？\n- 遇到难题时，你倾向于独立思考解决，还是希望及时获得提示？\n- 你能接受的错误率是多少？（希望90%正确率/70%正确率/50%正确率都能接受）",
		"你之前的学习经历如何？\n- 你参加过哪些课外辅导或培训？效果如何？\n- 你使用过哪些学习工具或APP？体验如何？\n- 你有哪些成功的学习经验可以分享？\n- 你在学习中遇到过哪些主要困难？",
		"你的考试情况如何？\n- 最近一次大考（期中/期末/模拟考）的各科成绩是多少？\n- 你在考试中通常遇到什么问题？（时间不够/粗心大意/知识点不熟/题型不熟悉/心理紧张等）\n- 你的目标分数是多少？距离目标还差多少分？",
		"关于作业和练习：\n- 你每天完成学校作业需要多长时间？\n- 你做作业时的正确率大概是多少？\n- 你更喜欢什么类型的练习？（基础巩固题/综合应用题/拔高难题/真题模拟）\n- 你希望每天额外练习多少道题？",
		"你的学习动力和自律性如何？\n- 你学习的主要动力是什么？（兴趣/目标/压力/其他）\n- 你能否坚持每天按计划学习？\n- 你需要什么样的监督和提醒？（每日提醒/每周总结/阶段性测试/其他）\n- 你希望获得什么样的激励？（进步反馈/成就系统/排名对比/其他）",
		"关于错题和复习：\n- 你有整理错题的习惯吗？如何整理？\n- 你多久复习一次学过的内容？\n- 你觉得自己在哪些方面需要重点复习？\n- 你希望系统如何帮你管理错题和复习计划？",
		"你对AI教师的期望是什么？\n- 你希望AI教师扮演什么角色？（严格的老师/耐心的导师/学习伙伴/其他）\n- 你希望AI教师的讲解风格是什么？（详细深入/简明扼要/生动有趣/严谨专业）\n- 你希望AI教师如何给你反馈？（直接指出错误/引导思考/鼓励为主/严格要求）\n- 你还有什么特殊需求或期望？",
		"最后，请分享一些个人信息帮助我更好地服务你：\n- 你的性格特点是什么？（外向/内向/急性子/慢性子等）\n- 你有什么兴趣爱好？\n- 你的家庭对你的学习有什么期望？\n- 你对未来有什么规划？（理想大学/专业方向/职业目标等）\n- 还有什么想告诉我的吗？",
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

	_, err = s.db.ExecContext(ctx, query, userID, state.CurrentStep, string(responsesJSON), state.Completed)
	return err
}

func (s *OnboardingService) GetState(ctx context.Context, userID int64) (*OnboardingState, error) {
	query := `SELECT user_id, current_step, responses, completed FROM onboarding_state WHERE user_id = ?`

	var state OnboardingState
	var responsesJSON string

	err := s.db.QueryRowContext(ctx, query, userID).Scan(
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
	tx, err := s.db.BeginTx(ctx, nil)
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
