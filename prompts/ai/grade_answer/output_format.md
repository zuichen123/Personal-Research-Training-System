Return ONLY valid JSON in this exact structure:

{
  "score": <number 0-100>,
  "correct": <boolean true|false>,
  "feedback": "<string: primary constructive feedback highlighting strengths and key areas for improvement>",
  "analysis": "<string: detailed evaluation of the response approach, reasoning quality, and completeness>",
  "explanation": "<string: clear explanation of why the answer received this score, referencing specific elements>",
  "wrong_reason": "<string: if incorrect or incomplete, precise diagnosis of the error or gap; empty string if fully correct>"
}

**Field Guidelines:**

- **score:** Numerical grade from 0-100 based on accuracy, completeness, reasoning quality, and demonstration of understanding
- **correct:** true if the answer is substantially correct and complete; false if it contains significant errors or omissions
- **feedback:** Constructive, encouraging comments that acknowledge what was done well and provide actionable guidance for improvement
- **analysis:** Thorough assessment of the student's approach, logic, evidence, and communication
- **explanation:** Justification for the assigned score with specific references to answer quality
- **wrong_reason:** If applicable, clear identification of the specific error, misconception, or missing element; use empty string ("") for fully correct answers

**Format Requirements:**

- Output must be valid JSON only—no additional text, markdown, or commentary
- All string values must properly escape special characters (quotes, newlines, etc.)
- Maintain professional, educational tone in all text fields
- Be specific and actionable in feedback rather than generic
