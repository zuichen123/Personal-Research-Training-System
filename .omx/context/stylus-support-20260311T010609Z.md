# Task
Add stylus (pen) support to Flutter frontend.

# Desired outcome
- Handwriting/drawing input works well with stylus.
- Palm rejection: ignore touch when stylus is active.
- Optional: pressure/tilt support if drawing surface exists.

# Known facts
- Flutter client located at apps/flutter_client.
- Repo currently has unrelated uncommitted changes (see git status below).

# Constraints
- Keep changes scoped to Flutter frontend.
- Avoid committing generated/build artifacts.

# Unknowns / questions
- Which screen/component is the handwriting surface? (need code search)
- Expected data model: store strokes? bitmap? send to backend?

# Current git status
```
 M apps/flutter_client/lib/services/api_service.dart
 M internal/modules/ai/prompt_templates_test.go
 M internal/platform/httpserver/middleware.go
?? .cache/
?? .claude/
?? .omc/
?? .omx/
?? CLAUDE.md
?? apps/flutter_client/.flutter
?? apps/flutter_client/.flutter_tool_state
?? apps/flutter_client/.omc/
?? internal/modules/question/.omc/
?? internal/platform/httpserver/activity_timeout_writer.go
```
