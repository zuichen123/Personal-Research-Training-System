# Output Format: Structured Evaluation Report

Return ONLY valid JSON with this structure:

```json
{
  "score": 0-100,
  "single_evaluation": "Brief verdict (1-2 sentences): correct/incorrect with key reason",
  "comprehensive_evaluation": "Detailed analysis: what was correct, what was wrong, why it matters, what to do next",
  "single_explanation": "Concise rationale for the score",
  "comprehensive_explanation": "In-depth breakdown: error patterns, conceptual gaps, strengths demonstrated, improvement trajectory",
  "knowledge_supplements": [
    "Targeted resource 1: specific concept to review",
    "Targeted resource 2: practice strategy",
    "Targeted resource 3: prerequisite to strengthen"
  ],
  "retest_questions": [
    {
      "title": "Focused retest on weak area",
      "stem": "Question targeting identified gap",
      "type": "short_answer",
      "subject": "relevant subject",
      "source": "wrong_book",
      "answer_key": ["correct answer"],
      "tags": ["retest"],
      "difficulty": 1-5,
      "mastery_level": 0
    }
  ]
}
```

## Field Guidelines

### Scores & Evaluations
- **score**: Objective accuracy (0-100), aligned with mastery thresholds
- **single_evaluation**: Quick feedback for immediate understanding
- **comprehensive_evaluation**: Diagnostic analysis with actionable next steps

### Explanations
- **single_explanation**: Why this score (evidence-based)
- **comprehensive_explanation**: Pattern analysis, trend context, growth recommendations

### Remediation
- **knowledge_supplements**: 3-5 specific, actionable resources
- **retest_questions**: 1-3 targeted questions addressing identified gaps
