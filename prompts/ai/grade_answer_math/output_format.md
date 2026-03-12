**Output Format: Structured Mathematical Feedback**

Return ONLY valid JSON with the following structure:

```json
{
  "score": 0-100,
  "correct": true|false,
  "feedback": "string",
  "analysis": "string",
  "explanation": "string",
  "wrong_reason": "string"
}
```

**Field Guidelines:**

**score** (number, 0-100):
- Award based on correctness, method validity, and reasoning quality
- Partial credit for correct approach with minor errors
- Consider: setup (20%), method (30%), execution (30%), final answer (20%)

**correct** (boolean):
- true: Final answer matches the answer key (within acceptable tolerance for decimals)
- false: Final answer is incorrect or significantly incomplete

**feedback** (string):
- Start with positive elements: "Your setup using the quadratic formula was correct..."
- Identify specific errors: "In step 3, you incorrectly distributed the negative sign..."
- Provide hints: "Consider factoring the numerator before simplifying..."
- Suggest visualizations when helpful: "Drawing a diagram of the triangle might clarify the relationship..."
- Connect to concepts: "This relates to the distributive property you learned earlier..."
- Keep concise but informative (2-4 sentences)

**analysis** (string):
- Detailed breakdown of the solution approach
- Evaluate each major step: "Step 1: Correctly identified variables. Step 2: Set up equation properly. Step 3: Sign error when expanding (x-3)²..."
- Note alternative methods: "You could also solve this geometrically using similar triangles..."
- Highlight patterns: "This is a common error when working with negative exponents..."

**explanation** (string):
- Explain the correct mathematical reasoning
- Clarify why the student's approach did or didn't work
- Provide conceptual understanding: "The derivative represents the instantaneous rate of change, so..."
- Include formulas or theorems when relevant: "Using the Pythagorean theorem: a² + b² = c²..."

**wrong_reason** (string, only if correct=false):
- Pinpoint the root cause of the error
- Examples: "Sign error in algebraic manipulation", "Misapplied order of operations", "Conceptual misunderstanding of function composition", "Calculation error in final step", "Forgot to check for extraneous solutions"
- Be specific and diagnostic, not judgmental
