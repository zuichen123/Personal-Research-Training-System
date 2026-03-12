# Compression Output Format

Output your compression as a JSON object with the following structure:

```json
{
  "summary": "Brief narrative summary of the entire session (1-3 sentences)",
  "learning_progress": {
    "topics_covered": ["topic1", "topic2"],
    "concepts_mastered": ["concept1", "concept2"],
    "concepts_struggling": ["concept3"]
  },
  "action_items": [
    "Action item 1 with specific details",
    "Action item 2 with deadline if applicable"
  ],
  "unresolved_questions": [
    "Question 1 that needs follow-up",
    "Question 2 that wasn't fully answered"
  ],
  "follow_up_needed": ["topic1", "topic2"],
  "student_state": {
    "confidence": "low|medium|high",
    "engagement": "low|medium|high",
    "needs_encouragement": true|false
  }
}
```

## Field Descriptions

**summary**: A concise narrative that captures the essence of the session. Should read naturally and provide context for someone reviewing the session later.

**learning_progress.topics_covered**: List of all topics discussed during the session.

**learning_progress.concepts_mastered**: Concepts the student demonstrated clear understanding of.

**learning_progress.concepts_struggling**: Concepts where the student showed difficulty or confusion.

**action_items**: Specific tasks, homework, or practice exercises assigned. Be explicit about what needs to be done.

**unresolved_questions**: Questions the student asked that weren't fully resolved or need deeper exploration.

**follow_up_needed**: Topics that require additional attention in future sessions.

**student_state.confidence**: Overall confidence level demonstrated during the session.

**student_state.engagement**: How engaged and focused the student was.

**student_state.needs_encouragement**: Whether the student would benefit from motivational support.

## Example

```json
{
  "summary": "Student practiced quadratic equations, mastered factoring but struggled with completing the square. Assigned 5 practice problems for homework.",
  "learning_progress": {
    "topics_covered": ["quadratic equations", "factoring", "completing the square"],
    "concepts_mastered": ["factoring simple quadratics"],
    "concepts_struggling": ["completing the square"]
  },
  "action_items": [
    "Complete 5 practice problems on completing the square",
    "Review video on completing the square technique"
  ],
  "unresolved_questions": [
    "Why do we add (b/2)^2 when completing the square?"
  ],
  "follow_up_needed": ["completing the square", "word problems with quadratics"],
  "student_state": {
    "confidence": "medium",
    "engagement": "high",
    "needs_encouragement": false
  }
}
```
