Return ONLY JSON with the following structure:

{
  "score": 0-100,
  "correct": true|false,
  "feedback": "Primary assessment message highlighting key strengths and areas for improvement",
  "analysis": "Detailed breakdown of answer quality, covering accuracy, language use, and comprehension",
  "explanation": "Educational commentary explaining why the answer is correct/incorrect and what makes a strong response",
  "wrong_reason": "Specific diagnosis of errors if incorrect, with examples and corrections"
}

## Field Guidelines

**score (0-100)**
Holistic assessment reflecting accuracy, language quality, and communication effectiveness. Consider both content correctness and linguistic proficiency.

**correct (boolean)**
True if the answer demonstrates adequate understanding and accuracy relative to the answer key. Minor language errors don't necessarily make an answer incorrect if comprehension is sound.

**feedback (concise, constructive)**
2-3 sentences summarizing overall performance. Acknowledge strengths, identify priority improvements. Example: "Your answer demonstrates good comprehension of the main idea, but contains several verb tense errors that affect clarity. The vocabulary choices are appropriate, though 'effect' should be 'affect' in this context."

**analysis (detailed, structured)**
Comprehensive evaluation covering:
- Content accuracy and completeness
- Grammar and syntax quality
- Vocabulary appropriateness and precision
- Organization and coherence
- Specific examples of what works well and what needs improvement

**explanation (educational)**
Clarify why the answer key is correct, what principles or knowledge it reflects, and what distinguishes strong responses from weak ones. Help the learner understand the standard they're working toward.

**wrong_reason (diagnostic, specific)**
If incorrect, provide:
- Exact errors with corrections (e.g., "Line 2: 'was went' → 'went' (double past tense error)")
- Comprehension gaps identified (e.g., "Missed the implied contrast between the two characters")
- Pattern diagnosis (e.g., "Consistent confusion between present perfect and simple past")
- Improvement resources (e.g., "Review: irregular verb forms, conditional sentence structures")

Omit or use empty string if answer is fully correct.

## Example Corrections Format

"Grammar: 'They was going' → 'They were going' (subject-verb agreement). Vocabulary: 'effect' → 'affect' (verb form needed here). Comprehension: The passage suggests irony, not literal meaning—reconsider the author's tone."
