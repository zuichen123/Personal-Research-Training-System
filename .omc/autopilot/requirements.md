# Self-Study-Tool Enhancement Requirements

**Date:** 2026-03-11
**Status:** Analysis Phase
**Analyst:** oh-my-claudecode:analyst

---

## Executive Summary

This document captures requirements for a comprehensive enhancement to the Self-Study-Tool platform, introducing an AI-driven "Head Teacher Agent" (班主任Agent) orchestration system with deep personalization, intelligent scheduling, and professional-grade educational content delivery.

**Core Vision:** Transform the platform from a basic study tool into an intelligent, adaptive learning system with AI agents that provide personalized, professional-grade tutoring comparable to human expert teachers.

---

## 1. Head Teacher Agent (班主任Agent) - Core Orchestrator

### 1.1 Initial Onboarding & User Profiling

**Requirement:** Interactive N-question onboarding flow to build comprehensive user profile.

**Data to Collect:**
- Basic: Name, Age
- Educational: Current level, subjects, learning goals
- Self-assessment: Strengths, weaknesses, learning style preferences
- Availability: Free time slots (detailed to specific periods/sessions)
- Preferences: Study pace, difficulty tolerance, preferred teaching methods

**Acceptance Criteria:**
- [ ] Conversational Q&A interface (not form-based)
- [ ] All collected data persists to user profile
- [ ] Profile completeness validation before proceeding
- [ ] User can skip and return later (progress saved)

**Technical Constraints:**
- Must integrate with existing `user_profile` module
- Flutter UI must support multi-turn conversational flow
- Backend must validate and structure unstructured AI responses

---

### 1.2 Intelligent Course Schedule Management

**Requirement:** AI-generated personalized course schedule based on user profile, goals, and availability.

**Capabilities:**
- Generate detailed schedule: subject → chapter → session → content depth
- Dynamic adjustment based on user requests (leave, advance, delay)
- Bind schedule to teaching agents for execution
- Support multiple views: daily (default), weekly, monthly

**Acceptance Criteria:**
- [ ] Schedule generation considers: user level, goals, available time, subject dependencies
- [ ] User can request changes via natural language ("今天有事，无法进行计划")
- [ ] Agent automatically adjusts entire schedule to maintain learning continuity
- [ ] Daily view shows today's classes with direct access
- [ ] Each schedule entry links to executable teaching session

**Technical Constraints:**
- Schedule stored in `plan` module (extend existing schema)
- Must handle conflicts and dependencies between subjects
- Adjustment algorithm must preserve learning progression logic

---

### 1.3 Agent Lifecycle Management

**Requirement:** Head Teacher dynamically creates, configures, and manages specialized teaching agents.

**Capabilities:**
- Analyze user needs and auto-generate subject-specific teaching agents
- Generate complete, professional, ready-to-use prompts for each agent
- Assign tasks to agents with context and expectations
- Agents proactively initiate conversations when tasks are due

**Acceptance Criteria:**
- [ ] Agent creation includes: subject, chapter scope, teaching style, difficulty calibration
- [ ] Generated prompts include all necessary context from prompt database
- [ ] Agents receive schedule bindings and task assignments
- [ ] Agents persist after class completion for follow-up questions
- [ ] Agents have access to previous/next session context for continuity

**Technical Constraints:**
- Extends existing `ai_agent` module
- Prompt templates stored in database with variable interpolation
- Agent state management (active, idle, archived)
- Must support agent-to-agent context sharing

---


## 2. Default Prompt Enhancement

**Requirement:** Upgrade all default prompts to production-ready, robust, professional-grade templates.

**Scope:**
- Teaching agent prompts (per subject/chapter)
- Grading agent prompts (per subject, aligned with exam standards)
- Question generation prompts
- Schedule management prompts
- User profiling prompts

**Acceptance Criteria:**
- [ ] All prompts include: role definition, constraints, output format, examples
- [ ] Prompts leverage all available context (user profile, schedule, history)
- [ ] Prompts include error handling and edge case instructions
- [ ] Teaching prompts calibrated to professional teacher standards
- [ ] Grading prompts aligned with national exam (高考) standards

**Technical Constraints:**
- Prompts stored in database with versioning
- Support variable interpolation for personalization
- Must not exceed model context limits

---

## 3. Course Schedule & Teaching Session Enhancements

### 3.1 Homework Generation & Binding

**Requirement:** AI automatically generates homework after each class, bound to specific course sessions.

**Acceptance Criteria:**
- [ ] Homework generated based on class content and difficulty
- [ ] Homework appears in practice module with course binding
- [ ] User can see which class generated which homework
- [ ] Homework difficulty matches class difficulty setting

**Technical Constraints:**
- Extends `practice` module with `course_session_id` foreign key
- Homework questions stored in `question` module with metadata

---

### 3.2 Professional-Grade Teaching

**Requirement:** Teaching agents deliver expert-level instruction, not superficial content.

**Capabilities:**
- Generate challenging, appropriate-difficulty questions
- Provide detailed explanations with examples
- Adapt teaching style based on user comprehension
- Set review schedules for memory-intensive content

**Acceptance Criteria:**
- [ ] Questions match or exceed textbook difficulty standards
- [ ] No trivial or overly simple questions
- [ ] Teaching flow optimized for comprehension (your design)
- [ ] Agent can schedule follow-up review sessions automatically
- [ ] Review sessions added to plan module with trigger dates

**Technical Constraints:**
- Teaching flow state machine (intro → explain → example → practice → review)
- Review scheduling integrated with `plan` module

---

### 3.3 In-Class Practice Flow

**Requirement:** In-class practice launches interactive quiz interface, not just question generation.

**Acceptance Criteria:**
- [ ] Practice button launches dedicated quiz UI
- [ ] User completes questions in real-time
- [ ] After completion, user can optionally save to question bank
- [ ] No automatic question bank pollution

**Technical Constraints:**
- Flutter: new in-class practice screen
- Backend: ephemeral question session (not persisted unless user chooses)

---

### 3.4 Course Context Awareness

**Requirement:** Teaching agents have access to adjacent course session summaries.

**Acceptance Criteria:**
- [ ] Agent receives previous 2-3 session summaries
- [ ] Agent receives next 1-2 session summaries
- [ ] Agent uses context to ensure continuity and foreshadowing
- [ ] Context includes: topics covered, difficulty level, key concepts

**Technical Constraints:**
- Course session metadata includes summary field
- Agent prompt includes context injection

---

### 3.5 Persistent Teaching Agents

**Requirement:** Teaching agents remain accessible after class for follow-up questions.

**Acceptance Criteria:**
- [ ] Agent not deleted after session ends
- [ ] User can return to agent chat anytime
- [ ] Agent retains session context and history
- [ ] Agent list shows completed vs active sessions

**Technical Constraints:**
- Agent state: `active`, `completed`, `archived`
- Chat history persisted per agent

---

### 3.6 Study Time Tracking & Profiling

**Requirement:** Track actual study time and use for AI scoring/profiling.

**Acceptance Criteria:**
- [ ] Timer tracks active study time per session
- [ ] Time data added to user profile after session
- [ ] AI uses time data for effort assessment
- [ ] Time tracking integrated with pomodoro module

**Technical Constraints:**
- Extends existing `pomodoro` module
- Time data linked to course sessions


## 4. Question Bank Enhancements

### 4.1 Advanced Sorting & Filtering

**Requirement:** Multi-dimensional sorting and filtering for question bank.

**Sort Options:**
- Difficulty (1-10 scale)
- Subject
- Chapter
- Score/Performance
- Date added
- Source (AI-generated, imported, homework)

**Acceptance Criteria:**
- [ ] Support multi-level sorting (e.g., subject → chapter → difficulty)
- [ ] Filter combinations work correctly
- [ ] Performance optimized for large question banks (10k+ questions)

**Technical Constraints:**
- Database indexes on sort fields
- Frontend pagination required

---

### 4.2 AI-Driven Question Composition

**Requirement:** AI can query and compose question sets programmatically.

**Acceptance Criteria:**
- [ ] AI tools can query by: subject, chapter, difficulty range, tags
- [ ] AI can create practice sets without user intervention
- [ ] Query results respect user's learning progress

**Technical Constraints:**
- New AI tool: `QueryQuestionBank` with structured parameters
- Tool returns question IDs, not full content (token efficiency)

---

### 4.3 Professional Difficulty Calibration

**Requirement:** 10-level difficulty system aligned with national exam standards.

**Difficulty Scale:**
- Level 1-3: Basic comprehension (高考前三道选择题难度)
- Level 4-6: Intermediate application
- Level 7-8: Advanced synthesis
- Level 9-10: Expert level (高考最难题难度)

**Acceptance Criteria:**
- [ ] Difficulty assessment prompt per subject
- [ ] AI grader validates difficulty matches content
- [ ] Difficulty distribution tracked per user
- [ ] Recalibration mechanism for misclassified questions

**Technical Constraints:**
- Difficulty stored as integer 1-10
- Calibration prompt includes subject-specific rubrics

---

### 4.4 Reverse Navigation to Source Course

**Requirement:** Questions generated by teaching agents link back to originating course session.

**Acceptance Criteria:**
- [ ] Question metadata includes `source_course_session_id`
- [ ] UI shows "View Source Class" button when applicable
- [ ] Clicking navigates to course session chat
- [ ] User can ask follow-up questions to original teaching agent

**Technical Constraints:**
- `question` table adds nullable `course_session_id` foreign key
- Flutter navigation stack handles deep linking

---


## 5. Practice Module Enhancements

### 5.1 Intelligent Exam Paper Generation

**Requirement:** AI generates complete, rigorous exam papers following standard examination protocols.

**Capabilities:**
- Generate papers based on user's course progress (completed + upcoming)
- Follow standard exam structure (multiple choice, short answer, essay)
- Validate correctness programmatically for STEM subjects
- Verify factual accuracy for humanities subjects
- Network search for time-sensitive content (politics, current events)

**Acceptance Criteria:**
- [ ] Paper structure matches real exam formats
- [ ] STEM questions validated via computation/proof
- [ ] Humanities questions fact-checked (sources cited)
- [ ] Questions marked as "unverified" if validation fails
- [ ] Network search capability integrated (MCP or custom implementation)
- [ ] User-ready without additional configuration

**Technical Constraints:**
- Network search: implement via MCP server or custom HTTP client
- Validation logic per subject type
- Paper generation prompt includes exam rubrics

---

### 5.2 AI-Powered Unit Practice

**Requirement:** Unit practice auto-generates questions for current learning unit.

**Acceptance Criteria:**
- [ ] Default unit: current progress in selected subject
- [ ] User can select different subject/unit
- [ ] Questions match unit scope and difficulty
- [ ] Practice session saved with unit metadata

**Technical Constraints:**
- Requires user progress tracking per subject/unit
- Question generation scoped to unit content

---

### 5.3 Unified Practice Detail View

**Requirement:** Practice detail page shows score, correctness, and user answer in single unified view.

**Acceptance Criteria:**
- [ ] Single card/section per question showing: score, correct/incorrect, user answer, correct answer
- [ ] Visual distinction for correct vs incorrect
- [ ] Detailed explanation expandable
- [ ] No scattered information across multiple sections

**Technical Constraints:**
- Flutter UI redesign for practice detail screen

---

### 5.4 Historical Answer Navigation

**Requirement:** Click on historical answer to jump to that specific attempt's detail page.

**Acceptance Criteria:**
- [ ] Historical answers shown as clickable list
- [ ] Each entry shows: date, score, time spent
- [ ] Clicking navigates to full detail view of that attempt
- [ ] Navigation stack preserves context

**Technical Constraints:**
- Practice attempts stored with unique IDs
- Deep linking support in Flutter

---

### 5.5 Professional Grading System

**Requirement:** Exam-grade grading with detailed feedback per question.

**Grading Output:**
- Correctness (correct/incorrect/partial)
- Score (numeric)
- Detailed explanation
- Improvement suggestions
- Error pinpointing (without revealing answer directly)
- Full solution in separate "answer key" section

**Acceptance Criteria:**
- [ ] Grading prompt per subject with exam-level rubrics
- [ ] Partial credit supported for multi-step problems
- [ ] Error analysis highlights mistake without spoiling solution
- [ ] Answer key hidden by default, user must expand

**Technical Constraints:**
- Grading agent per subject
- Structured output format for parsing


## 6. AI System Enhancements

### 6.1 User Profiling & Personalization

**Requirement:** AI maintains comprehensive, multi-dimensional user profiles for personalized service.

**Profile Dimensions:**
- Subject profiles: strengths, weaknesses, learning pace per subject
- Overall profile: learning style, goals, progress, effort level
- Lifestyle profile: availability patterns, stress levels, preferences

**Acceptance Criteria:**
- [ ] AI can read/write profile data via tools
- [ ] Profile updates after each significant interaction
- [ ] Profile data influences all AI decisions (scheduling, difficulty, teaching style)
- [ ] User can view and edit profile data

**Technical Constraints:**
- Extends `user_profile` module with structured JSON fields
- AI tools: `ReadUserProfile`, `UpdateUserProfile`

---

### 6.2 Comprehensive Prompt Engineering

**Requirement:** All AI interactions use detailed, professional-grade prompts.

**Acceptance Criteria:**
- [ ] Every AI function has dedicated, tested prompt
- [ ] Prompts include: role, context, constraints, output format, examples
- [ ] Prompts reference user profile data
- [ ] Prompts include error handling instructions

**Technical Constraints:**
- Prompt library stored in database
- Version control for prompt iterations

---

### 6.3 Proactive Context Access

**Requirement:** AI agents can autonomously read user data to improve service quality.

**Accessible Data:**
- User profile
- Course schedule
- Practice history
- Question bank performance
- Resource library

**Acceptance Criteria:**
- [ ] AI tools for reading all relevant data
- [ ] Tools return token-efficient summaries
- [ ] Access logged for transparency
- [ ] No sensitive data exposure

**Technical Constraints:**
- Tools return structured data, not raw dumps
- Implement pagination for large datasets

---

### 6.4 Exam-Grade Scoring System

**Requirement:** Scoring aligned with national exam (高考) standards and strictness.

**Acceptance Criteria:**
- [ ] Scoring rubrics per subject match exam standards
- [ ] Partial credit rules match official guidelines
- [ ] Grading consistency validated across attempts
- [ ] Score distribution tracked and analyzed

**Technical Constraints:**
- Grading prompts include official rubrics
- Score validation logic per question type

---

### 6.5 Subject-Specific Grading Agents

**Requirement:** Dedicated grading agent per subject with specialized expertise.

**Acceptance Criteria:**
- [ ] Grading agent per major subject (Math, Physics, Chemistry, Chinese, English, etc.)
- [ ] Agent prompts include subject-specific rubrics and standards
- [ ] Agents handle subject-specific notation (LaTeX for math, pinyin for Chinese, etc.)
- [ ] Grading quality validated against human expert benchmarks

**Technical Constraints:**
- Agent registry maps subjects to grading agents
- Prompts stored per subject with examples


## 7. Resource Library Enhancements

### 7.1 Multi-Format Import Support

**Requirement:** Import resources in all common formats with AI-powered classification.

**Supported Formats:**
- Documents: PDF, DOCX, TXT, MD
- Images: PNG, JPG, JPEG, WebP
- E-books: MOBI, EPUB
- Others: PPT, PPTX (future consideration)

**Acceptance Criteria:**
- [ ] File upload supports all listed formats
- [ ] AI analyzes content using multimodal capabilities
- [ ] AI suggests: subject, chapter, tags, difficulty
- [ ] User can accept or modify AI suggestions
- [ ] OCR for image-based content

**Technical Constraints:**
- File storage: local filesystem or cloud (S3-compatible)
- AI vision API for image/PDF analysis
- Text extraction libraries per format

---

### 7.2 AI Resource Query & Retrieval

**Requirement:** AI can search and retrieve resources programmatically.

**Query Capabilities:**
- By subject and chapter
- By keywords (semantic search preferred)
- By resource type
- By relevance to current topic

**Acceptance Criteria:**
- [ ] AI tool: `QueryResources` with structured parameters
- [ ] Returns resource metadata + excerpts (not full content)
- [ ] Token-efficient: keyword-based or targeted retrieval
- [ ] Results ranked by relevance

**Technical Constraints:**
- Semantic search: vector embeddings (optional, can start with keyword)
- Tool returns resource IDs + summaries
- Full content retrieved only when needed

---

### 7.3 Token-Efficient Resource Access

**Requirement:** AI uses smart querying to avoid token overflow.

**Strategies:**
- Keyword-based search instead of full-text retrieval
- Targeted section extraction (e.g., "Chapter 3, Section 2")
- Summary-first approach (retrieve summary, then details if needed)

**Acceptance Criteria:**
- [ ] AI prompts include token-efficiency guidelines
- [ ] Tools support targeted retrieval parameters
- [ ] Large resources chunked with navigation

**Technical Constraints:**
- Resource metadata includes table of contents
- Chunking strategy for large documents


## 8. Mistake Book (错题本) Enhancements

### 8.1 Granular Organization & Analysis

**Requirement:** Organize mistakes by subject → unit → course, with AI-powered analysis.

**Organization Structure:**
- Top level: Today's mistakes (default view)
- Subject level: All mistakes per subject
- Unit level: Mistakes per unit within subject
- Course level: Mistakes per specific course session

**Acceptance Criteria:**
- [ ] Default view shows today's mistakes across all subjects
- [ ] Hierarchical navigation: subject → unit → individual mistakes
- [ ] Alternative sort: chronological (time-based)
- [ ] Filter by: subject, unit, difficulty, mistake type

**Technical Constraints:**
- `mistake` table links to: subject, unit, course_session_id, question_id
- Indexes for efficient hierarchical queries

---

### 8.2 AI-Powered Weakness Analysis

**Requirement:** AI analyzes mistake patterns and updates user profile.

**Analysis Output:**
- Common error types per subject
- Weak knowledge points (specific chapters/concepts)
- Strong areas (for confidence building)
- Recommended focus areas

**Acceptance Criteria:**
- [ ] AI tool: `AnalyzeMistakes` with date range and subject filters
- [ ] Analysis results written to user profile
- [ ] Analysis influences future question selection and teaching focus
- [ ] User can view analysis report

**Technical Constraints:**
- Analysis runs periodically or on-demand
- Results stored in user profile JSON field

---

### 8.3 Flexible Sorting Options

**Requirement:** Multiple sorting strategies for mistake review.

**Sort Options:**
- Subject → Unit → Chronological (default)
- Pure chronological (newest first)
- Difficulty (hardest first)
- Frequency (most repeated mistakes first)

**Acceptance Criteria:**
- [ ] User can switch sort mode via UI
- [ ] Sort preference persisted per user
- [ ] Performance optimized for large mistake sets

**Technical Constraints:**
- Database indexes for each sort dimension
- Frontend caching for smooth UX


## 9. Technical Architecture Requirements

### 9.1 Backend (Go)

**New Modules Required:**
- `head_teacher`: Orchestrator agent management
- `course_schedule`: Schedule generation and management
- `agent_registry`: Agent lifecycle and prompt management
- `grading`: Subject-specific grading engines
- `profiling`: User profile analytics

**Module Extensions:**
- `ai`: Add agent creation, task assignment, context sharing
- `practice`: Add course binding, ephemeral sessions
- `question`: Add difficulty calibration, source tracking
- `mistake`: Add hierarchical organization, analysis
- `resource`: Add multi-format import, semantic search
- `plan`: Add review scheduling, dynamic adjustment

**Infrastructure:**
- Network search capability (MCP or HTTP client)
- File storage for resources (local or S3-compatible)
- Vector database for semantic search (optional phase 2)

---

### 9.2 Frontend (Flutter)

**New Screens:**
- Onboarding flow (conversational Q&A)
- Daily schedule view (default)
- In-class practice interface
- Agent management dashboard
- User profile editor
- Mistake analysis report

**Screen Enhancements:**
- Practice detail: unified view redesign
- Question bank: advanced filters and sorting
- Resource library: multi-format upload
- Agent chat: persistent access, course context

---

### 9.3 Database Schema Changes

**New Tables:**
- `course_schedules`: Schedule entries with metadata
- `agent_registry`: Agent definitions and states
- `prompt_templates`: Versioned prompt library
- `user_profiles_extended`: JSON fields for profiling data
- `grading_rubrics`: Subject-specific scoring rules

**Table Extensions:**
- `practices`: Add `course_session_id`, `is_ephemeral`
- `questions`: Add `difficulty_level` (1-10), `source_course_session_id`
- `mistakes`: Add `unit_id`, `course_session_id`
- `resources`: Add `format`, `ai_classification`
- `plans`: Add `review_target_id`, `adjustment_history`

---


## 10. Missing Questions & Ambiguities

### 10.1 Head Teacher Agent Implementation

**Missing Questions:**
- [ ] What triggers Head Teacher agent creation? First app launch? Manual user action?
- [ ] How does Head Teacher decide when to create new teaching agents? User request only, or proactive based on schedule?
- [ ] What happens if user abandons onboarding mid-way? Can they resume? Is partial profile usable?
- [ ] How does schedule adjustment algorithm prioritize conflicts? (e.g., user requests delay but has exam deadline)
- [ ] What's the maximum number of concurrent teaching agents? Any resource limits?

**Why These Matter:**
- Initialization flow affects user experience and data consistency
- Agent creation strategy impacts system load and prompt costs
- Partial profile handling prevents data corruption
- Conflict resolution needs clear business rules
- Resource limits prevent system overload

---

### 10.2 Network Search Implementation

**Missing Questions:**
- [ ] Which network search provider? (Google, Bing, DuckDuckGo, or custom MCP server?)
- [ ] What's the fallback if network search fails? Skip question or mark as unverified?
- [ ] Rate limiting strategy? How many searches per exam paper generation?
- [ ] Cost considerations? API keys required? User-provided or system-provided?
- [ ] Privacy: Does user consent to network requests? Data retention policy?

**Why These Matter:**
- Provider choice affects reliability, cost, and setup complexity
- Fallback strategy prevents exam generation failures
- Rate limits prevent abuse and cost overruns
- API key management affects deployment complexity
- Privacy compliance may be legally required

---

### 10.3 Difficulty Calibration

**Missing Questions:**
- [ ] Who defines the initial difficulty rubrics per subject? AI-generated or human-curated?
- [ ] How is difficulty validated? Human review? User feedback? Performance statistics?
- [ ] What's the recalibration trigger? User reports? Statistical outliers?
- [ ] How to handle subjective subjects (literature, art) where difficulty is less quantifiable?
- [ ] Should difficulty adapt per user? (What's "hard" for one user may be "easy" for another)

**Why These Matter:**
- Initial rubrics determine system quality from day one
- Validation ensures difficulty ratings are accurate
- Recalibration prevents drift over time
- Subjective subjects need different approaches
- Personalized difficulty improves learning outcomes

---

### 10.4 Resource Storage & Scalability

**Missing Questions:**
- [ ] Where are uploaded resources stored? Local filesystem? Cloud storage? Database BLOBs?
- [ ] What's the storage limit per user? Per resource? Total system?
- [ ] How are large files (100MB+ PDFs) handled? Chunking? Streaming?
- [ ] Backup and disaster recovery strategy?
- [ ] Multi-user access: Can resources be shared between users? Privacy controls?

**Why These Matter:**
- Storage choice affects performance, cost, and scalability
- Limits prevent abuse and manage costs
- Large file handling prevents memory issues
- Backup prevents data loss
- Sharing features require access control

---

### 10.5 AI Model & Cost Management

**Missing Questions:**
- [ ] Which AI model(s)? (GPT-4, Claude, Gemini, local models?)
- [ ] Cost per interaction? Who pays? (User subscription? System absorbs cost?)
- [ ] Token limits per request? Per user per day?
- [ ] Fallback if primary model unavailable?
- [ ] How to handle rate limits from AI provider?

**Why These Matter:**
- Model choice affects quality, cost, and latency
- Cost structure determines business viability
- Token limits prevent runaway costs
- Fallback ensures system reliability
- Rate limit handling prevents service disruption

---

### 10.6 Grading Consistency & Appeals

**Missing Questions:**
- [ ] How to ensure grading consistency across attempts? Same question, same answer → same score?
- [ ] Can users appeal grades? What's the process?
- [ ] How to handle edge cases where AI grading is clearly wrong?
- [ ] Should there be human review for high-stakes assessments?
- [ ] How to log and audit grading decisions for transparency?

**Why These Matter:**
- Consistency builds user trust
- Appeal process prevents frustration
- Error handling maintains system credibility
- Human review may be required for fairness
- Audit logs enable debugging and improvement

---


## 11. Undefined Guardrails

### 11.1 Agent Prompt Length

**What Needs Bounds:**
- Maximum prompt length for teaching agents
- Maximum context injection per agent
- Token budget per teaching session

**Suggested Definition:**
- Teaching agent base prompt: ≤2000 tokens
- Context injection (user profile + course context): ≤1000 tokens
- Per-session budget: ≤8000 tokens (allows multi-turn conversation)
- Hard limit: 32k tokens (model context window)

---

### 11.2 Schedule Adjustment Limits

**What Needs Bounds:**
- How far in advance can schedule be adjusted?
- Maximum number of adjustments per day/week?
- Minimum notice for schedule changes?

**Suggested Definition:**
- Adjustment window: up to 30 days in advance
- Max adjustments: 5 per day (prevents chaos)
- Minimum notice: 1 hour before scheduled session
- Emergency override: allowed but logged

---

### 11.3 Question Generation Limits

**What Needs Bounds:**
- Maximum questions per homework assignment
- Maximum questions per practice session
- Maximum questions in question bank per user

**Suggested Definition:**
- Homework: 5-15 questions (based on difficulty and time estimate)
- Practice session: 10-50 questions
- Question bank: 10,000 questions per user (soft limit, warn at 8,000)
- Daily generation limit: 100 questions per user (prevents abuse)

---

### 11.4 Resource Upload Limits

**What Needs Bounds:**
- Maximum file size per resource
- Maximum total storage per user
- Allowed file types (whitelist vs blacklist)

**Suggested Definition:**
- Max file size: 50MB per file
- Total storage: 1GB per user (expandable)
- Allowed types: PDF, DOCX, TXT, MD, PNG, JPG, JPEG, WebP, MOBI, EPUB
- Blocked types: EXE, DLL, SH, BAT (security)

---

### 11.5 AI Interaction Rate Limits

**What Needs Bounds:**
- Maximum AI requests per user per hour/day
- Maximum concurrent AI sessions per user
- Timeout for AI responses

**Suggested Definition:**
- Requests: 100 per hour, 500 per day per user
- Concurrent sessions: 3 (one teaching, one grading, one chat)
- Response timeout: 60 seconds (then retry or fail gracefully)
- Cooldown after timeout: 30 seconds

---


## 12. Scope Risks

### 12.1 Feature Creep: "Perfect AI Teacher"

**Area Prone to Creep:**
Attempting to build a fully autonomous AI teacher that handles every edge case and teaching scenario.

**How to Prevent:**
- Phase 1: Core teaching flow (explain → practice → grade)
- Phase 2: Add review scheduling and context awareness
- Phase 3: Advanced personalization and adaptation
- Define "good enough" criteria per phase
- User feedback gates progression to next phase

---

### 12.2 Over-Engineering Prompt System

**Area Prone to Creep:**
Building a complex prompt management system with versioning, A/B testing, analytics, etc.

**How to Prevent:**
- Start with static prompts in database
- Add versioning only when needed (after first iteration)
- Manual prompt updates initially (no auto-generation)
- Defer analytics until baseline quality established

---

### 12.3 Universal Resource Format Support

**Area Prone to Creep:**
Supporting every possible file format (PPT, Excel, video, audio, etc.)

**How to Prevent:**
- Phase 1: PDF, images, plain text only
- Phase 2: Add DOCX, MOBI, EPUB if demand exists
- Explicitly exclude: video, audio, spreadsheets (different use case)
- Document unsupported formats with clear error messages

---

### 12.4 Real-Time Collaboration Features

**Area Prone to Creep:**
Adding multi-user features (shared resources, group study, teacher accounts)

**How to Prevent:**
- Explicitly single-user focused for MVP
- No sharing, no collaboration, no multi-tenancy
- Document as future consideration, not current scope
- Focus on individual learning experience

---


## 13. Unvalidated Assumptions

### 13.1 Assumption: Users Will Complete Onboarding

**Assumption:** Users will answer all onboarding questions and provide complete profile data.

**How to Validate:**
- Track onboarding completion rate in analytics
- A/B test: optional vs required questions
- User interviews: why did you skip questions?

**Mitigation:**
- Allow partial profiles with degraded experience
- Prompt for missing data when needed (just-in-time)
- Provide sensible defaults based on partial data

---

### 13.2 Assumption: AI Grading is Accurate Enough

**Assumption:** AI can grade answers with exam-level accuracy without human review.

**How to Validate:**
- Benchmark against human expert grading (100 sample questions)
- Measure inter-rater reliability (AI vs human)
- Track user appeals and overturn rate

**Mitigation:**
- Start with objective questions (multiple choice, true/false)
- Add confidence scores to AI grades
- Flag low-confidence grades for review
- Provide appeal mechanism

---

### 13.3 Assumption: Network Search is Reliable

**Assumption:** Network search will return accurate, relevant results for fact-checking.

**How to Validate:**
- Test with known queries (ground truth dataset)
- Measure precision and recall
- Track "unverified" question rate

**Mitigation:**
- Use multiple sources for verification
- Require source citations
- Mark questions as "unverified" if search fails
- Allow manual verification override

---

### 13.4 Assumption: Users Have Consistent Study Time

**Assumption:** Users will follow generated schedules and have predictable availability.

**How to Validate:**
- Track schedule adherence rate
- Measure frequency of schedule adjustments
- Survey users about schedule realism

**Mitigation:**
- Build flexibility into schedules (buffer time)
- Easy rescheduling mechanism
- Adaptive scheduling based on actual behavior
- No penalties for schedule changes

---

### 13.5 Assumption: 10-Level Difficulty is Sufficient

**Assumption:** 10 difficulty levels provide adequate granularity for all subjects and users.

**How to Validate:**
- Analyze difficulty distribution in question bank
- Measure user performance correlation with difficulty
- Check for clustering (all questions at level 5)

**Mitigation:**
- Allow sub-levels if needed (5.5, 6.5)
- Per-subject difficulty calibration
- User-relative difficulty (adaptive)

---


## 14. Missing Acceptance Criteria

### 14.1 Onboarding Flow

**What Success Looks Like:**
- User completes onboarding in <10 minutes
- Profile data sufficient for first schedule generation
- User understands system capabilities after onboarding

**Measurable Criteria:**
- [ ] Onboarding completion rate >70%
- [ ] Average time to complete: 5-10 minutes
- [ ] Profile completeness score ≥80% after onboarding
- [ ] Zero crashes or errors during onboarding flow

---

### 14.2 Schedule Generation Quality

**What Success Looks Like:**
- Generated schedule is realistic and followable
- User adheres to schedule without constant adjustments
- Learning progression is logical and effective

**Measurable Criteria:**
- [ ] Schedule adherence rate >60% in first week
- [ ] <3 schedule adjustments per week on average
- [ ] User satisfaction score ≥4/5 for schedule quality
- [ ] No impossible schedules (e.g., 8 hours of study in 2 hours of free time)

---

### 14.3 Teaching Quality

**What Success Looks Like:**
- User comprehends material after teaching session
- Questions are appropriately challenging
- User feels session was valuable

**Measurable Criteria:**
- [ ] Post-session quiz pass rate >70%
- [ ] User rates session ≥4/5 for quality
- [ ] <10% of questions flagged as "too easy" or "too hard"
- [ ] User returns to agent for follow-up questions (engagement indicator)

---

### 14.4 Grading Accuracy

**What Success Looks Like:**
- Grades match human expert judgment
- Users trust AI grading
- Few appeals or disputes

**Measurable Criteria:**
- [ ] Agreement with human grading ≥90% (on sample set)
- [ ] Appeal rate <5% of all graded questions
- [ ] Appeal overturn rate <20% (most appeals rejected)
- [ ] User satisfaction with grading ≥4/5

---

### 14.5 System Performance

**What Success Looks Like:**
- Fast response times
- No crashes or data loss
- Handles concurrent users gracefully

**Measurable Criteria:**
- [ ] AI response time <5 seconds (p95)
- [ ] Page load time <2 seconds (p95)
- [ ] Zero data loss incidents
- [ ] Uptime ≥99.5%
- [ ] Supports ≥100 concurrent users (if multi-user)

---


## 15. Edge Cases

### 15.1 Incomplete User Profile

**Scenario:** User skips onboarding or provides minimal information.

**How to Handle:**
- Generate basic schedule with conservative assumptions
- Prompt for missing data when needed (just-in-time)
- Degrade gracefully: simpler teaching, generic difficulty
- Show profile completion indicator with benefits of completing

---

### 15.2 Schedule Conflicts

**Scenario:** User requests schedule change that conflicts with exam deadline or dependencies.

**How to Handle:**
- Detect conflicts before applying changes
- Show conflict explanation to user
- Offer alternatives: compress other sessions, extend study hours, skip optional content
- Require explicit user confirmation for risky changes

---

### 15.3 AI Grading Failure

**Scenario:** AI returns malformed response, times out, or produces nonsensical grade.

**How to Handle:**
- Retry once with simplified prompt
- If retry fails, mark as "pending review"
- Log error for debugging
- Notify user: "Grading delayed, will be available soon"
- Fallback: basic correctness check (exact match for objective questions)

---

### 15.4 Network Search Unavailable

**Scenario:** Network search fails during exam paper generation.

**How to Handle:**
- Mark affected questions as "unverified"
- Continue generation with remaining questions
- Show warning to user: "Some questions could not be fact-checked"
- Allow manual verification or regeneration

---

### 15.5 Resource Upload Failure

**Scenario:** File too large, unsupported format, or corrupted file.

**How to Handle:**
- Validate file before processing (size, format, integrity)
- Show clear error message with specific issue
- Suggest solutions: compress file, convert format, re-upload
- No partial uploads (atomic operation)

---

### 15.6 Concurrent Schedule Modifications

**Scenario:** User modifies schedule while AI is also adjusting it (race condition).

**How to Handle:**
- Optimistic locking: detect concurrent modifications
- Show conflict resolution UI: "Schedule changed, review changes?"
- User chooses: keep their changes, accept AI changes, or merge
- Log all modifications for audit trail

---

### 15.7 Teaching Agent Context Overflow

**Scenario:** Teaching session exceeds token limit due to long conversation.

**How to Handle:**
- Monitor token usage throughout session
- When approaching limit (80%), summarize conversation
- Continue with summarized context
- Warn user: "Session is long, consider wrapping up"
- Hard limit: gracefully end session at 95% token usage

---

### 15.8 Zero Questions in Question Bank

**Scenario:** User requests practice but has no questions in selected subject/unit.

**How to Handle:**
- Detect empty question bank before generation
- Offer to generate questions on-the-fly
- Suggest importing resources or taking a class first
- No empty practice sessions

---

### 15.9 Difficulty Calibration Outliers

**Scenario:** Question marked as difficulty 3 but users consistently fail it (actually difficulty 8).

**How to Handle:**
- Track performance statistics per question
- Flag outliers: difficulty vs actual performance mismatch
- Recalibrate automatically after N attempts (N=20)
- Notify user of recalibration: "This question's difficulty was adjusted"

---

### 15.10 User Requests Impossible Schedule

**Scenario:** User wants to learn calculus in 1 week with 1 hour/day availability.

**How to Handle:**
- Validate schedule feasibility before generation
- Calculate minimum time required based on content volume
- Show warning: "This goal requires X hours, you have Y hours available"
- Offer alternatives: extend timeline, increase daily hours, reduce scope
- Require explicit acknowledgment of unrealistic goals

---


## 16. Recommendations

### Priority 1: Critical for MVP

1. **Define AI Model & Cost Strategy** - Blocks all AI features
   - Choose model(s): GPT-4, Claude, or local
   - Determine cost structure and limits
   - Set up API keys and fallback strategy

2. **Implement Network Search** - Required for exam generation
   - Choose provider (recommend: MCP server for flexibility)
   - Implement with retry and fallback logic
   - Document setup for "out-of-box" experience

3. **Design Database Schema** - Foundation for all features
   - Create migration plan from current schema
   - Add all new tables and foreign keys
   - Plan indexes for performance

4. **Define Difficulty Rubrics** - Core quality metric
   - Create initial rubrics per major subject
   - Validate with sample questions
   - Document calibration process

5. **Establish Guardrails** - Prevent system abuse
   - Implement rate limits and quotas
   - Add validation for all user inputs
   - Set resource limits (storage, tokens, etc.)

---

### Priority 2: Important for Quality

6. **Build Prompt Library** - Determines AI quality
   - Start with 5-10 core prompts (teaching, grading, scheduling)
   - Test and iterate on quality
   - Add versioning when needed

7. **Implement User Profiling** - Enables personalization
   - Design profile schema (JSON structure)
   - Create AI tools for read/write access
   - Build profile editor UI

8. **Create Grading Validation** - Ensures trust
   - Benchmark against human grading (100 questions)
   - Implement confidence scoring
   - Add appeal mechanism

9. **Design Onboarding Flow** - First user experience
   - Write conversational script
   - Implement progress saving
   - Test completion rates

---

### Priority 3: Nice-to-Have Enhancements

10. **Add Semantic Search** - Better resource discovery
    - Implement vector embeddings (optional)
    - Start with keyword search, upgrade later

11. **Build Analytics Dashboard** - Track system health
    - Monitor key metrics (completion rates, satisfaction, performance)
    - Defer until baseline established

12. **Implement A/B Testing** - Optimize prompts
    - Add after initial prompt quality validated
    - Not needed for MVP

---

### Open Questions

Before planning can proceed, these questions need answers:

- [ ] **AI Model Selection** — Which model(s) will be used? What's the budget per user per month?
- [ ] **Network Search Provider** — MCP server, direct API, or custom implementation? Who provides API keys?
- [ ] **Resource Storage** — Local filesystem or cloud? What's the storage limit per user?
- [ ] **Onboarding Trigger** — When does Head Teacher agent initialize? First launch or manual?
- [ ] **Schedule Conflict Resolution** — What's the priority order when conflicts occur? (exam > review > new content?)
- [ ] **Grading Appeals** — What's the process? Human review available? Automated re-grading?
- [ ] **Difficulty Validation** — Who creates initial rubrics? AI-generated or human-curated?
- [ ] **Multi-User Support** — Is this planned? Affects architecture decisions now.
- [ ] **Deployment Model** — Self-hosted or SaaS? Affects resource management strategy.
- [ ] **Localization** — Chinese-only or multi-language? Affects prompt design.

---

## 17. Implementation Phases

### Phase 1: Foundation (Weeks 1-4)
- Database schema migration
- AI model integration
- Basic prompt library
- User profiling system
- Network search capability

### Phase 2: Core Features (Weeks 5-8)
- Head Teacher agent (onboarding + scheduling)
- Teaching agent framework
- Grading system (objective questions first)
- Enhanced question bank (difficulty, sorting)

### Phase 3: Advanced Features (Weeks 9-12)
- Homework generation and binding
- In-class practice flow
- Resource multi-format import
- Mistake analysis
- Review scheduling

### Phase 4: Polish & Optimization (Weeks 13-16)
- UI/UX refinements
- Performance optimization
- Grading validation and appeals
- Analytics and monitoring
- User testing and iteration

---

## 18. Success Metrics

### User Engagement
- Onboarding completion rate >70%
- Daily active usage >50% of registered users
- Average session duration >20 minutes
- Schedule adherence rate >60%

### Quality Metrics
- Teaching session satisfaction ≥4/5
- Grading accuracy ≥90% vs human expert
- Question difficulty calibration accuracy ≥85%
- Appeal rate <5%, overturn rate <20%

### Technical Metrics
- AI response time <5s (p95)
- Page load time <2s (p95)
- Uptime ≥99.5%
- Zero data loss incidents

### Business Metrics
- User retention (30-day) >40%
- Feature adoption: all core features used by >60% of users
- Support ticket rate <5% of users per month

---

## 19. Risk Mitigation

### Technical Risks
- **AI Model Unavailability** → Implement fallback model + graceful degradation
- **Token Cost Overrun** → Strict rate limits + monitoring + alerts
- **Data Loss** → Regular backups + atomic operations + audit logs
- **Performance Degradation** → Load testing + caching + database optimization

### Product Risks
- **Poor AI Quality** → Extensive prompt testing + human validation + feedback loops
- **Low User Adoption** → User research + iterative design + onboarding optimization
- **Feature Creep** → Strict scope definition + phased rollout + MVP focus

### Operational Risks
- **Support Burden** → Comprehensive docs + in-app help + error messages
- **Scaling Issues** → Horizontal scaling design + resource limits + monitoring

---

**End of Requirements Document**

