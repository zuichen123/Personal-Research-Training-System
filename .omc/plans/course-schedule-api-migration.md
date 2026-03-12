# Course Schedule API Migration - Minimal Implementation Plan

**Created:** 2026-03-12
**Goal:** Migrate Flutter course schedule from hardcoded templates to server API

---

## Analysis Summary

**Backend:** ✅ API exists at `/ai/course-schedule/lessons`
**Frontend:** ❌ Uses hardcoded `_weeklyTemplates` (line 35-96 in `course_schedule_screen.dart`)
**Existing Model:** `_CourseLesson` class at line 1378-1398 (private, needs to be public)

---

## Task 1: Create Course Lesson Model

**File:** `apps/flutter_client/lib/models/course_lesson.dart` (NEW)

**Action:** Create minimal model with JSON deserialization

```dart
class CourseLesson {
  final String id;
  final String date;        // YYYY-MM-DD
  final int period;
  final String subject;
  final String topic;
  final String classroom;
  final String startTime;   // HH:mm
  final String endTime;

  CourseLesson({
    required this.id,
    required this.date,
    required this.period,
    required this.subject,
    required this.topic,
    required this.classroom,
    required this.startTime,
    required this.endTime,
  });

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    return CourseLesson(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      period: (json['period'] as num?)?.toInt() ?? 1,
      subject: json['subject']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      classroom: json['classroom']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
    );
  }
}
```

**Verification:** File compiles without errors

---

## Task 2: Add API Methods

**File:** `apps/flutter_client/lib/services/api_service.dart`

**Action:** Add 4 methods (insert after line ~400, near other API methods)

```dart
Future<List<CourseLesson>> getCourseScheduleLessons(
  String date,
  String granularity,
) async {
  final uri = Uri.parse('$baseUrl/ai/course-schedule/lessons')
      .replace(queryParameters: {
    'date': date,
    'granularity': granularity,
  });

  final response = await _client.get(uri).timeout(_defaultRequestTimeout);

  if (response.statusCode != 200) {
    throw ApiException(
      code: 'fetch_failed',
      message: 'Failed to fetch lessons',
      statusCode: response.statusCode,
    );
  }

  final json = await compute(_decodeJsonInBackground, response.body);
  final List<dynamic> data = json['data'] ?? [];
  return data.map((item) => CourseLesson.fromJson(item)).toList();
}

Future<CourseLesson> createCourseScheduleLesson(
  Map<String, dynamic> request,
) async {
  final uri = Uri.parse('$baseUrl/ai/course-schedule/lessons');
  final response = await _client
      .post(uri, body: jsonEncode(request), headers: {'Content-Type': 'application/json'})
      .timeout(_defaultRequestTimeout);

  if (response.statusCode != 201) {
    throw ApiException(
      code: 'create_failed',
      message: 'Failed to create lesson',
      statusCode: response.statusCode,
    );
  }

  final json = await compute(_decodeJsonInBackground, response.body);
  return CourseLesson.fromJson(json['data']);
}

Future<void> updateCourseScheduleLesson(
  String id,
  Map<String, dynamic> request,
) async {
  final uri = Uri.parse('$baseUrl/ai/course-schedule/lessons/$id');
  final response = await _client
      .put(uri, body: jsonEncode(request), headers: {'Content-Type': 'application/json'})
      .timeout(_defaultRequestTimeout);

  if (response.statusCode != 200) {
    throw ApiException(
      code: 'update_failed',
      message: 'Failed to update lesson',
      statusCode: response.statusCode,
    );
  }
}

Future<void> deleteCourseScheduleLesson(String id) async {
  final uri = Uri.parse('$baseUrl/ai/course-schedule/lessons/$id');
  final response = await _client.delete(uri).timeout(_defaultRequestTimeout);

  if (response.statusCode != 200) {
    throw ApiException(
      code: 'delete_failed',
      message: 'Failed to delete lesson',
      statusCode: response.statusCode,
    );
  }
}
```

**Also add import:** `import '../models/course_lesson.dart';`

**Verification:** `flutter analyze` passes

---

## Task 3: Update Course Schedule Screen - Part A (Remove Templates)

**File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`

**Action 3.1:** Remove hardcoded templates
- Delete lines 35-96 (`_weeklyTemplates` constant)
- Delete lines 1356-1376 (`_CourseTemplateLesson` class)

**Action 3.2:** Add imports and state
```dart
// Add import at top
import '../../models/course_lesson.dart';

// Replace _CourseLesson class (line 1378-1398) usage with imported CourseLesson
// Add state variables after line 34:
List<CourseLesson> _lessons = [];
bool _loadingLessons = false;
String? _lessonsError;
```

**Verification:** File compiles (may have runtime errors until Task 3B complete)

---

## Task 4: Update Course Schedule Screen - Part B (Fetch Logic)

**File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`

**Action 4.1:** Add fetch method (insert after `initState()` around line 115)

```dart
Future<void> _fetchLessons() async {
  if (!mounted) return;
  
  setState(() {
    _loadingLessons = true;
    _lessonsError = null;
  });

  try {
    final api = context.read<AppProvider>().apiService;
    final dateStr = _focusDate.toIso8601String().split('T')[0];
    final granularity = _view == CourseScheduleView.day ? 'day' : 'week';
    
    final lessons = await api.getCourseScheduleLessons(dateStr, granularity);
    
    if (!mounted) return;
    setState(() => _lessons = lessons);
  } catch (e) {
    if (!mounted) return;
    setState(() => _lessonsError = e.toString());
  } finally {
    if (!mounted) return;
    setState(() => _loadingLessons = false);
  }
}
```

**Action 4.2:** Call fetch in `initState()` (modify line ~101)
```dart
@override
void initState() {
  super.initState();
  _refreshSelectedLesson();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.read<AppProvider>().fetchPlans();
    _fetchLessons();  // ADD THIS LINE
  });
}
```

**Verification:** App fetches data on launch

---

## Task 5: Update Lesson Filtering Logic

**File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`

**Action:** Find and update `_lessonsForDate()` method (around line 1241)

**Current logic:** Filters `_weeklyTemplates` by weekday
**New logic:** Filter `_lessons` by date

```dart
List<CourseLesson> _lessonsForDate(DateTime date) {
  final dateStr = date.toIso8601String().split('T')[0];
  return _lessons.where((lesson) => lesson.date == dateStr).toList()
    ..sort((a, b) => a.period.compareTo(b.period));
}
```

**Verification:** Day view displays correct lessons for selected date

---

## Task 6: Add Loading and Empty States

**File:** `apps/flutter_client/lib/screens/course_schedule/course_schedule_screen.dart`

**Action:** Update `_buildCurrentView()` method to show loading/error/empty states

**Minimal changes:**
1. Wrap existing content with loading check
2. Show error message if fetch fails
3. Show empty state when no lessons

```dart
Widget _buildCurrentView(BuildContext context, AppProvider appProvider) {
  if (_loadingLessons) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ),
    );
  }

  if (_lessonsError != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('加载失败: $_lessonsError', style: TextStyle(color: Colors.red)),
      ),
    );
  }

  // Existing view logic continues here...
  // Add empty state check in day/week/month views
}
```

**Verification:** Loading indicator shows during fetch, error displays on failure

---

## Success Criteria

✅ `CourseLesson` model created with JSON deserialization
✅ API methods added to `api_service.dart`
✅ Hardcoded `_weeklyTemplates` removed
✅ App fetches lessons from server on launch
✅ Day/week views display server data
✅ Loading indicator shows during fetch
✅ Error message displays on failure
✅ Empty state shows when no lessons exist
✅ `flutter analyze` passes with no errors

---

## Out of Scope

❌ Create/update/delete UI (use agent chat for CRUD)
❌ Month view optimization
❌ Offline caching/persistence
❌ Pull-to-refresh gesture
❌ Retry logic for failed requests
❌ Mastery tracking changes (keep local)
❌ AI generation UI

---

## Execution Order

**Sequential execution required:**
1. Task 1: Create model
2. Task 2: Add API methods
3. Task 3: Remove templates and add state
4. Task 4: Add fetch logic
5. Task 5: Update filtering
6. Task 6: Add UI states

**Verification after each task:** Run `flutter analyze` to catch errors early

---

## File References

- **Spec:** `F:\Code\go\Self-Study-Tool\.omc\autopilot\spec.md`
- **Backend Handler:** `F:\Code\go\Self-Study-Tool\internal\modules\schedule\handler.go:18-22`
- **Current Screen:** `F:\Code\go\Self-Study-Tool\apps\flutter_client\lib\screens\course_schedule\course_schedule_screen.dart:35-96`
- **Model Reference:** `F:\Code\go\Self-Study-Tool\apps\flutter_client\lib\models\plan.dart:26-43`
- **API Service:** `F:\Code\go\Self-Study-Tool\apps\flutter_client\lib\services\api_service.dart`

---

## Rollback Strategy

If implementation fails:
- Before commit: `git checkout apps/flutter_client/` restores Flutter code
- Mastery tracking data preserved (local only, no server dependency)
- Backend unchanged (already complete)

