# Course Schedule Migration Specification

**Date:** 2026-03-12
**Goal:** Migrate Flutter course schedule from hardcoded templates to server-managed AI-controllable system

---

## Decision: Use AI Course Schedule System

After analysis, the project has TWO schedule systems:
1. Basic schedule module (`/schedule/*`) - simpler, less features
2. AI course schedule (`/ai/course-schedule/*`) - AI-integrated, richer features

**Selected:** AI Course Schedule System (System 2)

**Rationale:**
- Already has AI generation capability (`schedule_generator.go`)
- Stores as plan items (integrates with existing plan system)
- Richer data model (period, classroom, priority, notes)
- Active API endpoints already exist

---

## Architecture

### Backend (Already Complete ✅)
- **Storage:** `plans` table with `[course_schedule]` content marker
- **API Endpoints:**
  - `GET /ai/course-schedule/lessons?date=YYYY-MM-DD&granularity=day|week|month`
  - `POST /ai/course-schedule/lessons` - Create lesson
  - `PUT /ai/course-schedule/lessons/{id}` - Update lesson
  - `DELETE /ai/course-schedule/lessons/{id}` - Delete lesson
- **AI Generation:** Via `schedule_generator.go`

### Frontend (Needs Implementation ❌)
- **Remove:** Hardcoded `_weeklyTemplates` in `course_schedule_screen.dart`
- **Add:** API client methods in `api_service.dart`
- **Update:** UI to fetch/display server data

---

## Implementation Plan

### Phase 1: API Client Layer
**File:** `apps/flutter_client/lib/services/api_service.dart`

Add methods:
- `getCourseScheduleLessons(date, granularity)`
- `createCourseScheduleLesson(request)`
- `updateCourseScheduleLesson(id, request)`
- `deleteCourseScheduleLesson(id)`

### Phase 2: Data Model
**File:** `apps/flutter_client/lib/models/course_lesson.dart` (new)

Create model with JSON serialization.

### Phase 3: UI Update
**File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`

1. Remove `_weeklyTemplates` constant
2. Add `List<CourseLesson> _lessons = []`
3. Add `_fetchLessons()` method
4. Update views to use `_lessons`
5. Add error handling and empty state

---

## Success Criteria

✅ Hardcoded templates removed
✅ Lessons fetched from server API
✅ Day/week/month views work with server data
✅ Create/update/delete operations work
✅ Loading states and error handling implemented
✅ Empty state shows appropriate message

---

## Out of Scope

❌ AI generation UI (use existing agent chat)
❌ Template management
❌ Offline caching
❌ Mastery tracking migration (keep local)
