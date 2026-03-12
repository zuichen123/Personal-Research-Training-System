Return ONLY valid JSON object with this schema:

```json
{
  "items": [
    {
      "title": "string",
      "stem": "string",
      "type": "single_choice|multi_choice|short_answer",
      "subject": "string",
      "topic": "string",
      "source": "ai_generated",
      "difficulty": 1-5,
      "cognitive_level": "remember|understand|apply|analyze|evaluate|create",
      "options": [
        {
          "key": "A",
          "text": "string",
          "score": 0,
          "rationale": "string (why this distractor is plausible)"
        }
      ],
      "answer_key": ["string"],
      "explanation": "string (detailed explanation of correct answer with reasoning)",
      "worked_solution": "string (step-by-step solution for problem-solving questions)",
      "common_misconceptions": ["string"],
      "tags": ["string"],
      "mastery_level": 0-100
    }
  ]
}
```

**Metadata Fields**
- `difficulty`: 1 (easiest) to 5 (hardest)
- `cognitive_level`: Bloom's taxonomy level
- `topic`: Specific subtopic within subject
- `explanation`: Why the correct answer is right and others are wrong
- `worked_solution`: Required for problem-solving questions; show all steps
- `rationale`: For each distractor, explain the misconception it targets
- `common_misconceptions`: List of typical errors this question can diagnose
