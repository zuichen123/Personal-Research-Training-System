# Output Format

Return ONLY valid JSON with the following schema:

```json
{
  "mode": "build_learning_plan",
  "subject": "string - main topic",
  "unit": "string - specific focus area",
  "created_at": "RFC3339 timestamp",
  "final_goal": "string - SMART goal statement",
  "current_status": "string - learner's starting point",
  "plan_start_date": "YYYY-MM-DD",
  "plan_end_date": "YYYY-MM-DD",
  "study_outline": ["ordered list of major topics"],
  "review_checklist": ["key concepts to verify mastery"],
  "stage_suggestion": "string - recommended starting phase",
  "missing_fields": ["data needed for better planning"],
  "follow_up_questions": ["clarifying questions for user"],
  "themes": [
    {
      "name": "theme name",
      "estimated_hours": number,
      "children": [
        {
          "level": "year|month|week|day|task",
          "title": "milestone or task name",
          "estimated_hours": number,
          "start_date": "YYYY-MM-DD",
          "end_date": "YYYY-MM-DD",
          "details": ["specific activities, resources, success criteria"],
          "children": []
        }
      ]
    }
  ],
  "plan_items": [
    {
      "plan_type": "year_plan|month_plan|week_plan|day_plan|current_phase",
      "title": "string",
      "content": "detailed description with practice types and review schedule",
      "target_date": "YYYY-MM-DD",
      "status": "pending",
      "priority": 1
    }
  ],
  "optimization_hints": ["actionable tips for execution and adjustment"]
}
```

## Key Requirements
- **Timeline**: Realistic dates based on available hours/week
- **Milestones**: Clear checkpoints every 2-4 weeks
- **Resources**: Specific books, courses, tools in details arrays
- **Success Criteria**: Observable outcomes for each milestone
- **Review Schedule**: Explicit spaced repetition dates in plan_items
- **Practice Mix**: Each plan_item includes retrieval, application, and creation activities
