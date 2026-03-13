Analyze learning performance data and optimize the study plan.

## Analysis Steps
1. **Identify Performance Patterns**: Review completion rates, time spent, quiz scores, and engagement metrics
2. **Detect Struggling Areas**: Find topics with low scores, repeated attempts, or excessive time investment
3. **Detect Mastered Areas**: Find topics with high scores, quick completion, and consistent performance
4. **Assess Pacing**: Compare actual vs. planned progress; identify bottlenecks and acceleration opportunities
5. **Evaluate Motivation**: Check for signs of burnout (declining engagement) or momentum (consistent streaks)

## Optimization Actions
- **postpone**: Extend deadlines for struggling areas; add review cycles; reduce cognitive load
- **advance**: Accelerate mastered topics; unlock advanced material early; compress redundant practice
- **complete_early**: Mark overachieved goals as done; celebrate wins; redirect effort to new challenges

## Adjustment Strategies
- **Struggling areas**: Add spaced repetition, simplify explanations, recommend alternative resources, break into smaller chunks
- **Mastered areas**: Skip redundant drills, introduce challenge problems, connect to advanced topics
- **Pacing**: Rebalance time allocation, shift priorities, adjust milestones
- **Motivation**: Inject variety, celebrate progress, set micro-goals, recommend breaks

Maintain plan coherence: update dates, hierarchy, status, and dependencies consistently.

## JSON Output Example

You MUST output a JSON object with ALL required fields:

```json
{
  "action": "postpone",
  "change_summary": [
    "Extended calculus derivatives deadline by 1 week due to below-target quiz scores",
    "Added 3 extra practice sessions for limit concepts",
    "Reduced daily study time from 2h to 1.5h to prevent burnout"
  ],
  "updated_plan": {
    "mode": "self_study",
    "subject": "mathematics",
    "unit": "calculus",
    "created_at": "2026-03-13T10:00:00Z",
    "final_goal": "Master differential and integral calculus",
    "current_status": "Completed limits, struggling with derivatives",
    "plan_start_date": "2026-03-15",
    "plan_end_date": "2026-06-22",
    "study_outline": [
      "Week 1-3: Limits and continuity (extended)",
      "Week 4-6: Derivatives and rules",
      "Week 7-8: Applications",
      "Week 9-10: Integration",
      "Week 11-13: Review"
    ],
    "review_checklist": [
      "Daily: 15min review",
      "Weekly: Practice set",
      "Bi-weekly: Quiz"
    ],
    "stage_suggestion": "Focus on derivative fundamentals before advancing",
    "missing_fields": [],
    "follow_up_questions": [],
    "themes": [
      {
        "name": "Differential Calculus",
        "estimated_hours": 35.0,
        "children": [
          {
            "level": "topic",
            "title": "Derivative Concepts",
            "estimated_hours": 18.0,
            "start_date": "2026-03-23",
            "end_date": "2026-04-06",
            "children": []
          }
        ]
      }
    ],
    "plan_items": [
      {
        "plan_type": "practice",
        "title": "Extra Derivative Practice",
        "content": "Complete 30 derivative problems",
        "target_date": "2026-03-25",
        "status": "pending",
        "priority": 1
      }
    ],
    "optimization_hints": [
      "Take breaks between study sessions",
      "Review limits before each derivative session"
    ]
  }
}
```

**Critical Requirements:**
- action: Must be "postpone", "advance", or "complete_early"
- change_summary: Array of 2-5 specific changes made (each 10-30 words)
- updated_plan: Complete LearnResult object with all fields from build_learning_plan
- Ensure dates in updated_plan are consistent and logical
- All arrays must be present (use empty [] if no items)
