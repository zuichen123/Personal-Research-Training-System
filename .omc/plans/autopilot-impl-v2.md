# Self-Study-Tool Implementation Plan v2

**Date:** 2026-03-11
**Status:** Ready for Execution
**Addresses:** All critical blockers from critic review

**Reference Documents:**
- Architecture Decisions: `.omc/plans/architecture-decisions.md`
- Prompt Templates: `.omc/plans/prompt-templates.md`
- Phase 0 Specifications: `.omc/plans/phase0-specifications.md`
- Detailed Specifications: `.omc/plans/detailed-specifications.md`

**Module Naming Convention:**
- Module: `profile` (not `user_profile`)
- Table: `user_profiles` (plural)
- Package: `package profile`

---

## Phase 0: Prerequisites (4 commits)

### 0.1 Verify Current State
**Files:** `scripts/verify_state.sh`
**Task:** Check migration number, verify module names, confirm table schema
**Acceptance:** Script outputs current state report
**Commit:** `chore: add state verification script`

### 0.2 Web Search Package (DEFERRED to v2)
**Rationale:** Web search is optional for v1. AI can generate exam questions without external validation.
**Future:** Add legal API (Brave Search free tier) in v2 if needed.
**This phase is SKIPPED in v1 implementation.**

### 0.3 Prompt Templates Table
**Files:** `migrations/sqlite/024_create_prompt_templates.sql`
**Schema:**
```sql
CREATE TABLE prompt_templates (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL,
    system_role TEXT NOT NULL,
    task_description TEXT NOT NULL,
    output_format TEXT NOT NULL,
    examples TEXT,
    variables TEXT,
    version INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```
**Acceptance:** Migration runs successfully
**Commit:** `feat: add prompt templates table`

### 0.4 Seed Professional Prompts
**Files:** `migrations/sqlite/025_seed_prompt_templates.sql`
**Source:** Use prompt content from `.omc/plans/prompt-templates.md`
**Task:** Insert 8 core prompts with full content:
1. `onboarding_assistant` - 10-question conversational interview
2. `schedule_generator` - Weekly schedule with Gaokao alignment
3. `math_grader` - Partial credit grading with error identification
4. `english_grader` - Grammar, vocabulary, coherence assessment
5. `science_grader` - Conceptual understanding evaluation
6. `difficulty_rubric_generator` - 10-level Gaokao-aligned rubrics
7. `homework_generator` - Targeted post-lesson exercises
8. `head_teacher_orchestrator` - Progress monitoring and intervention
**Acceptance:** 8 rows inserted, SELECT COUNT(*) returns 8
**Commit:** `feat: seed professional AI prompt templates`

---

## Phase 1: Onboarding & Profile (5 commits)

### 1.1 Onboarding State Table
**Files:** `migrations/sqlite/026_create_onboarding_state.sql`
**Schema:**
```sql
CREATE TABLE onboarding_state (
    user_id INTEGER PRIMARY KEY,
    current_step INTEGER DEFAULT 0,
    responses TEXT,
    completed BOOLEAN DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES user_profiles(id)
);
```
**Commit:** `feat: add onboarding state tracking`

### 1.2 Enhance Profile Table
**Files:** `migrations/sqlite/027_enhance_profile.sql`
**Task:** Add columns: learning_goals TEXT, self_assessment TEXT, availability TEXT, learning_style TEXT, onboarding_completed BOOLEAN
**Commit:** `feat: enhance user profile for personalization`

### 1.3 Onboarding Service (Backend)
**Files:** `internal/modules/profile/onboarding.go`
**Functions:**
- `GetNextQuestion(userID, step) (Question, error)`
- `SaveResponse(userID, step, response) error`
- `CompleteOnboarding(userID) error`
**Acceptance:** Unit tests pass
**Commit:** `feat: add onboarding service with Q&A flow`

### 1.4 Onboarding API
**Files:** `internal/modules/profile/handler.go` (extend)
**Endpoints:**
- `GET /api/profile/onboarding/next` - get next question
- `POST /api/profile/onboarding/answer` - save answer
- `POST /api/profile/onboarding/complete` - finish onboarding
**Commit:** `feat: add onboarding API endpoints`

### 1.5 Onboarding UI (Flutter)
**Files:** `apps/flutter_client/lib/screens/onboarding_screen.dart`
**UI:** Conversational chat interface, progress indicator, skip button
**Flow:** Check onboarding_completed on app start, show screen if false
**Commit:** `feat: add onboarding UI with conversational flow`

---

## Phase 2: Scheduling System (5 commits)

### 2.1 Schedule Tables
**Files:** `migrations/sqlite/028_create_schedules.sql`
**Schema:**
```sql
CREATE TABLE schedules (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    date DATE NOT NULL,
    subject TEXT NOT NULL,
    topic TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    start_time TIME,
    status TEXT DEFAULT 'pending',
    FOREIGN KEY (user_id) REFERENCES user_profiles(id)
);

CREATE TABLE schedule_adjustments (
    id INTEGER PRIMARY KEY,
    schedule_id INTEGER NOT NULL,
    reason TEXT NOT NULL,
    old_date DATE NOT NULL,
    new_date DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);
```
**Commit:** `feat: add schedule and adjustment tables`

### 2.2 Schedule Service
**Files:** `internal/modules/schedule/service.go`, `internal/modules/schedule/repository.go`
**Functions:**
- `GenerateSchedule(userID) error` - AI generates personalized schedule
- `GetDailySchedule(userID, date) ([]Schedule, error)`
- `RequestAdjustment(scheduleID, reason) error` - AI adjusts schedule
**Commit:** `feat: add schedule generation service`

### 2.3 Schedule API
**Files:** `internal/modules/schedule/handler.go`
**Endpoints:**
- `POST /api/schedule/generate` - generate new schedule
- `GET /api/schedule/daily?date=YYYY-MM-DD` - get day view
- `POST /api/schedule/adjust` - request adjustment
**Commit:** `feat: add schedule API endpoints`

### 2.4 Schedule UI - Day View
**Files:** `apps/flutter_client/lib/screens/schedule_day_view.dart`
**UI:** List of today's classes, tap to start lesson, status indicators
**Commit:** `feat: add schedule day view UI`

### 2.5 Schedule Adjustment Dialog
**Files:** `apps/flutter_client/lib/widgets/schedule_adjustment_dialog.dart`
**UI:** Text input for reason, AI processes and updates schedule
**Commit:** `feat: add schedule adjustment dialog`

---

## Phase 3: Teaching Agents (6 commits)

### 3.1 Agents Table
**Files:** `migrations/sqlite/029_create_agents.sql`
**Schema:**
```sql
CREATE TABLE agents (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    subject TEXT,
    name TEXT NOT NULL,
    prompt_template_id INTEGER NOT NULL,
    context TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_profiles(id),
    FOREIGN KEY (prompt_template_id) REFERENCES prompt_templates(id)
);

CREATE TABLE agent_chats (
    id INTEGER PRIMARY KEY,
    agent_id INTEGER NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (agent_id) REFERENCES agents(id)
);
```
**Commit:** `feat: add agents and chat history tables`

### 3.2 Difficulty Rubrics Table
**Files:** `migrations/sqlite/030_create_difficulty_rubrics.sql`
**Schema:**
```sql
CREATE TABLE difficulty_rubrics (
    id INTEGER PRIMARY KEY,
    subject TEXT NOT NULL,
    level INTEGER NOT NULL CHECK(level BETWEEN 1 AND 10),
    description TEXT NOT NULL,
    example_question TEXT,
    gaokao_equivalent TEXT,
    created_by TEXT DEFAULT 'ai',
    UNIQUE(subject, level)
);
```
**Commit:** `feat: add difficulty rubrics table`

### 3.3 Agent Service
**Files:** `internal/modules/agent/service.go`, `internal/modules/agent/repository.go`
**Functions:**
- `CreateHeadTeacher(userID) (Agent, error)`
- `CreateSubjectAgent(userID, subject) (Agent, error)`
- `Chat(agentID, message) (response, error)`
- `GenerateHomework(agentID, lessonID) ([]Question, error)`
**Commit:** `feat: add agent management service`

### 3.4 Lesson Session Table
**Files:** `migrations/sqlite/031_create_lesson_sessions.sql`
**Schema:**
```sql
CREATE TABLE lesson_sessions (
    id INTEGER PRIMARY KEY,
    schedule_id INTEGER NOT NULL,
    agent_id INTEGER NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    duration_seconds INTEGER,
    homework_generated BOOLEAN DEFAULT 0,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id),
    FOREIGN KEY (agent_id) REFERENCES agents(id)
);
```
**Commit:** `feat: add lesson session tracking`

### 3.5 Teaching API
**Files:** `internal/modules/agent/handler.go`
**Endpoints:**
- `POST /api/agent/create` - create subject agent
- `POST /api/agent/chat` - send message to agent
- `POST /api/agent/lesson/start` - start lesson session
- `POST /api/agent/lesson/end` - end session, generate homework
**Commit:** `feat: add teaching agent API`

### 3.6 Teaching UI
**Files:** `apps/flutter_client/lib/screens/lesson_screen.dart`
**UI:** Chat interface with agent, timer, end lesson button
**Flow:** Start from schedule, chat with agent, end generates homework
**Commit:** `feat: add lesson screen with agent chat`

---

## Phase 4: Question Bank Enhancement (4 commits)

### 4.1 Enhance Questions Table
**Files:** `migrations/sqlite/032_enhance_questions.sql`
**Task:** Add columns: difficulty_level INTEGER (1-10), source_agent_id INTEGER, source_lesson_id INTEGER
**Commit:** `feat: enhance questions with difficulty and source tracking`

### 4.2 Question Sorting Service
**Files:** `internal/modules/question/service.go` (extend)
**Functions:**
- `ListQuestions(filters QuestionFilter, sort SortOption) ([]Question, error)`
- `GetQuestionsByDifficulty(subject, level) ([]Question, error)`
**Commit:** `feat: add question sorting and filtering`

### 4.3 Question Bank UI Enhancement
**Files:** `apps/flutter_client/lib/screens/question_bank_screen.dart` (extend)
**UI:** Sort dropdown (difficulty/subject/chapter/score), filter chips
**Commit:** `feat: add sorting and filtering to question bank UI`

### 4.4 Question Source Navigation
**Files:** `apps/flutter_client/lib/widgets/question_card.dart` (extend)
**UI:** If source_lesson_id exists, show "Ask Teacher" button → opens agent chat
**Commit:** `feat: add question source navigation to teaching agent`

---

## Phase 5: Practice Enhancement (5 commits)

### 5.1 Exam Generation Service
**Files:** `internal/modules/practice/exam_generator.go`
**Functions:**
- `GenerateIntelligentExam(userID, subject) ([]Question, error)` - uses AI + web search
- `GenerateUnitExam(userID, subject, unit) ([]Question, error)`
- `ValidateQuestion(question) (bool, error)` - verify correctness
**Commit:** `feat: add intelligent exam generation with validation`

### 5.2 Practice History Enhancement
**Files:** `migrations/sqlite/033_enhance_practice_history.sql`
**Task:** Add columns: my_answer TEXT, is_correct BOOLEAN, score INTEGER, grading_detail TEXT
**Commit:** `feat: enhance practice history with detailed results`

### 5.3 Grading Service
**Files:** `internal/modules/practice/grading.go`
**Functions:**
- `GradeAnswer(questionID, answer) (GradingResult, error)` - subject-specific AI grading
- `GetGradingDetail(practiceID) (GradingDetail, error)`
**Commit:** `feat: add professional AI grading service`

### 5.4 Practice Detail UI
**Files:** `apps/flutter_client/lib/screens/practice_detail_screen.dart` (extend)
**UI:** Show score, correctness, my answer in same card; grading detail expandable
**Commit:** `feat: enhance practice detail UI with inline results`

### 5.5 Practice History Navigation
**Files:** `apps/flutter_client/lib/screens/practice_detail_screen.dart` (extend)
**UI:** "View History" button for same question → list of past attempts → tap to view detail
**Commit:** `feat: add practice history navigation`

---

## Phase 6: Materials Enhancement (3 commits)

### 6.1 Materials Format Support
**Files:** `internal/modules/material/parser.go`
**Functions:**
- `ParsePDF(file) (text, error)`
- `ParseImage(file) (text, error)` - OCR
- `ParseMOBI(file) (text, error)`
**Libraries:** Use existing Go libraries (pdfcpu, tesseract-go, mobi)
**Commit:** `feat: add multi-format material parsing`

### 6.2 Material AI Analysis
**Files:** `internal/modules/material/service.go` (extend)
**Functions:**
- `AnalyzeMaterial(materialID) error` - AI categorizes and tags
- `SearchMaterials(query) ([]Material, error)` - keyword search
**Commit:** `feat: add AI material analysis and search`

### 6.3 Material Query Tool for AI
**Files:** `internal/modules/ai/tools.go` (extend)
**Tool:** `QueryMaterials(subject, keywords) ([]MaterialSnippet, error)` - token-efficient
**Commit:** `feat: add material query tool for AI agents`

---

## Phase 7: Mistake Analysis (3 commits)

### 7.1 Enhance Mistakes Table
**Files:** `migrations/sqlite/034_enhance_mistakes.sql`
**Task:** Add columns: unit TEXT, lesson_id INTEGER, analysis TEXT (AI-generated)
**Commit:** `feat: enhance mistakes with unit and AI analysis`

### 7.2 Mistake Analysis Service
**Files:** `internal/modules/mistake/service.go` (extend)
**Functions:**
- `AnalyzeMistakes(userID, subject) (Analysis, error)` - AI identifies patterns
- `GetMistakesByUnit(userID, subject, unit) ([]Mistake, error)`
- `GetTodayMistakes(userID) ([]Mistake, error)`
**Commit:** `feat: add AI mistake analysis service`

### 7.3 Mistake Book UI Enhancement
**Files:** `apps/flutter_client/lib/screens/mistake_book_screen.dart` (extend)
**UI:** Hierarchical view: Today's Mistakes → Subject → Unit → Questions
**Sort:** Default subject→unit→order, optional time sort
**Commit:** `feat: enhance mistake book UI with hierarchical view`

---

## Phase 8: Head Teacher Orchestration (3 commits)

### 8.1 User Portrait Table
**Files:** `migrations/sqlite/035_create_user_portrait.sql`
**Schema:**
```sql
CREATE TABLE user_portraits (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    category TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    confidence REAL DEFAULT 1.0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_profiles(id),
    UNIQUE(user_id, category, key)
);
```
**Commit:** `feat: add user portrait table for AI profiling`

### 8.2 Orchestration Service
**Files:** `internal/modules/agent/orchestration.go`
**Functions:**
- `UpdatePortrait(userID, category, data) error`
- `MonitorProgress(userID) error` - periodic check
- `TriggerIntervention(userID, reason) error` - AI suggests adjustments
**Commit:** `feat: add head teacher orchestration service`

### 8.3 Orchestration Background Job
**Files:** `cmd/server/main.go` (extend)
**Task:** Start goroutine that runs orchestration every 1 hour
**Commit:** `feat: add orchestration background job`

---

## Total: 38 Commits across 8 Phases

## Acceptance Criteria
- [ ] All migrations run successfully
- [ ] All Go tests pass
- [ ] Flutter app builds without errors
- [ ] Onboarding completes in <5 minutes
- [ ] Schedule generation completes in <10 seconds
- [ ] AI grading returns results in <15 seconds
- [ ] Web search returns results in <5 seconds or fails gracefully
- [ ] No breaking changes to existing features
