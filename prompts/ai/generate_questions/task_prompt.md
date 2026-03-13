Generate practice questions that meet the following criteria:

**Difficulty Calibration**
- Match the specified difficulty level (1-5) through appropriate cognitive demand
- Level 1-2: Recall and basic comprehension
- Level 3: Application and analysis
- Level 4-5: Evaluation, synthesis, and complex problem-solving

**Question Types**
- Single choice (MCQ): One correct answer with 3-4 plausible distractors
- Multi choice: Multiple correct answers clearly indicated
- Short answer: Open-ended requiring brief written response
- Problem-solving: Multi-step questions with worked solutions

**Content Requirements**
- Align precisely with the specified subject, topic, and learning objectives
- Include complete worked solutions showing all steps
- Provide clear explanations of why answers are correct
- For MCQs, base distractors on documented misconceptions in the field
- Vary cognitive levels within the question set

**Quality Standards**
- Questions must be unambiguous with single defensible answers
- Avoid "all of the above" or "none of the above" options
- Use authentic contexts relevant to real-world application
- Ensure distractors are plausible but distinctly incorrect
- Balance conceptual understanding with procedural knowledge

## JSON Output Example

You MUST output a JSON array of questions. Each question MUST include ALL required fields shown below:

```json
[
  {
    "title": "Quadratic Equation Roots",
    "stem": "Solve the quadratic equation: x² - 5x + 6 = 0",
    "type": "single_choice",
    "subject": "math",
    "chapter": "Algebra - Quadratic Equations",
    "options": [
      {
        "key": "A",
        "text": "x = 2 or x = 3",
        "score": 0
      },
      {
        "key": "B",
        "text": "x = -2 or x = -3",
        "score": 0
      },
      {
        "key": "C",
        "text": "x = 1 or x = 6",
        "score": 0
      },
      {
        "key": "D",
        "text": "x = 2 or x = 3",
        "score": 0
      }
    ],
    "answer_key": ["A"],
    "tags": ["quadratic", "factoring", "algebra"],
    "difficulty": 3
  },
  {
    "title": "Photosynthesis Process",
    "stem": "Which of the following are products of photosynthesis? (Select all that apply)",
    "type": "multi_choice",
    "subject": "biology",
    "chapter": "Plant Biology",
    "options": [
      {
        "key": "A",
        "text": "Glucose (C₆H₁₂O₆)",
        "score": 0
      },
      {
        "key": "B",
        "text": "Oxygen (O₂)",
        "score": 0
      },
      {
        "key": "C",
        "text": "Carbon dioxide (CO₂)",
        "score": 0
      },
      {
        "key": "D",
        "text": "Water (H₂O)",
        "score": 0
      }
    ],
    "answer_key": ["A", "B"],
    "tags": ["photosynthesis", "cellular-processes", "plants"],
    "difficulty": 2
  },
  {
    "title": "Newton's Second Law Application",
    "stem": "A 5 kg object is pushed with a force of 20 N. Calculate its acceleration and explain your reasoning step by step.",
    "type": "short_answer",
    "subject": "physics",
    "chapter": "Mechanics - Forces and Motion",
    "options": [],
    "answer_key": ["4 m/s²"],
    "tags": ["newton-laws", "force", "acceleration"],
    "difficulty": 3
  }
]
```

**Critical Requirements:**
- ALWAYS output a valid JSON array (even for single question)
- NEVER omit required fields: title, stem, type, subject, difficulty
- For MCQ: include options array with key and text for each option
- For MCQ: answer_key must be array of option keys (e.g., ["A"] or ["A", "B"])
- For short_answer: options can be empty array, answer_key contains expected answer(s)
- tags should be array of relevant keywords (minimum 2 tags)
- difficulty must be integer 1-5
