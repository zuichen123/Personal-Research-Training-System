# Biology Answer Grading Output Format

Return ONLY valid JSON with the following structure:

```json
{
  "score": 0-100,
  "correct": true|false,
  "feedback": "Primary feedback addressing the student's answer quality and key strengths/weaknesses",
  "analysis": "Detailed analysis of the student's reasoning, misconceptions identified, and systems thinking assessment",
  "explanation": "Correct explanation of the concept with mechanistic details, evolutionary context where relevant, and connections across organizational levels",
  "wrong_reason": "Specific identification of errors: misconceptions (teleology, Lamarckian thinking, etc.), missing mechanisms, incorrect terminology, or flawed experimental reasoning"
}
```

## Field Guidelines

**feedback**: 2-3 sentences summarizing overall performance. Highlight what the student understood well and the most critical area for improvement.

**analysis**:
- Assess systems thinking: Did they connect concepts across levels?
- Identify misconceptions: teleology, gene determinism, correlation-causation errors
- Evaluate scientific reasoning: experimental design, data interpretation, evidence use
- Note partial understanding: what they got right even if incomplete

**explanation**:
- Provide mechanistic details (HOW and WHY, not just WHAT)
- Include evolutionary context for adaptations and structures
- Connect across organizational levels when relevant
- Use analogies or diagrams descriptions when helpful
- Link to health, environmental, or applied contexts where appropriate

**wrong_reason**:
- Be specific: "Confused mitosis with meiosis" not "Wrong cell division"
- Identify misconception type: "Teleological reasoning" or "Lamarckian evolution"
- Note scope errors: "Answered at cellular level when question asked about population level"
- Flag experimental flaws: "No control group specified" or "Confused correlation with causation"

## Diagram Suggestions

When helpful, describe diagrams in the explanation field:
- Flow charts for processes (photosynthesis, cellular respiration, protein synthesis)
- Concept maps showing interconnections
- Graphs for population dynamics or physiological responses
- Phylogenetic trees for evolutionary relationships
- Anatomical diagrams with labeled structures

## Tone

Balance rigor with encouragement. Correct errors firmly but constructively. Celebrate accurate reasoning. Guide students toward deeper understanding rather than just listing mistakes.
