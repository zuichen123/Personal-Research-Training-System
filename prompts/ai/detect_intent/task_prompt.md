# Intent Detection Task

Analyze user input and classify it into one of the following intent categories. Apply confidence scoring and handle multi-intent scenarios.

## Intent Categories

**question**: User seeks information or explanation
- "What is photosynthesis?"
- "How do I solve this equation?"
- "Can you explain Newton's laws?"
- "Why does this happen?"

**practice**: User wants exercises or practice sessions
- "I want to practice math"
- "Give me some questions"
- "Let's do some exercises"
- "Quiz me on biology"

**schedule**: User queries about timing or calendar
- "When is my next lesson?"
- "Show my calendar"
- "What's my schedule today?"
- "Do I have class tomorrow?"

**plan**: User requests study planning or preparation
- "Create a study plan"
- "Help me prepare for exam"
- "I need a learning roadmap"
- "Plan my week"

**help**: User expresses confusion or needs assistance
- "I'm stuck"
- "I don't understand"
- "This is confusing"
- "Can you help me?"

**chat**: Casual conversation or social interaction
- "How are you?"
- "Tell me a joke"
- "Good morning"
- "Thanks!"

## Classification Workflow

1. **Analyze Input**: Extract keywords, phrases, and grammatical patterns from user message
2. **Check Context**: Review conversation history for disambiguation clues
3. **Score Confidence**: Assign 0-100 confidence score to each potential intent based on:
   - Keyword match strength
   - Sentence structure alignment
   - Contextual relevance
4. **Handle Multi-Intent**: Detect when multiple intents coexist (e.g., "I want to practice math and check my schedule")
5. **Apply Thresholds**:
   - High confidence (>80%): Clear, unambiguous intent
   - Medium confidence (50-80%): Probable intent with some uncertainty
   - Low confidence (<50%): Requires clarification
6. **Return Classification**: Output primary intent, secondary intents if applicable, and suggested action

## Confidence Thresholds

- **>80%**: Proceed with high confidence classification
- **50-80%**: Proceed with medium confidence, consider context
- **<50%**: Request user clarification before proceeding
