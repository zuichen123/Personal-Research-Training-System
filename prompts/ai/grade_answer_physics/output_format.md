Return ONLY valid JSON in this exact structure:

{
  "score": <number 0-100>,
  "correct": <boolean>,
  "feedback": "<string>",
  "analysis": "<string>",
  "explanation": "<string>",
  "wrong_reason": "<string>"
}

**Field Specifications:**

**score** (0-100):
- 90-100: Correct answer with excellent understanding, proper methodology, and clear presentation
- 80-89: Correct answer with minor issues (small calculation error, missing unit, imprecise significant figures)
- 70-79: Mostly correct approach with moderate errors (wrong intermediate step but sound reasoning)
- 60-69: Correct concept but significant execution errors (right equation, wrong application)
- 40-59: Partial understanding with major errors (some correct elements, fundamental mistakes)
- 20-39: Minimal correct work (identified relevant concept but failed execution)
- 0-19: Incorrect approach or no meaningful physics content

**correct** (true/false):
- true: Final answer matches answer key within acceptable tolerance (considering significant figures)
- false: Final answer is incorrect or missing

**feedback** (concise, actionable guidance):
Provide 2-4 sentences of constructive feedback focusing on:
- What was done well (if anything)
- The most important error or misconception
- Specific guidance for improvement
- Encouragement when appropriate

Example: "Your free body diagram correctly identified all forces. However, you used the wrong component of tension—you need the vertical component (T cos θ) not horizontal. Review vector decomposition and try again."

**analysis** (detailed evaluation):
Provide a thorough breakdown including:
- Conceptual understanding demonstrated
- Correctness of physical setup (diagrams, identified quantities)
- Equation selection and application
- Mathematical execution
- Dimensional analysis and units
- Physical reasonableness of result
- Comparison with answer key

Use specific references: "In step 2, you wrote F = ma = 50 N, but mass is 5 kg, so a = 10 m/s², not 50 m/s²."

**explanation** (teaching moment):
Explain the correct physics and methodology:
- State the relevant physical principles
- Show the correct approach step-by-step
- Explain why the student's approach was incorrect (if applicable)
- Connect to broader physics concepts
- Include diagrams descriptions when helpful ("Draw a free body diagram showing...")

Example: "This is a conservation of energy problem. The gravitational potential energy at the top (mgh) converts to kinetic energy at the bottom (½mv²). Setting them equal: mgh = ½mv², the mass cancels, giving v = √(2gh). This shows that final speed is independent of mass—a key insight from Galileo's experiments."

**wrong_reason** (diagnostic):
If the answer is incorrect, identify the root cause:
- "Conceptual error: confused force with acceleration"
- "Setup error: incorrect free body diagram, missed friction force"
- "Equation error: used v = at instead of v² = v₀² + 2aΔx"
- "Sign error: treated upward acceleration as negative"
- "Unit error: forgot to convert km/h to m/s"
- "Calculation error: arithmetic mistake in final step"
- "Dimensional error: added quantities with incompatible units"
- "Physical unreasonableness: result violates conservation law"

If correct, state: "No errors—correct solution"

**Formatting Guidelines:**
- Use clear, professional language
- Include specific equation references (F = ma, E = mc², etc.)
- Reference line numbers or steps when pointing out errors
- Use proper physics notation and terminology
- Keep feedback encouraging but honest
- Escape special characters properly for JSON (quotes, newlines)
