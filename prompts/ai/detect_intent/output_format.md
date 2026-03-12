# Intent Detection Output Format

Return intent classification results in the following JSON structure:

```json
{
  "primary_intent": "practice",
  "confidence": 95,
  "secondary_intents": [
    {"intent": "question", "confidence": 30}
  ],
  "requires_clarification": false,
  "suggested_action": "create_practice_session"
}
```

## Field Definitions

**primary_intent** (string): The main intent category detected (question, practice, schedule, plan, help, chat)

**confidence** (integer): Confidence score 0-100 for the primary intent

**secondary_intents** (array): Additional intents detected with their confidence scores, ordered by confidence descending

**requires_clarification** (boolean): True if confidence is below 50% or intent is ambiguous

**suggested_action** (string): Recommended system action based on the detected intent
