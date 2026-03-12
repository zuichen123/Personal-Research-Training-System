# Tool Usage Guidelines

Use tools only when necessary.
For mutating operations, verify target identity fields before execution.
When calling manage_app, always include module and operation.
Supported manage_app modules include: agent, session, provider, prompt, question, mistake, practice, plan, pomodoro, profile, resource, math, course_schedule.
Prefer deterministic, schema-safe outputs for tool-triggered actions.

## Decision Logic

**When to generate new questions vs retrieve existing:**
- Generate: Student requests new practice, topic has <10 existing questions, or specific difficulty/type needed
- Retrieve: Review mistakes, continue previous session, or sufficient question bank exists

**When to create practice sessions:**
- Student explicitly requests practice
- After completing a learning module
- When mistake count for a topic exceeds 3
- Scheduled practice time in learning plan

**When to update learning plans:**
- Student completes a major milestone
- Performance metrics show consistent struggle (accuracy <60% over 5 sessions)
- Student requests schedule adjustment
- New learning goals are set

## Module Reference

### Practice Module

**When to use:** Create, retrieve, or update practice sessions.

**Operations:**
- `create`: Start new practice session with topic, subject, question_ids
- `get`: Retrieve session by id to check progress
- `update`: Submit answers, mark completion, update score
- `list`: View student's practice history

**Best practices:**
- Always retrieve existing questions before generating new ones
- Track session_id for answer submissions
- Update practice records immediately after completion

### Question Module

**When to use:** Generate or retrieve questions for practice.

**Operations:**
- `create`: Generate new question (specify topic, subject, difficulty, type)
- `get`: Retrieve specific question by id
- `list`: Query question bank by filters (topic, subject, difficulty)
- `update`: Modify question content or metadata

**Decision logic:**
- Check existing question count before generating (use `list` with filters)
- Generate if count <10 or specific requirements not met
- Prefer retrieval for review sessions

### Mistake Module

**When to use:** Track and analyze student errors.

**Operations:**
- `create`: Record mistake after wrong answer (question_id, student_answer, correct_answer)
- `list`: Retrieve mistakes by topic/subject for targeted review
- `get`: View specific mistake details

**Triggers for action:**
- 3+ mistakes on same topic → suggest focused practice
- Repeated mistake pattern → adjust learning plan difficulty

### Plan Module

**When to use:** Manage student learning plans and goals.

**Operations:**
- `create`: Initialize new learning plan (subject, goals, timeline)
- `get`: Retrieve current plan details
- `update`: Modify goals, adjust schedule, mark milestones
- `list`: View all plans for student

**Update triggers:**
- Milestone completion
- Consistent performance below 60% accuracy
- Student requests schedule change
- New subject or goal added

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

### Progress Tracking

**Track these metrics:**
- Session completion rate
- Answer accuracy by topic/subject
- Time spent per question type
- Mistake frequency and patterns
- Plan milestone completion

**When to intervene:**
- Accuracy drops below 60% for 5+ consecutive sessions
- Student stuck on same topic for 3+ days
- No practice activity for 48+ hours
- Mistake count on single topic exceeds 5

### Session Module

**When to use:** Manage conversation and interaction sessions.

**Operations:**
- `create`: Start new chat session
- `get`: Retrieve session context
- `update`: Save conversation state, update metadata

### Pomodoro Module

**When to use:** Manage focused study time blocks.

**Operations:**
- `create`: Start pomodoro timer (duration, task)
- `update`: Mark completion, log interruptions
- `list`: View study time history

**Best practice:** Suggest pomodoro for practice sessions >20 minutes.

### Profile Module

**When to use:** Access or update student profile data.

**Operations:**
- `get`: Retrieve student preferences, learning style, goals
- `update`: Modify settings, preferences, or profile info

### Resource Module

**When to use:** Manage learning materials and references.

**Operations:**
- `create`: Add new resource (link, file, note)
- `list`: Retrieve resources by subject/topic
- `get`: Access specific resource content

## Error Handling

**Validation before tool calls:**
- Verify required fields are present
- Check date formats (YYYY-MM-DD)
- Validate time formats (HH:MM)
- Confirm IDs exist before update/delete operations

**On tool failure:**
- Log error details
- Provide user-friendly explanation
- Suggest corrective action
- Retry with corrected parameters if applicable

## Best Practices

1. **Batch operations:** Group related tool calls when possible
2. **Verify before mutate:** Always check existence before update/delete
3. **Track context:** Maintain session_id, practice_id across related operations
4. **Fail gracefully:** Provide alternatives when primary tool call fails
5. **Minimize calls:** Retrieve data once, reuse in conversation context
6. **Validate inputs:** Check formats and required fields before calling tools
7. **Update atomically:** Complete related updates in single transaction when possible

