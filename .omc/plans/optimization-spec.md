# Self-Study-Tool Optimization Specification

**Version:** 1.0
**Date:** 2026-03-12
**Status:** Draft

## Executive Summary

This specification addresses critical architectural issues in the PRTS (Personal Research & Training System) project, focusing on frontend-backend alignment, deprecated code cleanup, and UI/UX standardization. The project currently suffers from module duplication (`agent/` vs `ai/agents`), incomplete Flutter integration with backend APIs, and missing UI for several backend features.

## 1. Current State Analysis

### 1.1 Architecture Overview

**Backend (Go):**
- Modular architecture with 13+ domain modules
- Dual agent systems: `internal/modules/agent` (legacy) and `internal/modules/ai` (current)
- RESTful API with Chi router
- SQLite database with migration support

**Frontend (Flutter):**
- Cross-platform client (Android, iOS, Web, Desktop)
- Provider-based state management
- Single `ApiService` class handling all HTTP communication
- Limited integration with newer backend features

### 1.2 Identified Issues

#### Critical Issues (P0)
1. **Agent Module Duplication**: Two separate agent implementations causing confusion and maintenance overhead
   - `internal/modules/agent/`: Legacy system with 5 files, basic CRUD operations
   - `internal/modules/ai/`: Modern system with 40+ files, advanced features (artifacts, compression, tool loop)

2. **Missing Flutter Integration**: Backend endpoints without Flutter client support
   - AI provider configuration (`/ai/provider/config`)
   - Prompt template management (`/ai/prompts`)
   - Agent artifacts (`/ai/sessions/{id}/artifacts`)
   - Session compression (`/ai/sessions/{id}/compress`)
   - Course schedule lessons (partial integration)

3. **Inconsistent Error Handling**: No standardized error format between backend and Flutter

#### High Priority Issues (P1)
4. **UI Component Fragmentation**: Inconsistent patterns across screens
5. **Dead Code**: Unused endpoints and database tables
6. **Missing API Documentation**: No OpenAPI/Swagger specification

## 2. Frontend-Backend Alignment

### 2.1 API Gap Analysis

**Backend Endpoints Missing Flutter Integration:**

| Endpoint | Method | Purpose | Priority | Complexity |
|----------|--------|---------|----------|------------|
| `/ai/provider/config` | PUT | Update AI provider settings | P0 | Low |
| `/ai/provider/default-agent` | GET | Get default agent provider | P0 | Low |
| `/ai/prompts` | GET | List prompt templates | P1 | Low |
| `/ai/prompts/{key}` | PUT | Update prompt template | P1 | Medium |
| `/ai/prompts/reload` | POST | Reload templates from disk | P2 | Low |
| `/ai/agents/{id}/sessions` | GET | List agent sessions | P0 | Low |
| `/ai/sessions/{id}/artifacts` | GET | List session artifacts | P0 | Medium |
| `/ai/sessions/{id}/compress` | POST | Compress message history | P1 | Medium |
| `/ai/sessions/{id}/confirm` | POST | Confirm agent action | P0 | High |
| `/ai/artifacts/{id}/import/questions` | POST | Import questions from artifact | P1 | Medium |
| `/ai/artifacts/{id}/import/plan` | POST | Import plan from artifact | P1 | Medium |
| `/ai/course-schedule/lessons` | GET/POST/PUT/DELETE | CRUD for lessons | P0 | Medium |

**Flutter Methods Missing Backend Support:**
- None identified (Flutter is behind backend)

### 2.2 API Contract Standards

**Proposed Standards:**

1. **Versioning Strategy**: URL-based versioning (`/api/v1/...`)
   - Current: No versioning (implicit v1)
   - Migration: Add `/api/v1` prefix to all routes
   - Timeline: Phase 2 (non-breaking)

2. **Error Response Format**:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable error message",
    "details": {
      "field": "email",
      "reason": "invalid_format"
    },
    "trace_id": "uuid-v4"
  }
}
```

3. **Pagination Standard**:
```json
{
  "data": [...],
  "pagination": {
    "cursor": "next_cursor_value",
    "has_more": true,
    "limit": 20
  }
}
```

4. **Success Response Format**:
```json
{
  "data": {...},
  "meta": {
    "timestamp": "2026-03-12T03:51:00Z",
    "trace_id": "uuid-v4"
  }
}
```

### 2.3 Data Model Synchronization

**Misaligned Models:**

1. **Agent Model**:
   - Backend: `id` (string UUID), `name`, `description`, `system_prompt`, `model`, `temperature`, `created_at`
   - Flutter: `id`, `name`, `type`, `subject`, `promptTemplateId` (legacy fields)
   - **Action**: Update Flutter model to match backend schema

2. **Session Model**:
   - Backend: Full session with artifacts, schedule binding, compression state
   - Flutter: Minimal session (id, agent_id, created_at only)
   - **Action**: Add missing fields to Flutter model

3. **Artifact Model**:
   - Backend: Exists with full schema
   - Flutter: Not implemented
   - **Action**: Create Flutter artifact model

## 3. Deprecated Feature Cleanup

### 3.1 Agent Module Consolidation

**Problem**: Two agent implementations with overlapping functionality

**Legacy Module** (`internal/modules/agent/`):
- Files: `handler.go`, `service.go`, `repository.go`, `orchestrator.go`, `prompts.go`
- Routes: `/agents`, `/agents/{type}`, `/agents/{id}/dispatch`, `/agents/{id}/history`
- Features: Basic CRUD, simple dispatch, chat history
- Database: Uses `agents` table with legacy schema

**Modern Module** (`internal/modules/ai/`):
- Files: 40+ files including agent_service.go, agent_handler.go, agent_chat_store.go
- Routes: `/ai/agents`, `/ai/agents/{id}/sessions`, `/ai/sessions/{id}/messages`
- Features: Advanced chat, artifacts, compression, tool loop, schedule binding
- Database: Uses `ai_agents`, `ai_agent_sessions`, `ai_session_messages`, `ai_session_artifacts`

**Resolution Strategy**:

1. **Phase 1: Deprecation** (Week 1)
   - Add deprecation warnings to legacy `/agents` endpoints
   - Update Flutter to use `/ai/agents` endpoints exclusively
   - Add migration guide in API docs

2. **Phase 2: Data Migration** (Week 2)
   - Create migration script to move legacy agent data to new schema
   - Preserve chat history by converting to new message format
   - Backup legacy tables before migration

3. **Phase 3: Removal** (Week 3)
   - Remove `internal/modules/agent/` directory
   - Drop legacy database tables
   - Remove legacy routes from router

**Migration Script Outline**:
```sql
-- Migrate agents
INSERT INTO ai_agents (id, name, description, system_prompt, model, temperature)
SELECT uuid(), name, '', prompt_template, 'claude-3-5-sonnet-20241022', 0.7
FROM agents WHERE NOT EXISTS (SELECT 1 FROM ai_agents WHERE name = agents.name);

-- Migrate chat history to sessions
-- (Detailed implementation in migration file)
```

### 3.2 Dead Code Identification

**Unused Backend Endpoints** (to verify and remove):
- `/agents/head-teacher` - No Flutter usage found
- `/agents/subject` - No Flutter usage found
- `/agents/{id}/bind-schedule` - Replaced by `/ai/sessions/{id}/schedule-binding`

**Orphaned Database Tables** (to verify):
- Check for tables without corresponding Go models
- Verify migration files are all applied

**Unused Flutter Code**:
- `lib/models/ai_tutor_team.dart` - Legacy team model, replaced by agent sessions
- Dead imports in `api_service.dart`

### 3.3 Cleanup Checklist

- [ ] Audit all `/agents` endpoint usage in Flutter
- [ ] Migrate Flutter to `/ai/agents` endpoints
- [ ] Run data migration script
- [ ] Remove `internal/modules/agent/` directory
- [ ] Drop legacy database tables
- [ ] Remove unused Flutter models
- [ ] Update API documentation

## 4. UI/UX Optimization

### 4.1 Component Standardization

**Current State**: Inconsistent UI patterns across screens
- Some screens use custom widgets, others use raw Material components
- Inconsistent loading states (CircularProgressIndicator vs custom loaders)
- Mixed error handling approaches (SnackBar, Dialog, inline messages)

**Proposed Component Library**:

1. **Core Components** (Priority: P0)
   - `AppButton` - Standardized button with loading state
   - `AppTextField` - Consistent text input with validation
   - `AppCard` - Unified card design
   - `AppLoadingIndicator` - Consistent loading UI
   - `AppErrorView` - Standardized error display
   - `AppEmptyState` - Empty state placeholder

2. **Composite Components** (Priority: P1)
   - `AppListTile` - Enhanced list item
   - `AppBottomSheet` - Modal bottom sheet
   - `AppDialog` - Consistent dialog design
   - `AppAppBar` - Standardized app bar

3. **Domain Components** (Priority: P1)
   - `QuestionCard` - Display question items
   - `PracticeSessionCard` - Practice session summary
   - `AgentChatBubble` - Chat message display
   - `ScheduleLessonCard` - Course lesson item

**Implementation Location**: `lib/widgets/common/`

### 4.2 Error Handling Enhancement

**Current Issues**:
- No centralized error handling
- Inconsistent error messages
- No retry mechanism for failed requests

**Proposed Solution**:

1. **Error Mapper Enhancement** (`lib/i18n/error_mapper.dart`):
   - Map backend error codes to user-friendly messages
   - Support for multiple languages
   - Context-aware error messages

2. **Retry Logic**:
   - Automatic retry for network failures (exponential backoff)
   - Manual retry button for user-triggered actions
   - Offline queue for critical operations

3. **Error UI Patterns**:
   - Inline errors for form validation
   - Toast/SnackBar for transient errors
   - Full-screen error view for critical failures
   - Retry button for recoverable errors

### 4.3 Loading State Improvements

**Current Issues**:
- Blocking full-screen loaders
- No progress indication for long operations
- No cancellation support

**Proposed Improvements**:

1. **Progressive Loading**:
   - Skeleton screens for list views
   - Shimmer effect for loading content
   - Partial content display (load as data arrives)

2. **Progress Indication**:
   - Percentage progress for file uploads
   - Step indicators for multi-step processes
   - Estimated time remaining for long operations

3. **Cancellation Support**:
   - Cancel button for long-running operations
   - Proper cleanup of cancelled requests
   - User feedback on cancellation

### 4.4 Missing UI Features

**Backend Features Without UI**:

1. **AI Provider Configuration** (P0)
   - **Backend**: `/ai/provider/config` (PUT), `/ai/provider` (GET)
   - **UI Needed**: Settings screen section for API keys, model selection, temperature
   - **Location**: `lib/screens/settings_screen.dart` - Add "AI Provider" section
   - **Complexity**: Low (form with text fields and dropdowns)

2. **Prompt Template Management** (P1)
   - **Backend**: `/ai/prompts` (GET), `/ai/prompts/{key}` (PUT)
   - **UI Needed**: New screen to view/edit prompt templates
   - **Location**: New `lib/screens/prompt_templates_screen.dart`
   - **Complexity**: Medium (list + detail view with markdown editor)

3. **Session Artifacts** (P0)
   - **Backend**: `/ai/sessions/{id}/artifacts` (GET)
   - **UI Needed**: Artifacts tab in agent chat screen
   - **Location**: `lib/screens/agent_chat_hub_screen.dart` - Add artifacts view
   - **Complexity**: Medium (list with preview, import actions)

4. **Message Compression** (P1)
   - **Backend**: `/ai/sessions/{id}/compress` (POST)
   - **UI Needed**: Button in chat screen to compress history
   - **Location**: `lib/screens/agent_chat_hub_screen.dart` - Add to app bar menu
   - **Complexity**: Low (button + confirmation dialog)

5. **Course Schedule Lessons** (P0)
   - **Backend**: Full CRUD at `/ai/course-schedule/lessons`
   - **UI Needed**: Complete lesson management UI
   - **Location**: `lib/screens/course_schedule/` - Enhance existing screens
   - **Complexity**: High (CRUD operations, lesson details, scheduling)

### 4.5 User Flow Improvements

**Core Feature Flows to Optimize**:

1. **Practice Session Flow**:
   - Current: Questions → Answer → Grade → Results (4 screens)
   - Improved: Streamline to 3 screens, add progress indicator
   - Add: Quick retry on wrong answers, bookmark questions

2. **Learning Plan Creation**:
   - Current: Manual form entry
   - Improved: AI-assisted plan generation with templates
   - Add: Import from course schedule, duplicate existing plans

3. **Agent Chat Flow**:
   - Current: Basic chat interface
   - Improved: Add artifacts panel, action confirmation UI
   - Add: Message search, export conversation, attach files

## 5. Technical Approach

### 5.1 Prioritization Strategy

**Phase 0: Foundation** (Week 1)
- Establish API contract standards
- Create Flutter component library (core components only)
- Implement standardized error handling

**Phase 1: Critical Alignment** (Week 2-3)
- Migrate Flutter from legacy `/agents` to `/ai/agents`
- Implement missing P0 API integrations (provider config, artifacts, lessons)
- Add UI for provider configuration

**Phase 2: Cleanup** (Week 4)
- Execute agent module consolidation
- Remove dead code and unused endpoints
- Data migration for legacy agents

**Phase 3: Enhancement** (Week 5-6)
- Implement P1 features (prompt templates, compression)
- Optimize user flows
- Add missing UI components

**Phase 4: Documentation** (Week 7)
- Generate OpenAPI specification
- Update API documentation
- Create migration guides

### 5.2 Backward Compatibility

**Breaking Changes to Avoid**:
- Keep legacy `/agents` endpoints during migration period (deprecate, don't remove immediately)
- Maintain existing Flutter API method signatures
- Database migrations must be reversible

**Deprecation Strategy**:
1. Add `X-Deprecated: true` header to legacy endpoints
2. Log warnings when legacy endpoints are used
3. Provide 2-week notice before removal
4. Ensure all Flutter clients updated before removal

### 5.3 Incremental Refactoring

**Approach**:
- Strangler Fig Pattern: Build new alongside old, gradually migrate
- Feature flags for new UI components (enable/disable during testing)
- Parallel API implementations during transition

**Risk Mitigation**:
- Comprehensive integration tests for critical paths
- Staged rollout (dev → staging → production)
- Rollback plan for each phase

### 5.4 Testing Strategy

**Backend Testing**:
- Unit tests for new API endpoints (target: 80% coverage)
- Integration tests for agent module migration
- Load testing for AI streaming endpoints

**Flutter Testing**:
- Widget tests for new UI components
- Integration tests for critical user flows
- Manual testing on all platforms (Android, iOS, Web, Desktop)

**Test Priorities**:
1. Agent chat functionality (P0)
2. Practice session flow (P0)
3. Course schedule management (P0)
4. Provider configuration (P1)
5. Prompt template management (P2)

## 6. Deliverables

### 6.1 Updated API Service Layer

**File**: `apps/flutter_client/lib/services/api_service.dart`

**New Methods to Add**:
```dart
// Provider configuration
Future<Map<String, dynamic>> getProviderStatus();
Future<Map<String, dynamic>> getDefaultAgentProvider();
Future<void> updateProviderConfig(Map<String, dynamic> config);

// Prompt templates
Future<List<PromptTemplate>> listPromptTemplates();
Future<PromptTemplate> updatePromptTemplate(String key, Map<String, dynamic> data);
Future<void> reloadPromptTemplates();

// Agent sessions
Future<List<AgentSession>> listAgentSessions(String agentId, {int? limit, String? cursor});
Future<AgentSession> createAgentSession(String agentId, {String? title});
Future<void> deleteAgentSession(String sessionId);

// Session artifacts
Future<List<Artifact>> listSessionArtifacts(String sessionId, {String? status});
Future<Map<String, dynamic>> importQuestionsFromArtifact(String artifactId, Map<String, dynamic> request);
Future<Map<String, dynamic>> importPlanFromArtifact(String artifactId, Map<String, dynamic> request);

// Session operations
Future<Map<String, dynamic>> compressSessionMessages(String sessionId, {int? targetCount});
Future<Map<String, dynamic>> confirmSessionAction(String sessionId, Map<String, dynamic> request);

// Course schedule lessons
Future<List<CourseLesson>> listCourseScheduleLessons({String? scheduleId});
Future<CourseLesson> createCourseScheduleLesson(Map<String, dynamic> data);
Future<CourseLesson> updateCourseScheduleLesson(int id, Map<String, dynamic> data);
Future<void> deleteCourseScheduleLesson(int id);
```

**Refactoring Tasks**:
- Remove legacy agent methods (migrate to AI module endpoints)
- Standardize error handling with `ApiException`
- Add request/response logging for debugging
- Implement retry logic for transient failures

### 6.2 Standardized UI Components Library

**Location**: `apps/flutter_client/lib/widgets/common/`

**Components to Create**:

1. **app_button.dart** - Standardized button with loading state
2. **app_text_field.dart** - Consistent text input with validation
3. **app_card.dart** - Unified card design
4. **app_loading_indicator.dart** - Consistent loading UI
5. **app_error_view.dart** - Standardized error display
6. **app_empty_state.dart** - Empty state placeholder
7. **app_dialog.dart** - Consistent dialog design
8. **app_bottom_sheet.dart** - Modal bottom sheet

**Design Tokens** (`lib/theme/app_theme.dart`):
```dart
// Colors
static const primaryColor = Color(0xFF2196F3);
static const errorColor = Color(0xFFE53935);
static const successColor = Color(0xFF43A047);

// Spacing
static const spacingXs = 4.0;
static const spacingS = 8.0;
static const spacingM = 16.0;
static const spacingL = 24.0;
static const spacingXl = 32.0;

// Border radius
static const radiusS = 4.0;
static const radiusM = 8.0;
static const radiusL = 16.0;
```

### 6.3 Deprecated Code Removal Plan

**Backend Removal**:
```
internal/modules/agent/
├── handler.go          [DELETE]
├── service.go          [DELETE]
├── repository.go       [DELETE]
├── orchestrator.go     [DELETE]
└── prompts.go          [DELETE]
```

**Database Cleanup**:
```sql
-- After migration, drop legacy tables
DROP TABLE IF EXISTS agents;
DROP TABLE IF EXISTS agent_chat_history;
DROP TABLE IF EXISTS agent_schedules;
```

**Flutter Cleanup**:
```
lib/models/ai_tutor_team.dart    [DELETE - replaced by agent sessions]
lib/controllers/ai_tutor_team_controller.dart    [REVIEW - may be reusable]
```

**Router Cleanup** (`internal/platform/httpserver/router.go`):
- Remove agent module registration
- Keep only AI module routes

### 6.4 API Documentation (OpenAPI Spec)

**File**: `docs/openapi.yaml`

**Structure**:
```yaml
openapi: 3.0.0
info:
  title: PRTS API
  version: 1.0.0
  description: Personal Research & Training System API

servers:
  - url: http://localhost:8080
    description: Local development

paths:
  /ai/agents:
    get:
      summary: List all agents
      tags: [Agents]
      responses:
        200:
          description: Success
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Agent'
    post:
      summary: Create new agent
      tags: [Agents]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UpsertAgentRequest'
      responses:
        201:
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Agent'

components:
  schemas:
    Agent:
      type: object
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
        description:
          type: string
        system_prompt:
          type: string
        model:
          type: string
        temperature:
          type: number
        created_at:
          type: string
          format: date-time
```

**Generation Tool**: Use `swag` (Swagger for Go) or manual YAML creation

**Documentation Sections**:
1. Authentication (if applicable)
2. Error codes reference
3. Rate limiting (if applicable)
4. Pagination patterns
5. Streaming endpoints
6. Webhook events (if applicable)

## 7. Implementation Roadmap

### 7.1 Phase 0: Foundation (Week 1)

**Goals**: Establish standards and core infrastructure

**Tasks**:
- [ ] Define and document API contract standards (error format, pagination, versioning)
- [ ] Create Flutter component library structure (`lib/widgets/common/`)
- [ ] Implement core components: AppButton, AppTextField, AppCard, AppLoadingIndicator
- [ ] Enhance error mapper with backend error code mapping
- [ ] Add retry logic to ApiService

**Deliverables**:
- API standards document
- 4 core UI components
- Enhanced error handling

**Risk**: Low
**Effort**: 3 days

### 7.2 Phase 1: Critical Alignment (Week 2-3)

**Goals**: Integrate missing P0 features and migrate from legacy agent system

**Tasks**:
- [ ] Add new API methods to ApiService (provider config, sessions, artifacts, lessons)
- [ ] Create Flutter models: AgentSession, Artifact, PromptTemplate
- [ ] Implement provider configuration UI in settings screen
- [ ] Add artifacts panel to agent chat screen
- [ ] Implement course schedule lesson CRUD UI
- [ ] Migrate all Flutter agent calls from `/agents` to `/ai/agents`
- [ ] Add deprecation warnings to legacy backend endpoints

**Deliverables**:
- 12 new API methods in ApiService
- 3 new Flutter models
- Provider config UI
- Artifacts UI
- Enhanced course schedule UI

**Risk**: Medium (breaking changes possible)
**Effort**: 8 days

### 7.3 Phase 2: Cleanup (Week 4)

**Goals**: Remove deprecated code and consolidate agent modules

**Tasks**:
- [ ] Create data migration script for legacy agents
- [ ] Test migration script on staging database
- [ ] Execute migration in production
- [ ] Remove `internal/modules/agent/` directory
- [ ] Drop legacy database tables
- [ ] Remove unused Flutter models (ai_tutor_team.dart)
- [ ] Clean up dead imports and unused code

**Deliverables**:
- Migration script
- Cleaned codebase (5 files removed)
- Migration documentation

**Risk**: High (data migration)
**Effort**: 4 days

### 7.4 Phase 3: Enhancement (Week 5-6)

**Goals**: Implement P1 features and optimize user flows

**Tasks**:
- [ ] Implement prompt template management UI (new screen)
- [ ] Add message compression UI to agent chat
- [ ] Implement action confirmation UI for agent operations
- [ ] Optimize practice session flow (reduce from 4 to 3 screens)
- [ ] Add progress indicators to multi-step processes
- [ ] Implement skeleton screens for list views
- [ ] Add message search to agent chat
- [ ] Create remaining UI components (AppDialog, AppBottomSheet, AppEmptyState)

**Deliverables**:
- Prompt template management screen
- Enhanced agent chat UI
- Optimized practice flow
- 3 additional UI components

**Risk**: Low
**Effort**: 8 days

### 7.5 Phase 4: Documentation (Week 7)

**Goals**: Complete API documentation and migration guides

**Tasks**:
- [ ] Generate OpenAPI specification (openapi.yaml)
- [ ] Document all API endpoints with examples
- [ ] Create migration guide for legacy agent system
- [ ] Update README with new architecture
- [ ] Add inline code documentation
- [ ] Create developer onboarding guide

**Deliverables**:
- OpenAPI specification
- API documentation
- Migration guides
- Updated README

**Risk**: Low
**Effort**: 3 days

## 8. Risk Assessment & Mitigation

### 8.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Data loss during agent migration | Medium | Critical | Backup before migration, test on staging, rollback plan |
| Breaking changes affect production users | Medium | High | Deprecation period, parallel endpoints, feature flags |
| Performance degradation with new UI | Low | Medium | Performance testing, lazy loading, code splitting |
| API contract changes break Flutter | Low | High | Versioned APIs, backward compatibility layer |
| Integration test failures | Medium | Medium | Comprehensive test coverage, CI/CD validation |

### 8.2 Project Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Scope creep | High | Medium | Strict phase boundaries, defer P2 features |
| Timeline delays | Medium | Medium | Buffer time in each phase, parallel work streams |
| Resource constraints | Low | High | Prioritize P0 features, defer nice-to-haves |
| Incomplete requirements | Medium | Medium | Regular stakeholder reviews, iterative approach |

### 8.3 Rollback Strategy

**Phase 1 Rollback**:
- Revert Flutter to legacy `/agents` endpoints
- Remove deprecation warnings
- Keep both systems running

**Phase 2 Rollback**:
- Restore database from backup
- Revert migration script
- Re-enable legacy agent module

**Phase 3 Rollback**:
- Revert UI changes via Git
- Restore previous API service version

## 9. Success Metrics

### 9.1 Technical Metrics

- **Code Quality**:
  - Test coverage: >80% for new code
  - Zero critical bugs in production
  - Reduced code duplication: -30%

- **Performance**:
  - API response time: <200ms (p95)
  - Flutter app startup: <2s
  - UI frame rate: 60fps maintained

- **Maintainability**:
  - Reduced module count: 13 → 12 (remove agent module)
  - Standardized components: 8 core components created
  - API documentation coverage: 100%

### 9.2 User Experience Metrics

- **Feature Completeness**:
  - All backend features have UI: 100%
  - Missing API integrations: 0

- **Usability**:
  - Reduced practice session steps: 4 → 3
  - Error recovery rate: >90%
  - User-reported bugs: <5 per week

### 9.3 Development Velocity

- **Delivery**:
  - All phases completed on time
  - Zero rollbacks required
  - Documentation complete

- **Team Efficiency**:
  - Reduced onboarding time: -50%
  - Faster feature development with component library
  - Fewer support tickets

## 10. Appendix

### 10.1 File Structure Changes

**New Files**:
```
apps/flutter_client/lib/
├── models/
│   ├── agent_session.dart          [NEW]
│   ├── artifact.dart                [NEW]
│   └── prompt_template.dart         [NEW]
├── screens/
│   └── prompt_templates_screen.dart [NEW]
└── widgets/common/
    ├── app_button.dart              [NEW]
    ├── app_text_field.dart          [NEW]
    ├── app_card.dart                [NEW]
    ├── app_loading_indicator.dart   [NEW]
    ├── app_error_view.dart          [NEW]
    ├── app_empty_state.dart         [NEW]
    ├── app_dialog.dart              [NEW]
    └── app_bottom_sheet.dart        [NEW]

docs/
└── openapi.yaml                     [NEW]
```

**Modified Files**:
```
apps/flutter_client/lib/
├── services/api_service.dart        [MAJOR UPDATE]
├── screens/settings_screen.dart     [UPDATE - add provider config]
├── screens/agent_chat_hub_screen.dart [UPDATE - add artifacts panel]
└── screens/course_schedule/course_schedule_screen.dart [UPDATE - lesson CRUD]

internal/
├── bootstrap/app.go                 [UPDATE - remove agent module]
└── platform/httpserver/router.go    [UPDATE - remove agent routes]
```

**Deleted Files**:
```
internal/modules/agent/
├── handler.go                       [DELETE]
├── service.go                       [DELETE]
├── repository.go                    [DELETE]
├── orchestrator.go                  [DELETE]
└── prompts.go                       [DELETE]

apps/flutter_client/lib/
└── models/ai_tutor_team.dart        [DELETE]
```

### 10.2 Database Migration Script

**File**: `migrations/sqlite/XXX_consolidate_agents.sql`

```sql
-- Backup legacy data
CREATE TABLE agents_backup AS SELECT * FROM agents;
CREATE TABLE agent_chat_history_backup AS SELECT * FROM agent_chat_history;

-- Migrate agents to new schema
INSERT INTO ai_agents (id, name, description, system_prompt, model, temperature, created_at, updated_at)
SELECT
    lower(hex(randomblob(16))),
    name,
    COALESCE(subject, ''),
    COALESCE(prompt_template, ''),
    'claude-3-5-sonnet-20241022',
    0.7,
    created_at,
    updated_at
FROM agents
WHERE NOT EXISTS (
    SELECT 1 FROM ai_agents WHERE ai_agents.name = agents.name
);

-- Migrate chat history to sessions and messages
-- (Implementation depends on legacy schema structure)

-- After verification, drop legacy tables
-- DROP TABLE agents;
-- DROP TABLE agent_chat_history;
-- DROP TABLE agent_schedules;
```

### 10.3 API Error Codes Reference

| Code | HTTP Status | Description | User Action |
|------|-------------|-------------|-------------|
| `VALIDATION_ERROR` | 400 | Invalid request data | Check input format |
| `NOT_FOUND` | 404 | Resource not found | Verify ID/URL |
| `UNAUTHORIZED` | 401 | Authentication required | Login again |
| `FORBIDDEN` | 403 | Insufficient permissions | Contact admin |
| `CONFLICT` | 409 | Resource already exists | Use different name |
| `RATE_LIMIT` | 429 | Too many requests | Wait and retry |
| `INTERNAL_ERROR` | 500 | Server error | Contact support |
| `SERVICE_UNAVAILABLE` | 503 | Service temporarily down | Retry later |

### 10.4 Component Usage Examples

**AppButton**:
```dart
AppButton(
  text: 'Submit',
  onPressed: () async {
    // Action
  },
  isLoading: isSubmitting,
  variant: ButtonVariant.primary,
)
```

**AppErrorView**:
```dart
AppErrorView(
  error: error,
  onRetry: () => _loadData(),
  showRetryButton: true,
)
```

**AppLoadingIndicator**:
```dart
AppLoadingIndicator(
  message: 'Loading agents...',
  showProgress: true,
  progress: 0.6,
)
```

---

## Summary

This specification provides a comprehensive plan to optimize the Self-Study-Tool project by:

1. **Aligning frontend and backend** through 12 new API integrations and standardized contracts
2. **Eliminating technical debt** by consolidating duplicate agent modules and removing dead code
3. **Improving user experience** with 8 standardized UI components and optimized workflows
4. **Ensuring maintainability** through complete API documentation and migration guides

The 7-week phased approach prioritizes high-impact, low-risk changes while maintaining backward compatibility. Success metrics focus on code quality, performance, and user satisfaction.

**Next Steps**: Review and approve this specification, then proceed with Phase 0 implementation.
