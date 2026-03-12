# Prompt Optimization Implementation Plan

**Version:** 1.0
**Date:** 2026-03-12
**Goal:** Optimize all AI prompts to master-level quality for perfect student tutoring
**Estimated Duration:** 7-11 days

## Overview

Transform 15 prompt categories from placeholder-level to production-grade, pedagogically sound prompts. Each category has multiple segments (persona, identity, rules, task_prompt, etc.) that need comprehensive updates.

## Task Breakdown

### Phase 1: Core Tutoring Prompts (Priority 1)

#### Task 1.1: agent_chat - Main Tutor Persona & Identity
**Files:**
- prompts/ai/agent_chat/persona.md
- prompts/ai/agent_chat/identity.md

**Requirements:**
- Warm, encouraging teaching style with Socratic method
- Growth mindset language patterns
- Cultural sensitivity and age-appropriate humor
- Expert tutor identity with multilingual support

**Verification:**
- Minimum 200 words for persona
- Includes all required teaching principles from spec
- Language appropriate for students

#### Task 1.2: agent_chat - Rules & Scoring
**Files:**
- prompts/ai/agent_chat/rules.md
- prompts/ai/agent_chat/scoring_criteria.md

**Requirements:**
- Never give direct answers, guide discovery
- Bloom's taxonomy integration
- Partial credit rubrics
- Process vs outcome evaluation

**Verification:**
- All behavioral rules from spec included
- Scoring criteria covers all cognitive levels

#### Task 1.3: agent_chat - Tool Instructions
**Files:**
- prompts/ai/agent_chat/tool_instructions.md

**Requirements:**
- When to use manage_app for course scheduling
- How to create practice sessions
- When to generate vs retrieve questions
- Progress tracking and plan updates

**Verification:**
- All tool usage scenarios covered
- Clear examples provided
- Minimum 300 words

#### Task 1.4: grade_answer_math - Complete Overhaul
**Files:**
- prompts/ai/grade_answer_math/persona.md
- prompts/ai/grade_answer_math/task_prompt.md
- prompts/ai/grade_answer_math/scoring_criteria.md
- prompts/ai/grade_answer_math/rules.md

**Requirements:**
- Deep mathematical expertise (all domains)
- Multiple solution methods
- Common misconceptions addressed
- Visual representations and diagrams
- Real-world applications

**Verification:**
- Minimum 500 words for persona
- Covers all math domains from spec
- Includes worked examples
- Test with 5 sample math problems

#### Task 1.5: grade_answer_english - Complete Overhaul
**Files:**
- prompts/ai/grade_answer_english/persona.md
- prompts/ai/grade_answer_english/task_prompt.md
- prompts/ai/grade_answer_english/scoring_criteria.md
- prompts/ai/grade_answer_english/rules.md

**Requirements:**
- Grammar and syntax expertise
- Reading comprehension strategies
- Writing structure guidance
- Literary analysis skills
- Cultural context awareness

**Verification:**
- Minimum 500 words for persona
- Test with 5 sample English questions

#### Task 1.6: grade_answer_chinese - Complete Overhaul
**Files:**
- prompts/ai/grade_answer_chinese/persona.md
- prompts/ai/grade_answer_chinese/task_prompt.md
- prompts/ai/grade_answer_chinese/scoring_criteria.md
- prompts/ai/grade_answer_chinese/rules.md

**Requirements:**
- Character structure and radicals
- Tone and pronunciation guidance
- Grammar patterns
- Cultural context and idioms
- Classical vs modern usage

**Verification:**
- Minimum 500 words for persona
- Test with 5 sample Chinese questions

#### Task 1.7: generate_questions - Complete Overhaul
**Files:**
- prompts/ai/generate_questions/persona.md
- prompts/ai/generate_questions/task_prompt.md
- prompts/ai/generate_questions/rules.md

**Requirements:**
- Question design expertise
- Bloom's taxonomy awareness
- Difficulty calibration
- Multiple question types
- Distractor creation for MCQ

**Verification:**
- Generate 10 test questions at different levels
- Verify quality and appropriateness

### Phase 2: Subject-Specific Graders (Priority 2)

#### Task 2.1: grade_answer_physics - Complete Overhaul
**Files:**
- prompts/ai/grade_answer_physics/persona.md
- prompts/ai/grade_answer_physics/task_prompt.md
- prompts/ai/grade_answer_physics/scoring_criteria.md
- prompts/ai/grade_answer_physics/rules.md

**Requirements:**
- Conceptual understanding vs formula application
- Unit analysis and dimensional reasoning
- Free body diagrams
- Common misconceptions
- Real-world phenomena

**Verification:**
- Minimum 500 words for persona
- Test with 5 sample physics problems

#### Task 2.2: grade_answer_chemistry - Complete Overhaul
**Files:**
- prompts/ai/grade_answer_chemistry/persona.md
- prompts/ai/grade_answer_chemistry/task_prompt.md
- prompts/ai/grade_answer_chemistry/scoring_criteria.md
- prompts/ai/grade_answer_chemistry/rules.md

**Requirements:**
- Molecular visualization and bonding
- Stoichiometry and conversions
- Lab safety
- Common errors (balancing, sig figs)
- Real-world applications

**Verification:**
- Minimum 500 words for persona
- Test with 5 sample chemistry problems

#### Task 2.3: grade_answer_biology - Complete Overhaul
**Files:**
- prompts/ai/grade_answer_biology/persona.md
- prompts/ai/grade_answer_biology/task_prompt.md
- prompts/ai/grade_answer_biology/scoring_criteria.md
- prompts/ai/grade_answer_biology/rules.md

**Requirements:**
- Systems thinking
- Evolution and adaptation
- Experimental design
- Common misconceptions
- Health and environmental connections

**Verification:**
- Minimum 500 words for persona
- Test with 5 sample biology questions

#### Task 2.4: grade_answer (General) - Complete Overhaul
**Files:**
- prompts/ai/grade_answer/persona.md
- prompts/ai/grade_answer/task_prompt.md
- prompts/ai/grade_answer/scoring_criteria.md
- prompts/ai/grade_answer/rules.md

**Requirements:**
- Cross-disciplinary grading expertise
- Adaptable to any subject
- General pedagogical principles
- Constructive feedback framework

**Verification:**
- Test with questions from 3 different subjects

### Phase 3: Planning & Assessment (Priority 3)

#### Task 3.1: build_learning_plan - Complete Overhaul
**Files:**
- prompts/ai/build_learning_plan/persona.md
- prompts/ai/build_learning_plan/task_prompt.md
- prompts/ai/build_learning_plan/rules.md

**Requirements:**
- Curriculum design expertise
- Learning science principles
- SMART goals framework
- Spaced repetition scheduling
- Time management and pacing

**Verification:**
- Generate 3 sample learning plans
- Verify pedagogical soundness

#### Task 3.2: optimize_learning_plan - Complete Overhaul
**Files:**
- prompts/ai/optimize_learning_plan/persona.md
- prompts/ai/optimize_learning_plan/task_prompt.md

**Requirements:**
- Performance pattern analysis
- Adaptive pacing
- Resource recommendations
- Motivation maintenance

**Verification:**
- Test with sample performance data

#### Task 3.3: evaluate_learning & score_learning - Complete Overhaul
**Files:**
- prompts/ai/evaluate_learning/persona.md
- prompts/ai/evaluate_learning/task_prompt.md
- prompts/ai/evaluate_learning/scoring_criteria.md
- prompts/ai/score_learning/persona.md
- prompts/ai/score_learning/task_prompt.md
- prompts/ai/score_learning/scoring_criteria.md

**Requirements:**
- Assessment expertise
- Multiple evaluation dimensions
- Trend analysis
- Actionable recommendations

**Verification:**
- Test with sample student data

### Phase 4: Utility Prompts (Priority 4)

#### Task 4.1: detect_intent - Complete Overhaul
**Files:**
- prompts/ai/detect_intent/persona.md
- prompts/ai/detect_intent/task_prompt.md
- prompts/ai/detect_intent/output_format.md

**Requirements:**
- Intent classification expertise
- Context awareness
- Confidence thresholds
- Multi-intent detection

**Verification:**
- Test with 20 sample user inputs
- Verify accuracy >90%

#### Task 4.2: compress_session - Complete Overhaul
**Files:**
- prompts/ai/compress_session/persona.md
- prompts/ai/compress_session/task_prompt.md

**Requirements:**
- Preserve learning progress
- Maintain key insights
- Keep action items
- Note follow-up areas

**Verification:**
- Test with sample conversation
- Verify no information loss

## Verification Strategy

### Per-Task Verification
Each task includes specific verification steps:
- Word count minimums met
- All requirements from spec included
- Test with sample inputs
- Quality review

### Phase Completion Verification
After each phase:
- All files updated and committed
- No placeholder text remains
- Prompts compose correctly
- Integration tests pass

### Final Verification
Before completion:
- All 15 categories updated
- Expert review (subject matter + pedagogy)
- Student testing (clarity, helpfulness)
- A/B comparison with baseline

## Execution Order

### Sequential Dependencies
- Phase 1 must complete before Phase 2
- Phase 2 must complete before Phase 3
- Phase 3 must complete before Phase 4

### Parallel Opportunities
Within each phase, tasks can run in parallel:
- Phase 1: Tasks 1.4, 1.5, 1.6, 1.7 (subject graders) can run parallel
- Phase 2: All tasks (2.1-2.4) can run parallel
- Phase 3: All tasks (3.1-3.3) can run parallel
- Phase 4: Both tasks (4.1-4.2) can run parallel

## Timeline Estimate

- **Phase 1**: 2-3 days (7 tasks, some parallel)
- **Phase 2**: 2-3 days (4 tasks, all parallel)
- **Phase 3**: 1-2 days (3 tasks, all parallel)
- **Phase 4**: 1 day (2 tasks, parallel)
- **Testing & Validation**: 1-2 days
- **Total**: 7-11 days

## Success Criteria

### Quantitative
- ✅ All 15 prompt categories updated
- ✅ All segments have substantive content (no placeholders)
- ✅ Persona segments: minimum 200 words
- ✅ Task_prompt segments: minimum 300 words
- ✅ Subject graders: minimum 500 words each

### Qualitative
- ✅ Deep subject expertise demonstrated
- ✅ Pedagogical principles embedded
- ✅ Age-appropriate language
- ✅ Examples and guidance included
- ✅ Error handling covered

### Validation
- ✅ Test with 10 sample inputs per category
- ✅ Expert review completed
- ✅ Student feedback positive
- ✅ Prompts compose correctly
- ✅ No integration errors

## Deliverables

1. **Updated Prompt Files**: 15 categories × multiple segments
2. **Test Cases**: Sample inputs and expected outputs
3. **Validation Report**: Expert review results
4. **Documentation**: Design rationale and usage guide

---

**End of Implementation Plan**
