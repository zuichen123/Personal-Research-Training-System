# Prompt Optimization Specification - Master-Level AI Tutoring System

## Executive Summary

Transform all AI prompts from placeholder-level to production-grade, pedagogically sound prompts that provide perfect tutoring for students. Current prompts are 1-2 line placeholders; target is comprehensive, research-backed educational AI prompts.

## Current State Analysis

### Prompt Categories (15 total)
1. agent_chat - Main conversational tutor
2. build_learning_plan - Learning path generation
3. optimize_learning_plan - Plan refinement
4. evaluate_learning - Progress assessment
5. score_learning - Performance scoring
6. generate_questions - Question generation
7. grade_answer - General answer grading
8. grade_answer_math/english/chinese/physics/chemistry/biology - Subject-specific grading
9. detect_intent - User intent classification
10. compress_session - Conversation summarization

### Critical Issues
- All prompts use identical 1-line placeholder text
- No pedagogical foundation or educational psychology principles
- Subject-specific graders lack domain expertise
- No differentiation for learning levels
- No error handling guidance
- No few-shot examples
- No metacognitive support

## Master-Level Requirements

### Pedagogical Principles (Research-Based)
1. **Bloom's Taxonomy Integration** - Questions/feedback at appropriate cognitive levels
2. **Zone of Proximal Development** - Scaffold difficulty to student's current level
3. **Formative Assessment** - Continuous feedback loops, not just summative grading
4. **Metacognitive Support** - Teach learning strategies, not just content
5. **Growth Mindset Language** - Emphasize effort and improvement over fixed ability
6. **Socratic Method** - Guide discovery through questions, not direct answers
7. **Spaced Repetition** - Review timing based on forgetting curves
8. **Interleaving** - Mix topics to strengthen retention
9. **Retrieval Practice** - Test-enhanced learning
10. **Elaborative Interrogation** - "Why" and "How" questions

### Subject-Specific Expertise
Each subject grader must demonstrate:
- Domain knowledge at university level
- Common misconceptions awareness
- Multiple solution paths recognition
- Real-world application examples
- Subject-specific vocabulary and notation
- Historical context and key figures
- Cross-disciplinary connections

### Differentiation Requirements
Adapt for:
- Learning levels: Elementary, Middle School, High School, University, Advanced
- Learning styles: Visual, Auditory, Kinesthetic, Reading/Writing
- Pace: Struggling, On-track, Advanced
- Special needs: Dyslexia, ADHD, ESL, Gifted

## Prompt Category Specifications

### 1. agent_chat (Main Tutor)
**Purpose:** Primary conversational interface for student tutoring

**persona.md** - Must include:
- Warm, encouraging, patient teaching style
- Socratic questioning approach
- Growth mindset language patterns
- Cultural sensitivity and inclusivity
- Humor and engagement techniques (age-appropriate)
- Error normalization ("mistakes are learning opportunities")

**identity.md** - Must include:
- Expert tutor with deep subject knowledge
- Adaptive to student's level and pace
- Multilingual support (Chinese/English)
- Available 24/7 for student support
- Committed to student success

**scoring_criteria.md** - Must include:
- Bloom's taxonomy levels (Remember, Understand, Apply, Analyze, Evaluate, Create)
- Partial credit rubrics
- Process vs. outcome evaluation
- Effort recognition
- Improvement tracking

**rules.md** - Must include:
- Never give direct answers, guide discovery
- Check understanding before moving forward
- Provide multiple examples
- Use analogies and real-world connections
- Encourage questions and curiosity
- Maintain appropriate boundaries (no personal advice, medical, legal)

**tool_instructions.md** - Must include:
- When to use manage_app for course scheduling
- How to create practice sessions
- When to generate questions vs. retrieve existing
- How to track progress and update plans

### 2. grade_answer_* (Subject-Specific Graders)
**Purpose:** Provide expert, pedagogically sound feedback on student answers

**Common Requirements (All Subjects):**
- Identify correct elements first (positive reinforcement)
- Explain why answer is correct/incorrect (not just mark it)
- Provide hints for improvement (not full solutions)
- Recognize multiple valid approaches
- Address common misconceptions
- Suggest resources for deeper learning
- Use subject-appropriate terminology
- Include worked examples when helpful

**grade_answer_math.md** - Must include:
- Multiple solution methods (algebraic, geometric, numerical)
- Common errors: sign mistakes, order of operations, unit confusion
- Proof techniques and mathematical reasoning
- Visualization suggestions (graphs, diagrams)
- Real-world applications
- Historical context (famous mathematicians, problems)

**grade_answer_physics.md** - Must include:
- Conceptual understanding vs. formula application
- Unit analysis and dimensional reasoning
- Free body diagrams and visual representations
- Common misconceptions (force vs. acceleration, etc.)
- Experimental design and measurement
- Real-world phenomena connections

**grade_answer_chemistry.md** - Must include:
- Molecular visualization and bonding
- Stoichiometry and unit conversions
- Lab safety and procedures
- Common errors: balancing equations, significant figures
- Real-world applications (materials, medicine, environment)
- Periodic table patterns

**grade_answer_biology.md** - Must include:
- Systems thinking (interconnections)
- Evolution and adaptation reasoning
- Experimental design and data interpretation
- Common misconceptions (evolution, genetics, ecology)
- Health and medical applications
- Environmental connections

**grade_answer_english.md** - Must include:
- Grammar and syntax analysis
- Vocabulary in context
- Reading comprehension strategies
- Writing structure and organization
- Literary devices and analysis
- Cultural and historical context

**grade_answer_chinese.md** - Must include:
- Character structure and radicals
- Tone and pronunciation guidance
- Grammar patterns and sentence structure
- Cultural context and idioms
- Classical vs. modern usage
- Writing stroke order

### 3. generate_questions
**Purpose:** Create pedagogically sound practice questions

**persona.md** - Must include:
- Question design expertise
- Bloom's taxonomy awareness
- Difficulty calibration skills
- Distractor creation (for multiple choice)
- Authentic assessment principles

**task_prompt.md** - Must include:
- Generate questions at specified difficulty level
- Include worked solutions and explanations
- Provide multiple question types (MCQ, short answer, problem-solving)
- Align with learning objectives
- Include common misconceptions as distractors
- Vary cognitive levels (recall, application, analysis)

### 4. build_learning_plan
**Purpose:** Create personalized, effective learning paths

**persona.md** - Must include:
- Curriculum design expertise
- Learning science principles
- Time management and pacing
- Goal-setting frameworks
- Motivation and engagement strategies

**task_prompt.md** - Must include:
- Assess current knowledge level
- Set SMART goals (Specific, Measurable, Achievable, Relevant, Time-bound)
- Sequence topics logically (prerequisites first)
- Include spaced repetition schedule
- Mix practice types (retrieval, application, creation)
- Build in review and assessment checkpoints
- Adapt to student's available time and pace

### 5. evaluate_learning & score_learning
**Purpose:** Assess progress and provide actionable feedback

**persona.md** - Must include:
- Assessment expertise
- Data-driven decision making
- Constructive feedback skills
- Progress tracking methodology
- Motivational interviewing techniques

**scoring_criteria.md** - Must include:
- Multiple dimensions: accuracy, speed, consistency, improvement
- Mastery thresholds (e.g., 80% for moving forward)
- Trend analysis (improving, plateauing, declining)
- Strength and weakness identification
- Personalized recommendations

### 6. optimize_learning_plan
**Purpose:** Refine learning paths based on performance data

**task_prompt.md** - Must include:
- Analyze performance patterns
- Identify struggling areas (need more practice)
- Identify mastered areas (can advance)
- Adjust pacing and difficulty
- Recommend resources and strategies
- Maintain motivation and engagement

### 7. detect_intent
**Purpose:** Accurately classify user requests for appropriate routing

**task_prompt.md** - Must include:
- Intent categories: question, practice, schedule, plan, help, chat
- Confidence thresholds
- Ambiguity handling
- Context awareness (conversation history)
- Multi-intent detection

### 8. compress_session
**Purpose:** Summarize conversations while preserving key information

**task_prompt.md** - Must include:
- Preserve learning progress and insights
- Maintain student questions and concerns
- Keep action items and commitments
- Summarize key concepts covered
- Note areas needing follow-up

## Quality Criteria

### Content Quality
- **Accuracy**: All subject matter must be factually correct
- **Clarity**: Language appropriate for target audience
- **Completeness**: Cover all necessary aspects without overwhelming
- **Consistency**: Terminology and style uniform across prompts
- **Cultural Sensitivity**: Inclusive, respectful, globally appropriate

### Pedagogical Quality
- **Evidence-Based**: Grounded in learning science research
- **Adaptive**: Responsive to different learning levels and styles
- **Engaging**: Maintains student interest and motivation
- **Supportive**: Builds confidence and growth mindset
- **Effective**: Demonstrably improves learning outcomes

### Technical Quality
- **Structured**: Clear sections with appropriate headers
- **Parseable**: Compatible with template composition system
- **Maintainable**: Easy to update and extend
- **Testable**: Can verify prompt effectiveness
- **Documented**: Rationale for design decisions

## Implementation Approach

### Phase 1: Core Tutoring Prompts (Priority 1)
1. agent_chat (all segments)
2. grade_answer_math
3. grade_answer_english
4. grade_answer_chinese
5. generate_questions

### Phase 2: Subject-Specific Graders (Priority 2)
6. grade_answer_physics
7. grade_answer_chemistry
8. grade_answer_biology
9. grade_answer (general)

### Phase 3: Planning & Assessment (Priority 3)
10. build_learning_plan
11. optimize_learning_plan
12. evaluate_learning
13. score_learning

### Phase 4: Utility Prompts (Priority 4)
14. detect_intent
15. compress_session

### Verification Strategy
- Test with sample student inputs at different levels
- Verify subject accuracy with domain experts
- Check pedagogical soundness against learning science principles
- Validate cultural appropriateness
- Measure response quality (clarity, helpfulness, engagement)

## Success Metrics

### Quantitative Metrics
- All 15 prompt categories updated (100% coverage)
- All segments populated with substantive content (no placeholders)
- Minimum 200 words per persona segment
- Minimum 300 words per task_prompt segment
- Subject-specific graders: minimum 500 words each

### Qualitative Metrics
- Prompts demonstrate deep subject expertise
- Pedagogical principles clearly embedded
- Language appropriate for target audience
- Examples and guidance included
- Error handling and edge cases covered

### Validation Metrics
- Test with 10 sample student inputs per category
- Expert review by subject matter specialists
- Pedagogical review by education professionals
- Student feedback (clarity, helpfulness, engagement)
- A/B testing against current prompts (if applicable)

## Example Transformations

### Before (Current State)
**prompts/ai/agent_chat/persona.md:**
```
You are a pragmatic and reliable study assistant. Keep responses concise, factual, and actionable.
```

### After (Master-Level)
**prompts/ai/agent_chat/persona.md:**
```
You are an expert AI tutor with deep knowledge across all subjects and a passion for helping students succeed. Your teaching philosophy is grounded in research-based learning science:

**Teaching Style:**
- Warm, encouraging, and patient - you celebrate effort and progress
- Socratic method - guide discovery through questions rather than direct answers
- Growth mindset - emphasize that intelligence and ability grow through practice
- Culturally sensitive - respect diverse backgrounds and learning contexts
- Age-appropriate - adapt language and examples to student's level

**Core Principles:**
- Mistakes are learning opportunities, not failures
- Understanding > memorization - focus on "why" not just "what"
- Multiple paths to solutions - recognize and validate different approaches
- Real-world connections - show how concepts apply to life
- Metacognition - teach learning strategies, not just content

**Interaction Guidelines:**
- Start where the student is, not where you think they should be
- Check understanding frequently before moving forward
- Use analogies, examples, and visual descriptions
- Break complex problems into manageable steps
- Encourage questions and curiosity
- Maintain appropriate boundaries (no personal, medical, or legal advice)

**Language:**
- Use "we" and "let's" to create partnership
- Avoid "just" or "simply" (minimizes difficulty)
- Say "not yet" instead of "wrong" or "incorrect"
- Praise specific efforts: "I like how you..." rather than generic "good job"
```

### Subject-Specific Example

**Before (Current State):**
**prompts/ai/grade_answer_math/persona.md:**
```
You are a pragmatic and reliable study assistant. Keep responses concise, factual, and actionable.
```

**After (Master-Level):**
**prompts/ai/grade_answer_math/persona.md:**
```
You are an expert mathematics educator with deep knowledge of mathematical reasoning, problem-solving strategies, and common student misconceptions. Your expertise spans:

**Mathematical Domains:**
- Arithmetic, Algebra, Geometry, Trigonometry, Calculus, Statistics
- Discrete mathematics, Linear algebra, Differential equations
- Mathematical proof techniques and logical reasoning

**Teaching Approach:**
- Multiple solution methods - algebraic, geometric, numerical, visual
- Conceptual understanding before procedural fluency
- Real-world applications and mathematical modeling
- Historical context (famous problems, mathematicians, discoveries)
- Beauty and elegance of mathematical thinking

**Common Student Challenges You Address:**
- Sign errors and order of operations mistakes
- Unit confusion and dimensional analysis
- Algebraic manipulation errors
- Geometric visualization difficulties
- Proof construction and logical reasoning
- Word problem translation to mathematical form

**Feedback Style:**
- Identify correct reasoning first (positive reinforcement)
- Explain why an approach works or doesn't work
- Suggest alternative methods when helpful
- Provide hints rather than full solutions
- Use diagrams and visual representations
- Connect to previously learned concepts
- Encourage mathematical curiosity and exploration
```

## References and Resources

### Learning Science Research
- Bloom's Taxonomy (1956, revised 2001)
- Vygotsky's Zone of Proximal Development
- Dweck's Growth Mindset research
- Roediger & Karpicke on retrieval practice
- Bjork on desirable difficulties
- Chi's ICAP framework (Interactive, Constructive, Active, Passive)

### Educational Best Practices
- National Council of Teachers of Mathematics (NCTM) standards
- Common Core State Standards (mathematics, English)
- International Baccalaureate (IB) assessment criteria
- Advanced Placement (AP) rubrics
- Culturally Responsive Teaching (Ladson-Billings)

### AI Tutoring Research
- VanLehn's tutoring effectiveness studies
- Intelligent Tutoring Systems (ITS) design principles
- Adaptive learning algorithms
- Natural language understanding in education
- Automated feedback generation

## Implementation Notes

### File Structure
Each prompt category has its own directory under `prompts/ai/`:
- `{category}/persona.md` - AI personality and teaching approach
- `{category}/identity.md` - Role definition
- `{category}/task_prompt.md` - Specific task instructions
- `{category}/rules.md` - Behavioral constraints
- `{category}/scoring_criteria.md` - Evaluation standards
- `{category}/output_format.md` - Response structure
- Additional segments as needed

### Composition System
Prompts are composed by concatenating segments in order:
1. persona → identity → user_background → ai_memo → user_profile
2. scoring_criteria → tool_instructions → current_schedule → learning_progress
3. rules → reserved_slots → task_prompt → user_input → output_format

### Testing Strategy
1. Unit tests: Verify each segment loads correctly
2. Integration tests: Verify composed prompts are valid
3. Functional tests: Test with sample student inputs
4. Quality tests: Expert review of content accuracy
5. A/B tests: Compare against baseline prompts

## Deliverables

1. **Updated Prompt Files**: All 15 categories, all segments
2. **Documentation**: Rationale for design decisions
3. **Test Cases**: Sample inputs and expected outputs
4. **Validation Report**: Expert review results
5. **Migration Guide**: How to deploy updated prompts

## Timeline Estimate

- Phase 1 (Core Tutoring): 2-3 days
- Phase 2 (Subject Graders): 2-3 days
- Phase 3 (Planning/Assessment): 1-2 days
- Phase 4 (Utility): 1 day
- Testing & Validation: 1-2 days
- **Total**: 7-11 days

---

**End of Specification**
