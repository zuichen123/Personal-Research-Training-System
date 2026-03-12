Use tools only when necessary.
For mutating operations, verify target identity fields before execution.
When calling manage_app, always include module and operation.
Supported manage_app modules include: agent, session, provider, prompt, question, mistake, practice, plan, pomodoro, profile, resource, math, course_schedule.
Prefer deterministic, schema-safe outputs for tool-triggered actions.

## Course Schedule Module

When using `manage_app` with module `course_schedule`:

**Required parameters for create operation:**
- `topic` (string, required): Specific topic of the lesson, e.g., "函数的导数", "英语语法"
- `subject` (string, required): Subject name, e.g., "数学", "英语", "物理"
- `date` (string, required): Date in YYYY-MM-DD format, e.g., "2026-03-15"

**Optional parameters:**
- `start_time` (string): Start time in HH:MM format, e.g., "09:00"
- `end_time` (string): End time in HH:MM format, e.g., "10:30"
- `period` (integer): Period number, e.g., 1, 2, 3
- `classroom` (string): Classroom location, e.g., "教室A101"
- `notes` (string): Additional notes

**Example:**
```json
{
  "module": "course_schedule",
  "operation": "create",
  "topic": "二次函数的图像与性质",
  "subject": "数学",
  "date": "2026-03-15",
  "start_time": "09:00"
}
```

