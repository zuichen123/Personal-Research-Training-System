# PRTS UI Optimization - Implementation Plan

**Version:** 1.0
**Date:** 2026-03-12
**Target Execution:** Ralph + Ultrawork (Phase 2)
**Estimated Duration:** 7 weeks (35 working days)

## Executive Summary

This plan breaks down the optimization specification into 87 atomic, independently testable tasks across 7 phases. Focus areas:

1. **Frontend-Backend Alignment** (12 missing Flutter integrations)
2. **Agent Module Consolidation** (remove duplicate `agent/` module)
3. **UI Component Standardization** (8 core components)
4. **Deprecated Code Removal** (5 backend files, 2 Flutter files)

**Critical Path:** Phase 0 → Phase 1 (API alignment) → Phase 2 (cleanup) → Phase 3 (enhancement)

**Parallel Execution:** 44 tasks can run in parallel (marked with `[P]`)

**Risk Level:** Medium (data migration in Phase 2)

---

## Dependency Graph

```
Phase 0 (Foundation)
├─ T001-T004: API Standards [P] → T005-T007: Error Handling
├─ T008-T009: Component Setup [P] → T010-T015: Core Components
└─ All Phase 0 → Phase 1

Phase 1 (Critical Alignment)
├─ T016-T019: Models [P] → T020-T037: API Methods
├─ T020-T037: API Methods → T038-T053: UI Integration
└─ All Phase 1 → Phase 2

Phase 2 (Cleanup)
├─ T054-T056: Migration Script → T057-T060: Execute Migration
├─ T061-T065: Backend Cleanup [after T060]
├─ T066-T069: Flutter Cleanup [after T060]
└─ All Phase 2 → Phase 3

Phase 3 (Enhancement)
├─ T070-T073: Prompt Template UI [P]
├─ T074-T076: Enhanced Chat UI [P]
├─ T077-T078: Additional UI Components [P]
└─ T079-T082: User Flow Optimization [P]

Phase 4 (Documentation)
├─ T083-T092: All parallel [P]
```

---

## Phase 0: Foundation (Week 1, Days 1-5)

**Goal:** Establish standards and core infrastructure
**Effort:** 5 days
**Risk:** Low
**Deliverables:** API standards doc, 6 core UI components, enhanced error handling

### 0.1 API Contract Standards (Day 1)

**T001** [P] Define error response format schema
- **File:** `docs/api-standards.md` (new)
- **Action:** Document JSON schema for error format
- **Acceptance:** Error format includes code, message, details, trace_id
- **Complexity:** Simple
- **Dependencies:** None

**T002** [P] Define pagination standard
- **File:** `docs/api-standards.md`
- **Action:** Document cursor-based pagination pattern
- **Acceptance:** Pagination includes cursor, has_more, limit
- **Complexity:** Simple
- **Dependencies:** None

**T003** [P] Define success response format
- **File:** `docs/api-standards.md`
- **Action:** Document standard response wrapper
- **Acceptance:** Response includes data, meta with timestamp and trace_id
- **Complexity:** Simple
- **Dependencies:** None

**T004** Document API versioning strategy
- **File:** `docs/api-standards.md`
- **Action:** Document URL-based versioning approach
- **Acceptance:** Versioning strategy documented with migration plan
- **Complexity:** Standard
- **Dependencies:** None

### 0.2 Flutter Error Handling Enhancement (Day 2)

**T005** Enhance ApiException class
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Add `details` (Map) and `traceId` (String?) fields
- **Acceptance:** ApiException supports structured error details
- **Complexity:** Simple
- **Dependencies:** T001

**T006** [P] Implement error code mapper
- **File:** `apps/flutter_client/lib/i18n/error_mapper.dart`
- **Action:** Add mapErrorCode method with backend error codes
- **Acceptance:** Maps VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, etc.
- **Complexity:** Standard
- **Dependencies:** T001

**T007** [P] Add retry logic to ApiService
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement exponential backoff for network failures
- **Acceptance:** 3 retries max with 1s, 2s, 4s delays
- **Complexity:** Standard
- **Dependencies:** None

### 0.3 Core UI Components (Days 3-5)

**T008** Create component library structure
- **File:** `apps/flutter_client/lib/widgets/common/` (new directory)
- **Action:** Create directory with README.md
- **Acceptance:** Directory exists with component usage guidelines
- **Complexity:** Simple
- **Dependencies:** None
- **Note:** Must complete before T010-T015

**T009** Define design tokens
- **File:** `apps/flutter_client/lib/theme/app_theme.dart`
- **Action:** Add color, spacing, radius constants
- **Acceptance:** Tokens defined: primaryColor, errorColor, successColor, spacing (xs/s/m/l/xl), radius (s/m/l)
- **Complexity:** Simple
- **Dependencies:** None

**T010** Implement AppButton component
- **File:** `apps/flutter_client/lib/widgets/common/app_button.dart`
- **Action:** Create button with loading state, variants (primary/secondary/text)
- **Acceptance:** Button shows CircularProgressIndicator when isLoading=true
- **Complexity:** Standard
- **Dependencies:** T009
- **Test:** Widget test for loading state

**T011** Implement AppTextField component
- **File:** `apps/flutter_client/lib/widgets/common/app_text_field.dart`
- **Action:** Create text field with validation, error display
- **Acceptance:** Shows error message below field, supports validator function
- **Complexity:** Standard
- **Dependencies:** T009
- **Test:** Widget test for validation

**T012** Implement AppCard component
- **File:** `apps/flutter_client/lib/widgets/common/app_card.dart`
- **Action:** Create unified card with elevation, padding variants
- **Acceptance:** Supports padding (none/small/medium/large)
- **Complexity:** Simple
- **Dependencies:** T009

**T013** Implement AppLoadingIndicator component
- **File:** `apps/flutter_client/lib/widgets/common/app_loading_indicator.dart`
- **Action:** Create loading indicator with optional message and progress
- **Acceptance:** Shows CircularProgressIndicator or LinearProgressIndicator with message
- **Complexity:** Standard
- **Dependencies:** T009

**T014** Implement AppErrorView component
- **File:** `apps/flutter_client/lib/widgets/common/app_error_view.dart`
- **Action:** Create error display with retry button
- **Acceptance:** Shows error icon, message, optional retry button
- **Complexity:** Standard
- **Dependencies:** T009, T006

**T015** Implement AppEmptyState component
- **File:** `apps/flutter_client/lib/widgets/common/app_empty_state.dart`
- **Action:** Create empty state with icon, message, action button
- **Acceptance:** Shows icon, message, optional action button
- **Complexity:** Simple
- **Dependencies:** T009

---

## Phase 1: Critical Alignment (Weeks 2-3, Days 6-15)

**Goal:** Integrate missing P0 features and migrate from legacy agent system
**Effort:** 10 days
**Risk:** Medium
**Deliverables:** 12 new API methods, 3 new models, provider config UI, artifacts UI

### 1.1 Flutter Data Models (Day 6)

**T016** [P] Create AgentSession model
- **File:** `apps/flutter_client/lib/models/agent_session.dart`
- **Action:** Create model with fromJson/toJson
- **Acceptance:** Fields: id, agentId, title, createdAt, updatedAt
- **Complexity:** Simple
- **Dependencies:** None

**T017** [P] Create Artifact model
- **File:** `apps/flutter_client/lib/models/artifact.dart`
- **Action:** Create model with fromJson/toJson
- **Acceptance:** Fields: id, sessionId, type, title, content, status, createdAt
- **Complexity:** Simple
- **Dependencies:** None

**T018** [P] Create PromptTemplate model
- **File:** `apps/flutter_client/lib/models/prompt_template.dart`
- **Action:** Create model with fromJson/toJson
- **Acceptance:** Fields: key, name, content, variables (List<String>)
- **Complexity:** Simple
- **Dependencies:** None

**T019** Update AIAgent model
- **File:** `apps/flutter_client/lib/models/ai_agent_chat.dart`
- **Action:** Add systemPrompt (String), model (String), temperature (double) fields. Remove fields: type, subject, promptTemplateId
- **Acceptance:** Model matches backend schema from internal/modules/ai/agent_chat_store.go:29-40. Verify fields: ID, Name, Protocol, Primary, Fallback, SystemPrompt, IntentCapabilities, Enabled, CreatedAt, UpdatedAt.
- **Complexity:** Simple
- **Dependencies:** None

### 1.2 API Service - Provider Configuration (Day 7)

**T020** Add getProviderStatus method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement GET /ai/provider
- **Acceptance:** Returns Map with provider status
- **Complexity:** Simple
- **Dependencies:** None

**T021** Add getDefaultAgentProvider method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement GET /ai/provider/default-agent
- **Acceptance:** Returns default provider name
- **Complexity:** Simple
- **Dependencies:** None

**T022** Add updateProviderConfig method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement PUT /ai/provider/config
- **Acceptance:** Accepts config Map, returns success
- **Complexity:** Simple
- **Dependencies:** None

### 1.3 API Service - Prompt Templates (Day 7)

**T023** [P] Add listPromptTemplates method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement GET /ai/prompts
- **Acceptance:** Returns List<PromptTemplate>
- **Complexity:** Simple
- **Dependencies:** T018

**T024** [P] Add updatePromptTemplate method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement PUT /ai/prompts/{key}
- **Acceptance:** Updates template, returns PromptTemplate
- **Complexity:** Simple
- **Dependencies:** T018

**T025** [P] Add reloadPromptTemplates method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement POST /ai/prompts/reload
- **Acceptance:** Triggers reload, returns success
- **Complexity:** Simple
- **Dependencies:** None

### 1.4 API Service - Agent Sessions (Day 8)

**T026** Add listAgentSessions method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement GET /ai/agents/{id}/sessions with pagination
- **Acceptance:** Returns List<AgentSession>, supports limit and cursor params
- **Complexity:** Standard
- **Dependencies:** T016, T002

**T027** Add createAgentSession method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement POST /ai/agents/{id}/sessions
- **Acceptance:** Creates session with optional title, returns AgentSession
- **Complexity:** Simple
- **Dependencies:** T016

**T028** Add deleteAgentSession method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement DELETE /ai/sessions/{id}
- **Acceptance:** Deletes session, returns success
- **Complexity:** Simple
- **Dependencies:** None

### 1.5 API Service - Session Artifacts (Day 8)

**T029** [P] Add listSessionArtifacts method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement GET /ai/sessions/{id}/artifacts
- **Acceptance:** Returns List<Artifact>, supports status filter
- **Complexity:** Standard
- **Dependencies:** T017

**T030** [P] Add importQuestionsFromArtifact method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement POST /ai/artifacts/{id}/import/questions
- **Acceptance:** Imports questions from artifact, returns result Map
- **Complexity:** Standard
- **Dependencies:** T017

**T031** [P] Add importPlanFromArtifact method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement POST /ai/artifacts/{id}/import/plan
- **Acceptance:** Imports plan from artifact, returns result Map
- **Complexity:** Standard
- **Dependencies:** T017

### 1.6 API Service - Session Operations (Day 9)

**T032** Add compressSessionMessages method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement POST /ai/sessions/{id}/compress
- **Acceptance:** Compresses history, accepts optional targetCount, returns result Map
- **Complexity:** Standard
- **Dependencies:** None

**T033** Add confirmSessionAction method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement POST /ai/sessions/{id}/confirm
- **Acceptance:** Confirms agent action, returns result Map
- **Complexity:** Standard
- **Dependencies:** None

### 1.7 API Service - Course Schedule Lessons (Day 9)

**T034** [P] Add listCourseScheduleLessons method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement GET /ai/course-schedule/lessons
- **Acceptance:** Returns List<CourseLesson>, supports scheduleId filter
- **Complexity:** Simple
- **Dependencies:** None

**T035** [P] Add createCourseScheduleLesson method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement POST /ai/course-schedule/lessons
- **Acceptance:** Creates lesson, returns CourseLesson
- **Complexity:** Simple
- **Dependencies:** None

**T036** [P] Add updateCourseScheduleLesson method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement PUT /ai/course-schedule/lessons/{id}
- **Acceptance:** Updates lesson, returns CourseLesson
- **Complexity:** Simple
- **Dependencies:** None

**T037** [P] Add deleteCourseScheduleLesson method
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Implement DELETE /ai/course-schedule/lessons/{id}
- **Acceptance:** Deletes lesson, returns success
- **Complexity:** Simple
- **Dependencies:** None

### 1.8 UI Integration - Provider Configuration (Days 10-11)

**T038** Add AI Provider section to settings screen
- **File:** `apps/flutter_client/lib/screens/settings_screen.dart`
- **Action:** Add "AI Provider" section with API key, model, temperature fields
- **Acceptance:** Form displays current config, saves on submit
- **Complexity:** Standard
- **Dependencies:** T020, T021, T022, T010, T011

**T039** Implement provider config form validation
- **File:** `apps/flutter_client/lib/screens/settings_screen.dart`
- **Action:** Validate API key format, temperature range (0-1)
- **Acceptance:** Shows validation errors, prevents invalid submission
- **Complexity:** Simple
- **Dependencies:** T038

**T040** Add provider status indicator
- **File:** `apps/flutter_client/lib/screens/settings_screen.dart`
- **Action:** Show provider connection status (connected/disconnected)
- **Acceptance:** Displays status badge with color indicator
- **Complexity:** Simple
- **Dependencies:** T038

### 1.9 UI Integration - Session Artifacts (Days 12-13)

**T041** Add artifacts tab to agent chat screen
- **File:** `apps/flutter_client/lib/screens/agent_chat_hub_screen.dart`
- **Action:** Add TabBar with "Chat" and "Artifacts" tabs
- **Acceptance:** Tabs switch between chat and artifacts views
- **Complexity:** Standard
- **Dependencies:** T029, T012

**T042** Implement artifacts list view
- **File:** `apps/flutter_client/lib/screens/agent_chat_hub_screen.dart`
- **Action:** Display artifacts in list with type, title, status
- **Acceptance:** Shows artifacts grouped by type, supports filtering
- **Complexity:** Standard
- **Dependencies:** T041, T017

**T043** Add artifact preview dialog
- **File:** `apps/flutter_client/lib/screens/agent_chat_hub_screen.dart`
- **Action:** Show artifact content in dialog with import actions
- **Acceptance:** Dialog displays content, shows import buttons for questions/plans
- **Complexity:** Standard
- **Dependencies:** T042, T030, T031

**T044** Implement artifact import actions
- **File:** `apps/flutter_client/lib/screens/agent_chat_hub_screen.dart`
- **Action:** Handle import questions/plan from artifact
- **Acceptance:** Shows success/error message, refreshes relevant screens
- **Complexity:** Standard
- **Dependencies:** T043

### 1.10 UI Integration - Course Schedule Lessons (Days 14-15)

**T045** Add lesson management to course schedule screen
- **File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`
- **Action:** Add "Manage Lessons" button, show lessons list
- **Acceptance:** Displays lessons for selected schedule
- **Complexity:** Standard
- **Dependencies:** T034, T012

**T046** Implement create lesson dialog
- **File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`
- **Action:** Dialog with lesson form (title, description, date, duration)
- **Acceptance:** Creates lesson on submit, refreshes list
- **Complexity:** Standard
- **Dependencies:** T035, T010, T011

**T047** Implement edit lesson dialog
- **File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`
- **Action:** Pre-populate form with lesson data, update on submit
- **Acceptance:** Updates lesson, refreshes list
- **Complexity:** Standard
- **Dependencies:** T036, T046

**T048** Implement delete lesson confirmation
- **File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`
- **Action:** Show confirmation dialog, delete on confirm
- **Acceptance:** Deletes lesson, refreshes list
- **Complexity:** Simple
- **Dependencies:** T037

### 1.11 Legacy Agent Migration (Day 15)

**T049** Audit legacy /agents endpoint usage in Flutter
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Identify all methods using /agents endpoints
- **Acceptance:** List of methods to migrate documented
- **Complexity:** Simple
- **Dependencies:** None

**T050** Migrate Flutter to /ai/agents endpoints
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Update all agent methods to use /ai/agents
- **Acceptance:** All agent operations use new endpoints
- **Complexity:** Standard
- **Dependencies:** T049

**T051** Add deprecation warnings to backend /agents endpoints
- **File:** `internal/modules/agent/handler.go`
- **Action:** Add X-Deprecated: true header, log warnings
- **Acceptance:** Legacy endpoints return deprecation header
- **Complexity:** Simple
- **Dependencies:** None

**T052** Test Flutter with new endpoints
- **File:** `apps/flutter_client/`
- **Action:** Run flutter analyze, execute test checklist with verification
- **Acceptance:** No errors, all agent features work. Test checklist: (1) Create agent → returns 201, agent.id present, agent appears in GET /ai/agents; (2) Start session → returns 201, session.id present; (3) Send message → returns 200, assistant_message.content non-empty; (4) View history → returns 200, messages array length ≥ 2; (5) Delete agent → returns 204, GET /ai/agents/{id} returns 404.
- **Complexity:** Standard
- **Dependencies:** T050

**T053** Update API documentation with deprecation notice
- **File:** `docs/api-standards.md`
- **Action:** Document deprecated endpoints, migration path
- **Acceptance:** Deprecation notice with timeline documented
- **Complexity:** Simple
- **Dependencies:** T051

---

## Phase 2: Cleanup (Week 4, Days 16-20)

**Goal:** Remove deprecated code and consolidate agent modules
**Effort:** 5 days
**Risk:** High (data migration)
**Deliverables:** Migration script, cleaned codebase, consolidated agent module

### 2.1 Data Migration Preparation (Days 16-17)

**T054** Create agent migration script
- **File:** `migrations/sqlite/036_consolidate_agents.sql`
- **Action:** Write SQL to migrate agents table to ai_agents
- **Acceptance:** Script creates agents_backup and agent_chat_history_backup tables, then performs migration with verification queries
- **Complexity:** Complex
- **Dependencies:** None

**T055** Create chat history migration script
- **File:** `migrations/sqlite/036_consolidate_agents.sql`
- **Action:** Write SQL to migrate agent_chat_history to ai_session_messages
- **Acceptance:** Script preserves all chat history with correct associations
- **Complexity:** Complex
- **Dependencies:** T054

**T056** Add migration rollback script
- **File:** `migrations/sqlite/036_consolidate_agents_rollback.sql`
- **Action:** Write SQL with these steps: (1) DROP TABLE ai_agents; (2) DROP TABLE ai_session_messages; (3) CREATE TABLE agents AS SELECT * FROM agents_backup; (4) CREATE TABLE agent_chat_history AS SELECT * FROM agent_chat_history_backup; (5) Verify: SELECT COUNT(*) FROM agents = original count
- **Acceptance:** Script tested on staging, restores all original records. Prerequisite: T054 must create agents_backup and agent_chat_history_backup tables before migration.
- **Complexity:** Standard
- **Dependencies:** T054, T055

### 2.2 Migration Execution (Day 18)

**T057** Backup production database
- **File:** Database backup
- **Action:** Create timestamped backup before migration
- **Acceptance:** Backup file created, verified readable
- **Complexity:** Simple
- **Dependencies:** None

**T058** Test migration on staging database
- **File:** Staging database
- **Action:** Run migration script, verify data integrity
- **Acceptance:** All agents and history migrated correctly. Staging verification report reviewed and approved before proceeding to T059.
- **Complexity:** Standard
- **Dependencies:** T054, T055, T057

**T059** Execute migration in production
- **File:** Production database
- **Action:** Run migration script with monitoring
- **Acceptance:** Migration completes successfully, data verified
- **Complexity:** Standard
- **Dependencies:** T058

**T060** Verify migration results
- **File:** Production database
- **Action:** Run verification queries with expected outcomes: (1) SELECT COUNT(*) FROM ai_agents = (SELECT COUNT(*) FROM agents_backup); (2) SELECT COUNT(*) FROM ai_session_messages = (SELECT COUNT(*) FROM agent_chat_history_backup); (3) Zero orphaned sessions: SELECT COUNT(*) FROM ai_agent_sessions WHERE agent_id NOT IN (SELECT id FROM ai_agents) = 0; (4) All agent names preserved: SELECT name FROM agents_backup EXCEPT SELECT name FROM ai_agents = 0 rows
- **Acceptance:** All verification queries pass, no data loss detected
- **Complexity:** Standard
- **Dependencies:** T059

### 2.3 Backend Cleanup (Days 19-20)

**T061** Remove agent module directory
- **File:** `internal/modules/agent/` (delete)
- **Action:** Delete handler.go, service.go, repository.go, orchestrator.go, prompts.go
- **Acceptance:** Directory deleted, no references remain
- **Complexity:** Simple
- **Dependencies:** T060

**T062** Remove agent module registration
- **File:** `internal/bootstrap/app.go`
- **Action:** Remove agent module initialization
- **Acceptance:** Agent module not registered
- **Complexity:** Simple
- **Dependencies:** T061

**T063** Remove legacy agent routes
- **File:** `internal/platform/httpserver/router.go`
- **Action:** Remove /agents route registration
- **Acceptance:** Legacy routes not registered
- **Complexity:** Simple
- **Dependencies:** T062

**T064** Drop legacy database tables
- **File:** `migrations/sqlite/XXX_drop_legacy_agents.sql`
- **Action:** Create migration to drop agents, agent_chat_history tables
- **Acceptance:** Tables dropped after verification period
- **Complexity:** Simple
- **Dependencies:** T060

**T065** Run backend tests
- **File:** Backend codebase
- **Action:** Run go test ./...
- **Acceptance:** All tests pass
- **Complexity:** Standard
- **Dependencies:** T061, T062, T063

### 2.4 Flutter Cleanup (Day 20)

**T066** Remove ai_tutor_team.dart model
- **File:** `apps/flutter_client/lib/models/ai_tutor_team.dart` (delete)
- **Action:** Delete file, remove imports
- **Acceptance:** File deleted, no import errors
- **Complexity:** Simple
- **Dependencies:** None

**T067** Review ai_tutor_team_controller.dart
- **File:** `apps/flutter_client/lib/controllers/ai_tutor_team_controller.dart`
- **Action:** Assess if reusable, delete or refactor
- **Acceptance:** Decision documented, action taken
- **Complexity:** Standard
- **Dependencies:** T066

**T068** Clean up dead imports in api_service.dart
- **File:** `apps/flutter_client/lib/services/api_service.dart`
- **Action:** Remove unused imports
- **Acceptance:** No unused imports remain
- **Complexity:** Simple
- **Dependencies:** T050

**T069** Run Flutter analyze
- **File:** Flutter codebase
- **Action:** Run flutter analyze
- **Acceptance:** No errors or warnings
- **Complexity:** Simple
- **Dependencies:** T066, T067, T068


---

## Phase 3: Enhancement (Weeks 5-6, Days 21-30)

**Goal:** Implement P1 features and optimize user flows
**Effort:** 10 days
**Risk:** Low
**Deliverables:** Prompt template UI, enhanced chat UI, optimized flows, additional components

### 3.1 Prompt Template Management (Days 21-23)

**T070** [P] Create prompt templates screen
- **File:** `apps/flutter_client/lib/screens/prompt_templates_screen.dart`
- **Action:** Create screen with templates list
- **Acceptance:** Displays all templates, supports search
- **Complexity:** Standard
- **Dependencies:** T023, T012

**T071** [P] Implement template detail view
- **File:** `apps/flutter_client/lib/screens/prompt_templates_screen.dart`
- **Action:** Show template content with markdown preview
- **Acceptance:** Displays content, highlights variables
- **Complexity:** Standard
- **Dependencies:** T070

**T072** [P] Implement template editor
- **File:** `apps/flutter_client/lib/screens/prompt_templates_screen.dart`
- **Action:** Add edit mode with markdown editor
- **Acceptance:** Edits template, saves changes
- **Complexity:** Complex
- **Dependencies:** T071, T024

**T073** [P] Add template reload button
- **File:** `apps/flutter_client/lib/screens/prompt_templates_screen.dart`
- **Action:** Add button to reload templates from disk
- **Acceptance:** Triggers reload, shows success message
- **Complexity:** Simple
- **Dependencies:** T070, T025

### 3.2 Enhanced Agent Chat UI (Days 24-25)

**T074** Add message compression button to chat screen
- **File:** `apps/flutter_client/lib/screens/agent_chat_hub_screen.dart`
- **Action:** Add menu item in app bar for compression
- **Acceptance:** Shows confirmation dialog, compresses on confirm
- **Complexity:** Standard
- **Dependencies:** T032

**T075** Implement action confirmation UI
- **File:** `apps/flutter_client/lib/screens/agent_chat_hub_screen.dart`
- **Action:** Show confirmation dialog for agent actions
- **Acceptance:** Displays action details, confirms/rejects
- **Complexity:** Standard
- **Dependencies:** T033

**T076** Add message search to chat
- **File:** `apps/flutter_client/lib/screens/agent_chat_hub_screen.dart`
- **Action:** Add search bar, filter messages by text
- **Acceptance:** Searches message content, highlights results
- **Complexity:** Standard
- **Dependencies:** None

### 3.3 Additional UI Components (Days 26-27)

**T077** [P] Implement AppDialog component
- **File:** `apps/flutter_client/lib/widgets/common/app_dialog.dart`
- **Action:** Create consistent dialog with title, content, actions
- **Acceptance:** Supports custom content, action buttons
- **Complexity:** Standard
- **Dependencies:** T009, T010

**T078** [P] Implement AppBottomSheet component
- **File:** `apps/flutter_client/lib/widgets/common/app_bottom_sheet.dart`
- **Action:** Create modal bottom sheet with consistent styling
- **Acceptance:** Supports custom content, drag to dismiss
- **Complexity:** Standard
- **Dependencies:** T009

### 3.4 User Flow Optimization (Days 28-30)

**T079** [P] Optimize practice session flow
- **File:** `apps/flutter_client/lib/screens/practice_session_screen.dart`
- **Action:** Combine answer and grade screens
- **Acceptance:** Reduces from 4 to 3 screens, maintains functionality
- **Complexity:** Complex
- **Dependencies:** None

**T080** [P] Add progress indicator to practice session
- **File:** `apps/flutter_client/lib/screens/practice_session_screen.dart`
- **Action:** Show question progress (e.g., "3 of 10")
- **Acceptance:** Displays current question number and total
- **Complexity:** Simple
- **Dependencies:** None

**T081** [P] Add quick retry on wrong answers
- **File:** `apps/flutter_client/lib/screens/practice_session_screen.dart`
- **Action:** Show retry button after incorrect answer
- **Acceptance:** Allows immediate retry without navigation
- **Complexity:** Standard
- **Dependencies:** None

**T082** [P] Implement skeleton screens for list views
- **File:** `apps/flutter_client/lib/widgets/common/app_skeleton.dart`
- **Action:** Create skeleton loader for list items
- **Acceptance:** Shows placeholder while loading
- **Complexity:** Standard
- **Dependencies:** T009


---

## Phase 4: Documentation (Week 7, Days 31-35)

**Goal:** Complete API documentation and migration guides
**Effort:** 5 days
**Risk:** Low
**Deliverables:** OpenAPI spec, API docs, migration guides, updated README

### 4.1 OpenAPI Specification (Days 31-32)

**T083** [P] Create OpenAPI spec structure
- **File:** `docs/openapi.yaml`
- **Action:** Create base OpenAPI 3.0 structure with info, servers
- **Acceptance:** Valid OpenAPI 3.0 YAML file
- **Complexity:** Simple
- **Dependencies:** None

**T084** [P] Document AI module endpoints
- **File:** `docs/openapi.yaml`
- **Action:** Add all /ai/* endpoints with request/response schemas
- **Acceptance:** All AI endpoints documented with examples
- **Complexity:** Complex
- **Dependencies:** T083

**T085** [P] Document other module endpoints
- **File:** `docs/openapi.yaml`
- **Action:** Add questions, practice, plans, mistakes, etc. endpoints
- **Acceptance:** All active endpoints documented
- **Complexity:** Complex
- **Dependencies:** T083

**T086** [P] Add error codes reference to OpenAPI
- **File:** `docs/openapi.yaml`
- **Action:** Document all error codes in components/schemas
- **Acceptance:** Error codes with descriptions documented
- **Complexity:** Simple
- **Dependencies:** T001

### 4.2 Migration Guides (Day 33)

**T087** [P] Create agent migration guide
- **File:** `docs/migration-agent-consolidation.md`
- **Action:** Document migration from /agents to /ai/agents
- **Acceptance:** Step-by-step guide with code examples
- **Complexity:** Standard
- **Dependencies:** T053

**T088** [P] Create data migration guide
- **File:** `docs/migration-agent-consolidation.md`
- **Action:** Document database migration process
- **Acceptance:** Includes backup, migration, rollback procedures
- **Complexity:** Standard
- **Dependencies:** T054, T055, T056

### 4.3 Project Documentation (Days 34-35)

**T089** [P] Update main README
- **File:** `README.md`
- **Action:** Update architecture section, add component library info
- **Acceptance:** README reflects current architecture
- **Complexity:** Standard
- **Dependencies:** None

**T090** [P] Update Flutter client README
- **File:** `apps/flutter_client/README.md`
- **Action:** Document new components, API methods
- **Acceptance:** README includes component usage examples
- **Complexity:** Standard
- **Dependencies:** T008

**T091** [P] Create developer onboarding guide
- **File:** `docs/developer-onboarding.md`
- **Action:** Document setup, architecture, development workflow
- **Acceptance:** New developers can set up project from guide
- **Complexity:** Standard
- **Dependencies:** None

**T092** [P] Add inline code documentation
- **File:** Various files
- **Action:** Add JSDoc/Dartdoc comments to new components and methods
- **Acceptance:** All public APIs documented
- **Complexity:** Standard
- **Dependencies:** None

---

## Risk Assessment & Mitigation

### High-Risk Tasks

| Task | Risk | Impact | Mitigation |
|------|------|--------|------------|
| T054-T060 | Data loss during migration | Critical | Backup before migration, test on staging, rollback script ready |
| T050 | Breaking changes in Flutter | High | Thorough testing, feature flags, gradual rollout |
| T061-T065 | Backend instability | High | Comprehensive tests, monitoring, rollback plan |
| T079 | UX regression | Medium | User testing, A/B testing, feedback collection |

### Rollback Procedures

**Phase 1 Rollback:**
- Revert Flutter to legacy /agents endpoints (T050)
- Remove deprecation warnings (T051)
- Keep both systems running

**Phase 2 Rollback:**
- Execute rollback script (T056)
- Restore database from backup (T057)
- Re-enable legacy agent module (T061-T063)

**Phase 3 Rollback:**
- Revert UI changes via Git
- Restore previous API service version

---

## Parallel Execution Opportunities

### Phase 0 (8 parallel tasks)
- T001, T002, T003 (API standards)
- T006, T007 (Error handling)
- T008, T009 (Component setup)

### Phase 1 (12 parallel tasks)
- T016, T017, T018, T019 (Models)
- T023, T024, T025 (Prompt templates)
- T029, T030, T031 (Artifacts)
- T034, T035, T036, T037 (Lessons)

### Phase 3 (14 parallel tasks)
- T070, T071, T072, T073 (Templates)
- T077, T078 (Components)
- T079, T080, T081, T082 (Flow optimization)

### Phase 4 (10 parallel tasks)
- T083, T084, T085, T086 (OpenAPI)
- T087, T088 (Migration guides)
- T089, T090, T091, T092 (Documentation)

**Total Parallel Tasks:** 44 out of 92 tasks (48%)

---

## Success Metrics

### Technical Metrics
- **Code Quality:** Test coverage >80% for new code
- **Performance:** API response time <200ms (p95)
- **Maintainability:** Module count reduced from 13 to 12
- **Documentation:** 100% API coverage in OpenAPI spec

### User Experience Metrics
- **Feature Completeness:** All backend features have UI (100%)
- **Missing Integrations:** 0 (down from 12)
- **Practice Flow:** Reduced from 4 to 3 screens
- **Error Recovery:** >90% success rate

### Development Velocity
- **Component Reuse:** 8 standardized components created
- **Onboarding Time:** -50% with documentation
- **Bug Reports:** <5 per week post-launch

---

## Execution Strategy for Ralph + Ultrawork

### Task Assignment Rules

1. **Simple tasks (1-2 hours):** Execute immediately
2. **Standard tasks (2-4 hours):** Break into subtasks if >3 hours
3. **Complex tasks (4-8 hours):** Mandatory breakdown into atomic steps

### Verification Requirements

**After each task:**
- Run relevant tests (go test, flutter analyze)
- Verify acceptance criteria met
- Document any deviations

**After each phase:**
- Full test suite (backend + Flutter)
- Manual smoke testing of affected features
- Update progress in `.omc/plans/progress.md`

### Checkpoint Strategy

**Phase 0 Checkpoint:** All components render correctly
**Phase 1 Checkpoint:** All API methods return expected data
**Phase 2 Checkpoint:** Migration verified, legacy code removed
**Phase 3 Checkpoint:** All P1 features functional
**Phase 4 Checkpoint:** Documentation complete and accurate

---

## Task Summary

**Total Tasks:** 92
**Parallel Tasks:** 44 (48%)
**Sequential Tasks:** 48 (52%)

**By Complexity:**
- Simple: 38 tasks (41%)
- Standard: 42 tasks (46%)
- Complex: 12 tasks (13%)

**By Phase:**
- Phase 0: 15 tasks (5 days)
- Phase 1: 38 tasks (10 days)
- Phase 2: 16 tasks (5 days)
- Phase 3: 13 tasks (10 days)
- Phase 4: 10 tasks (5 days)

**Critical Path Duration:** 35 days (7 weeks)
**With Parallelization:** ~28 days (5.6 weeks estimated)

---

## Next Steps

1. Review and approve this implementation plan
2. Set up progress tracking in `.omc/plans/progress.md`
3. Initialize Ralph + Ultrawork with Phase 0 tasks
4. Execute phases sequentially with checkpoints
5. Monitor progress and adjust as needed

**Ready for execution.**

