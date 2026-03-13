# Task: Comprehensive Learning Evaluation

## Evaluation Workflow

### 1. Analyze Performance Data
- Compare user answer against answer key
- Identify correct elements and errors
- Assess depth of understanding vs. surface recall
- Detect misconceptions or systematic errors

### 2. Multi-Dimensional Assessment
- **Accuracy**: Calculate correctness score (0-100)
- **Completeness**: Evaluate coverage of required concepts
- **Consistency**: Compare with historical performance patterns
- **Improvement**: Measure progress from previous attempts

### 3. Diagnostic Analysis
- Identify specific knowledge gaps
- Recognize error patterns (conceptual vs. careless)
- Determine readiness for advancement
- Assess mastery level against thresholds

### 4. Generate Actionable Feedback
- **Single Evaluation**: Brief verdict on this attempt
- **Comprehensive Evaluation**: Detailed analysis with context
- **Knowledge Supplements**: Targeted resources to fill gaps
- **Retest Questions**: Focused practice for weak areas

### 5. Provide Next Steps
- Recommend advancement or review based on mastery threshold
- Suggest specific study strategies for improvement
- Highlight strengths to build confidence
- Frame feedback to maintain motivation

## JSON Output Example

You MUST output a JSON object with ALL required fields:

```json
{
  "score": 78.5,
  "single_evaluation": "Good understanding of basic concepts, but needs practice with complex applications",
  "comprehensive_evaluation": "The student demonstrates solid grasp of fundamental principles in quadratic equations, successfully solving standard problems using factoring and the quadratic formula. However, performance drops when facing word problems or multi-step applications. Error analysis reveals occasional arithmetic mistakes rather than conceptual gaps. Overall trajectory shows steady improvement over the past three weeks.",
  "single_explanation": "Correct approach on 7/10 problems, with errors mainly in calculation steps",
  "comprehensive_explanation": "Your factoring technique is strong - you correctly identified factor pairs in all applicable problems. The quadratic formula application shows good setup, but watch for sign errors when computing the discriminant. In word problems, you're translating scenarios into equations correctly, but sometimes miss the final interpretation step. Your work is well-organized and shows clear reasoning, which makes it easy to identify where errors occur. The improvement from 65% to 78.5% over three weeks indicates effective study habits.",
  "knowledge_supplements": [
    "Review discriminant calculation: b² - 4ac, paying special attention to negative coefficients",
    "Practice translating word problems: identify what the variable represents before setting up equations",
    "Study completing the square method as an alternative to factoring for non-factorable quadratics"
  ],
  "retest_questions": [
    {
      "title": "Discriminant Practice",
      "stem": "For the equation 2x² - 7x + 3 = 0, calculate the discriminant and determine the nature of the roots",
      "type": "short_answer",
      "subject": "math",
      "chapter": "Quadratic Equations",
      "source": "ai_generated",
      "lesson_id": "",
      "options": [],
      "answer_key": ["25", "two distinct real roots"],
      "tags": ["discriminant", "quadratic", "roots"],
      "difficulty": 3,
      "mastery_level": 0
    },
    {
      "title": "Word Problem Application",
      "stem": "A rectangular garden has length 3 meters more than its width. If the area is 40 square meters, find the dimensions.",
      "type": "short_answer",
      "subject": "math",
      "chapter": "Quadratic Equations - Applications",
      "source": "ai_generated",
      "lesson_id": "",
      "options": [],
      "answer_key": ["width: 5m, length: 8m"],
      "tags": ["word-problem", "quadratic", "geometry"],
      "difficulty": 4,
      "mastery_level": 0
    }
  ]
}
```

**Critical Requirements:**
- score: Float 0.0-100.0 representing overall performance
- single_evaluation: Brief verdict (20-40 words)
- comprehensive_evaluation: Detailed analysis (100-200 words) covering strengths, weaknesses, patterns, and progress
- single_explanation: Concise explanation (15-30 words)
- comprehensive_explanation: In-depth feedback (150-250 words) with specific examples and guidance
- knowledge_supplements: Array of 2-4 targeted learning resources or review topics
- retest_questions: Array of 1-3 practice questions targeting identified weak areas (must include all CreateInput fields)
