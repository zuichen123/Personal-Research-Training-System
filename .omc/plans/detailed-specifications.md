# Detailed Feature Specifications

## 1. Onboarding Conversation Flow

### Question Sequence:
1. "你好！我是你的学习助手。首先，我想了解一下你的基本情况。请问你叫什么名字？" (Name)
2. "很高兴认识你，{name}！你今年多大了？" (Age)
3. "你目前的教育水平是什么？（初中/高中/大学）" (Education level)
4. "你想学习哪些科目？可以告诉我你最关注的3-5个科目。" (Subjects)
5. "你的学习目标是什么？比如准备高考、提升某科成绩、或者学习新知识？" (Goals)
6. "在这些科目中，你觉得自己哪些方面比较擅长？" (Strengths)
7. "有哪些方面你觉得需要加强或者学习起来比较困难？" (Weaknesses)
8. "你更喜欢哪种学习方式？视觉型（看图表、视频）、听觉型（听讲解）、还是动手型（做练习）？" (Learning style)
9. "你每天有多少时间可以用来学习？通常在什么时间段学习效果最好？" (Availability)
10. "最后一个问题：你更喜欢循序渐进的学习，还是愿意接受有挑战性的内容？" (Difficulty tolerance)

### State Management:
- Each answer saved immediately to `onboarding_state.responses` (JSON)
- User can close app and resume from last step
- Skip button available (marks step as skipped, continues to next)
- Back button to revise previous answer

### Completion:
- After question 10, AI summarizes collected info
- User confirms or edits
- On confirm: set `user_profiles.onboarding_completed = 1`, create head teacher agent

---

## 2. Schedule Generation Algorithm

### Input Data:
```json
{
  "user_profile": {
    "subjects": ["数学", "英语", "物理"],
    "level": "高中",
    "goals": "准备高考",
    "availability": "每天晚上7-10点，周末全天"
  },
  "current_progress": {
    "数学": "已学到函数",
    "英语": "词汇量3000",
    "物理": "力学基础"
  }
}
```

### Algorithm Steps:
1. **Parse availability** → extract time slots (weekday: 19:00-22:00, weekend: 09:00-21:00)
2. **Calculate weekly hours** → weekday 3h × 5 = 15h, weekend 12h × 2 = 24h, total 39h
3. **Allocate by subject priority:**
   - Weak subjects get 40% time
   - Medium subjects get 35% time
   - Strong subjects get 25% time
4. **Generate topic sequence:**
   - Query current progress from database
   - Use AI to determine next topics based on curriculum
   - Ensure prerequisites are met
5. **Distribute across week:**
   - Alternate subjects daily (avoid fatigue)
   - Place difficult subjects in peak hours (user's preferred time)
   - Add review sessions every 3 days for memory-intensive subjects
6. **Output schedule** → 7 days × 2-3 classes/day = 14-21 classes

### AI Prompt Variables:
- `{subjects}`, `{level}`, `{goals}`, `{availability}`, `{current_progress}`, `{weak_areas}`

---

## 3. Difficulty Validation Process

### Initial Rubric Generation:
1. AI generates 10-level rubric using `difficulty_rubric_generator` prompt
2. Each level includes: description, knowledge requirements, example question
3. Stored in `difficulty_rubrics` table

### Question Difficulty Assignment:
1. When teacher agent creates question, it specifies difficulty level (1-10)
2. AI validates: "Does this question match level X criteria?"
3. If mismatch detected, AI adjusts level or regenerates question

### Validation Triggers:
- On question creation (immediate)
- On first student attempt (if score deviates >30% from expected)
- Manual review by admin (future feature)

### Gaokao Alignment:
- Level 1-3: 基础题 (Gaokao Q1-5, 80%+ pass rate)
- Level 4-6: 中档题 (Gaokao Q6-15, 50-70% pass rate)
- Level 7-9: 压轴题 (Gaokao Q16-20, 20-40% pass rate)
- Level 10: 竞赛题 (beyond Gaokao)

---

## 4. Partial Credit Grading

### Scoring Breakdown (Math Example):

**Total Points: 10**
- Final answer correct: 4 points (40%)
- Method/approach correct: 3 points (30%)
- Clear working steps: 2 points (20%)
- Proper notation: 1 point (10%)

### AI Grading Logic:
```
1. Check final answer → if correct, award 4 points
2. If final answer wrong:
   a. Parse student's working steps
   b. Identify where error occurred
   c. Award points for correct steps before error
   d. Deduct points for incorrect steps
3. Check method:
   - Correct formula/theorem used? +3 points
   - Wrong method but valid alternative? +1-2 points
4. Check presentation:
   - Steps clearly shown? +2 points
   - Notation correct (units, symbols)? +1 point
```

### Output:
```json
{
  "score": 7,
  "breakdown": {
    "final_answer": 0,
    "method": 3,
    "working": 2,
    "notation": 1
  },
  "error_point": "第3步：计算导数时符号错误"
}
```

### Subject-Specific Rules:
- **English writing:** Grammar 30%, Vocabulary 25%, Coherence 25%, Task completion 20%
- **Science:** Concepts 40%, Calculations 30%, Procedure 20%, Explanation 10%

---

## 5. Orchestration Trigger Logic

### Monitoring Frequency:
- Background job runs every 1 hour
- Checks all active users

### Trigger Conditions:

**1. Performance Drop (Priority: HIGH)**
```
IF (recent_avg_score - previous_avg_score) < -15%
THEN trigger intervention
ACTION: Suggest focused review, adjust schedule difficulty
```

**2. Low Attendance (Priority: HIGH)**
```
IF attendance_rate < 70% for last 3 days
THEN trigger intervention
ACTION: Send motivational message, ask about obstacles
```

**3. Repeated Mistakes (Priority: MEDIUM)**
```
IF same_mistake_type_count >= 3 in last 7 days
THEN trigger intervention
ACTION: Create targeted practice set, recommend concept review
```

**4. Inactivity (Priority: MEDIUM)**
```
IF days_since_last_activity >= 2
THEN trigger intervention
ACTION: Send reminder, suggest easy warm-up lesson
```

**5. User Request (Priority: HIGH)**
```
IF user sends message to head teacher agent
THEN immediate response
ACTION: Analyze request, provide personalized guidance
```

### Intervention Actions:
- **Schedule adjustment:** Reduce difficulty, add review sessions
- **Content recommendation:** Suggest specific materials from library
- **Practice generation:** Create targeted exercise set
- **Motivational message:** Personalized encouragement
- **Alert user:** Notification in app

### Data Sources:
- `practice_history` → recent scores
- `schedules` → attendance tracking
- `mistakes` → error patterns
- `lesson_sessions` → study time tracking
- `agent_chats` → user requests

---

## Implementation Priority

**Must Have (v1):**
- Onboarding flow (10 questions)
- Schedule generation (basic algorithm)
- Difficulty rubrics (AI-generated)
- Partial credit grading (math, english, science)
- Basic orchestration (performance drop, inactivity)

**Nice to Have (v2):**
- Advanced schedule optimization
- Human review of rubrics
- Multi-language support
- Detailed analytics dashboard
