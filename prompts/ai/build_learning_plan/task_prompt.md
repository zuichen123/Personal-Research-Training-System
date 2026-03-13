# Task: Build Learning Plan

Design a comprehensive, executable learning plan using evidence-based principles.

## Core Principles

### 1. SMART Goal Setting
- **Specific**: Clear, concrete learning outcomes
- **Measurable**: Quantifiable progress indicators
- **Achievable**: Realistic given user's time and background
- **Relevant**: Aligned with user's objectives
- **Time-bound**: Explicit deadlines and milestones

### 2. Logical Sequencing
- Map prerequisites: foundational concepts before advanced
- Build progressively: simple → complex, concrete → abstract
- Identify critical path: core skills vs. optional enrichment
- Cluster related topics for coherence

### 3. Spaced Repetition Schedule
- Initial learning: concentrated exposure
- First review: 1-2 days after learning
- Second review: 1 week after first review
- Third review: 2-4 weeks after second review
- Ongoing: monthly maintenance reviews

### 4. Assessment Checkpoints
- Formative: frequent low-stakes checks (quizzes, self-tests)
- Summative: milestone assessments (projects, comprehensive tests)
- Diagnostic: identify gaps and adjust plan
- Frequency: weekly formative, monthly summative

### 5. Time Adaptation
- Calculate available hours per week
- Allocate 70% to new learning, 20% to review, 10% to buffer
- Adjust pace based on topic difficulty and user feedback
- Build in rest periods to prevent burnout

### 6. Practice Variety
- **Retrieval**: flashcards, practice tests, recall exercises
- **Application**: problem sets, case studies, real-world tasks
- **Creation**: projects, teaching others, original work
- Mix types within each study session for deeper encoding

## Execution
Analyze user profile, available time, and learning goals. Generate a structured plan with themes, milestones, and daily/weekly tasks.

## JSON Output Example

You MUST output a JSON object with ALL required fields. Here is a complete example:

```json
{
  "mode": "self_study",
  "subject": "mathematics",
  "unit": "calculus",
  "created_at": "2026-03-13T10:00:00Z",
  "final_goal": "Master differential and integral calculus for university entrance exam",
  "current_status": "Completed algebra and trigonometry, familiar with basic functions",
  "plan_start_date": "2026-03-15",
  "plan_end_date": "2026-06-15",
  "study_outline": [
    "Week 1-2: Limits and continuity",
    "Week 3-4: Derivatives and differentiation rules",
    "Week 5-6: Applications of derivatives",
    "Week 7-8: Integration techniques",
    "Week 9-10: Applications of integrals",
    "Week 11-12: Review and practice exams"
  ],
  "review_checklist": [
    "Daily: Review previous day's concepts (15 min)",
    "Weekly: Complete practice problem set (2 hours)",
    "Bi-weekly: Take diagnostic quiz",
    "Monthly: Comprehensive review session"
  ],
  "stage_suggestion": "Begin with limits foundation, ensure solid understanding before moving to derivatives",
  "missing_fields": [],
  "follow_up_questions": [
    "Do you have access to a graphing calculator?",
    "Have you studied limits before?",
    "What is your target exam score?"
  ],
  "themes": [
    {
      "name": "Foundations of Calculus",
      "estimated_hours": 20.0,
      "children": [
        {
          "level": "topic",
          "title": "Limits and Continuity",
          "estimated_hours": 10.0,
          "start_date": "2026-03-15",
          "end_date": "2026-03-22",
          "children": []
        },
        {
          "level": "topic",
          "title": "Derivative Concepts",
          "estimated_hours": 10.0,
          "start_date": "2026-03-23",
          "end_date": "2026-03-30",
          "children": []
        }
      ]
    },
    {
      "name": "Differential Calculus",
      "estimated_hours": 30.0,
      "children": [
        {
          "level": "topic",
          "title": "Differentiation Rules",
          "estimated_hours": 15.0,
          "start_date": "2026-03-31",
          "end_date": "2026-04-14",
          "children": []
        },
        {
          "level": "topic",
          "title": "Applications of Derivatives",
          "estimated_hours": 15.0,
          "start_date": "2026-04-15",
          "end_date": "2026-04-28",
          "children": []
        }
      ]
    }
  ],
  "plan_items": [
    {
      "plan_type": "study",
      "title": "Introduction to Limits",
      "content": "Study limit definition, one-sided limits, and limit laws. Complete exercises 1.1-1.3 from textbook.",
      "target_date": "2026-03-16",
      "status": "pending",
      "priority": 1
    },
    {
      "plan_type": "practice",
      "title": "Limit Calculation Practice",
      "content": "Solve 20 limit problems covering algebraic, trigonometric, and rational functions.",
      "target_date": "2026-03-18",
      "status": "pending",
      "priority": 2
    },
    {
      "plan_type": "review",
      "title": "Week 1 Review Session",
      "content": "Review all limit concepts, identify weak areas, and redo challenging problems.",
      "target_date": "2026-03-22",
      "status": "pending",
      "priority": 3
    }
  ],
  "optimization_hints": [
    "Focus on understanding limit intuition before memorizing formulas",
    "Use graphing tools to visualize function behavior near limits",
    "Practice daily for consistency rather than cramming"
  ]
}
```
