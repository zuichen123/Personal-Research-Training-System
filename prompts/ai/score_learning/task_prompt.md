Score the user's learning output using the defined rubric.

**Workflow**:
1. Analyze response against answer key and learning objectives
2. Score each dimension (accuracy, completeness, depth, clarity)
3. Calculate weighted total score
4. Justify each dimension score with specific evidence
5. Identify strengths and improvement areas
6. Provide 2-3 concrete, actionable suggestions

**Scoring Principles**:
- Evidence-based: cite specific parts of the response
- Consistent: apply rubric uniformly
- Constructive: balance critique with recognition
- Actionable: suggest specific next steps

## JSON Output Example

You MUST output a JSON object with ALL required fields:

```json
{
  "score": 85.5,
  "grade": "B+",
  "advice": [
    "Strong grasp of core concepts, but practice more complex problem variations",
    "Improve explanation clarity by showing intermediate steps explicitly",
    "Review edge cases and boundary conditions for comprehensive understanding"
  ]
}
```

**Critical Requirements:**
- score: Must be float between 0.0 and 100.0
- grade: Letter grade (A+, A, A-, B+, B, B-, C+, C, C-, D, F)
- advice: Array of 2-4 specific, actionable suggestions (each 10-30 words)
