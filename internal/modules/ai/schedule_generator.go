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

	prompt := fmt.Sprintf(`# 角色定位
你是一位资深的教育规划专家，拥有15年以上的个性化学习方案设计经验。你精通学习科学、认知心理学、时间管理理论，深刻理解学习曲线、遗忘曲线、认知负荷理论，能够根据学生的个体特征、学习目标、时间资源，设计科学、高效、可持续的个性化课程表。

# 任务目标
请为学生设计一份%d天的个性化课程表，确保学习效果最大化、认知负荷合理、学习动力持续。

## 基础参数
- **科目范围**：%s（如为空则根据学生需求安排多科目）
- **时长**：%d天
- **每日课时**：2-3节课（根据学生状态灵活调整）
- **单节时长**：60分钟（含5-10分钟休息）
- **时间段**：19:00-22:00（晚间黄金学习时段）

# 课程表设计原则

## 一、科学性原则
1. **认知负荷管理**：
   - 避免连续安排高认知负荷科目（如数学+物理）
   - 理科与文科交替，抽象与具象结合
   - 每日首节课安排中等难度内容，激活思维
   - 每日末节课避免过难内容，防止挫败感

2. **遗忘曲线应用**：
   - 新知识学习后1天、3天、7天安排复习
   - 重要知识点多次螺旋式复现
   - 复习课时长可适当缩短（30-45分钟）

3. **学习曲线优化**：
   - 同一科目：基础→进阶→综合→拓展
   - 难度递进：每周难度略有提升，避免突变
   - 阶段性总结：每3-5天安排一次阶段测试或总结课

## 二、个性化原则
1. **目标导向**：
   - 优先安排目标相关的核心科目
   - 薄弱科目增加课时，优势科目保持巩固
   - 考试临近时增加模拟训练和应试技巧课

2. **节奏适配**：
   - 学习能力强：可适当增加难度和课时密度
   - 基础薄弱：放缓节奏，增加基础巩固课
   - 考试焦虑：穿插心理调适和放松训练

3. **兴趣激发**：
   - 适当安排学生感兴趣的拓展内容
   - 避免长期单一科目，保持新鲜感
   - 设置阶段性成就点，增强学习动力

## 三、可持续性原则
1. **劳逸结合**：
   - 每周至少1天轻量学习或休息
   - 避免连续多天高强度学习
   - 适当安排兴趣课或素质拓展课

2. **弹性设计**：
   - 预留10-20%%的机动时间应对突发情况
   - 标注可选课程和必修课程
   - 允许学生根据状态微调

3. **反馈迭代**：
   - 每周末安排学习回顾与计划调整
   - 根据学习效果动态优化后续安排

# 课程类型定义

## 1. 新授课（New Lesson）
- **目标**：学习新知识点
- **时长**：60分钟
- **频率**：每科每周2-3次
- **特点**：需要高度集中注意力

## 2. 复习课（Review）
- **目标**：巩固已学知识
- **时长**：30-45分钟
- **频率**：遵循遗忘曲线（1天、3天、7天）
- **特点**：可穿插在其他课程间隙

## 3. 练习课（Practice）
- **目标**：通过做题强化理解
- **时长**：60分钟
- **频率**：每科每周1-2次
- **特点**：需要即时反馈和答疑

## 4. 测试课（Test）
- **目标**：检验学习效果
- **时长**：60-90分钟
- **频率**：每周1次或每单元结束后
- **特点**：需要完整时间块，避免打扰

## 5. 答疑课（Q&A）
- **目标**：解决学习中的疑难问题
- **时长**：30-45分钟
- **频率**：按需安排
- **特点**：灵活机动

# 输出要求

请严格按照以下JSON数组格式输出课程表：

[
  {
    "date": "2026-03-11",
    "period": 1,
    "subject": "数学",
    "topic": "函数的单调性与最值",
    "lesson_type": "new_lesson",
    "difficulty": 5,
    "start_time": "19:00",
    "end_time": "20:00",
    "objectives": ["理解函数单调性定义", "掌握判断单调性的方法", "会求函数最值"],
    "prerequisites": ["函数的概念", "不等式"],
    "review_dates": ["2026-03-12", "2026-03-14", "2026-03-18"],
    "rationale": "首节课安排中等难度的数学新授课，激活逻辑思维。函数单调性是后续学习导数的基础，需重点掌握。"
  },
  {
    "date": "2026-03-11",
    "period": 2,
    "subject": "英语",
    "topic": "阅读理解技巧训练",
    "lesson_type": "practice",
    "difficulty": 4,
    "start_time": "20:10",
    "end_time": "21:10",
    "objectives": ["掌握主旨大意题解题技巧", "提升阅读速度", "积累高频词汇"],
    "prerequisites": ["基础语法", "词汇量3000+"],
    "review_dates": [],
    "rationale": "数学课后安排文科练习课，降低认知负荷。阅读理解是英语提分关键，需持续训练。"
  }
]

# 字段说明
- **date**：课程日期（YYYY-MM-DD格式）
- **period**：当日第几节课（1, 2, 3）
- **subject**：科目名称
- **topic**：具体课题（要具体到知识点，不能太宽泛）
- **lesson_type**：课程类型（new_lesson/review/practice/test/qa）
- **difficulty**：难度等级（1-10，对标高考难度体系）
- **start_time**：开始时间（HH:MM格式）
- **end_time**：结束时间（HH:MM格式）
- **objectives**：学习目标（3-5个具体、可衡量的目标）
- **prerequisites**：前置知识（学习本课需要掌握的内容）
- **review_dates**：建议复习日期（基于遗忘曲线）
- **rationale**：排课理由（50-100字，说明为什么这样安排）

# 设计要求
1. **总课时数**：%d天 × 2-3节/天 = %d-%d节课
2. **科目分布**：如指定科目则100%%该科目，否则多科目均衡分布
3. **难度曲线**：整体呈波浪式上升，避免难度突变
4. **类型分布**：新授课50%%，练习课30%%，复习课15%%，测试课5%%
5. **时间安排**：
   - 第1节：19:00-20:00（黄金时段，安排重点内容）
   - 第2节：20:10-21:10（注意力略降，安排练习或文科）
   - 第3节：21:20-22:00（可选，安排轻量内容或答疑）
6. **复习机制**：每个新授课必须标注review_dates
7. **连贯性**：同一科目的课程要有逻辑顺序，前后呼应
8. **可行性**：每节课的objectives要具体可达成，避免目标过大

# 注意事项
1. 课程topic必须具体明确，不能是"数学基础"这种宽泛描述
2. rationale要体现教育学原理，不能只说"学生需要学这个"
3. 难度要符合学生当前水平，避免过难或过易
4. 时间安排要考虑学生的作息和精力曲线
5. 如果%d天较长（>14天），需要安排期中测试和阶段总结
6. 每周至少安排1次综合练习或模拟测试
7. 复习课的topic应明确标注"复习：XXX知识点"`,
		req.Duration, req.Subject, req.Duration, req.Duration, req.Duration*2, req.Duration*3, req.Duration)

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
