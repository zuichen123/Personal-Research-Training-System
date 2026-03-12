# Implementation Plan Review - Self-Study-Tool Enhancement

**Reviewer:** oh-my-claudecode:critic
**Date:** 2026-03-11
**Review Mode:** THOROUGH → ADVERSARIAL (escalated due to critical findings)

---

## VERDICT: REJECT

---

## Overall Assessment

The implementation plan demonstrates solid architectural thinking and comprehensive phase breakdown, but contains **critical gaps** that would block execution. The plan makes several unvalidated assumptions about existing infrastructure, lacks concrete answers to open questions from requirements, and proposes 35 commits across 7 sprints without addressing fundamental blockers identified in the requirements document.

After discovering multiple CRITICAL findings during initial review, I escalated to ADVERSARIAL mode and uncovered additional systemic issues around feasibility, dependency management, and missing prerequisite work.

---

## Pre-commitment Predictions vs Actual Findings

**Predicted Issues:**
1. Missing database migration strategy from current schema (migration 023) to proposed schema (starting at 024)
2. Undefined AI model selection and cost management strategy
3. Network search integration details missing (MCP exa mentioned but not configured)
4. Prompt engineering approach too vague for "professional-grade" requirement
5. Flutter UI complexity underestimated for conversational flows

**Actual Findings:**
- ✅ Prediction #1 CONFIRMED: Migration gap exists (023 → 024 jump)
- ✅ Prediction #2 CONFIRMED: No AI model selection or cost strategy defined
- ✅ Prediction #3 CONFIRMED: MCP exa mentioned but no configuration exists in codebase
- ✅ Prediction #4 CONFIRMED: Prompts described generically without actual content
- ✅ Prediction #5 CONFIRMED: Conversational UI treated as trivial ("reuse pattern")
- ❌ Additional finding: Module naming inconsistency (`user_profile` vs `profile`)
- ❌ Additional finding: Missing prerequisite work from requirements Priority 1 list

---

## Critical Findings (blocks execution)

### 1. Requirements Open Questions Not Addressed
**Evidence:** Requirements doc Section 16 lists 10 open questions that "need answers before planning can proceed." Plan proceeds anyway without answering them.

**Specific Unanswered Questions:**
- `[ ] AI Model Selection` — Plan says "use existing AI service" but doesn't specify which model(s)
- `[ ] Network Search Provider` — Plan says "leverage MCP exa server (already configured)" but no mcp.json exists in codebase
- `[ ] Resource Storage` — Plan doesn't specify local vs cloud
- `[ ] Onboarding Trigger` — Plan doesn't specify when Head Teacher initializes
- `[ ] Grading Appeals` — Plan includes grading but no appeal mechanism
- `[ ] Difficulty Validation` — Plan says "AI-generated via structured prompts" but requirements ask "AI-generated or human-curated?"

**Why this matters:** These are foundational decisions that affect every subsequent implementation choice. Proceeding without answers will cause rework.

**Fix:** Create a separate "Architecture Decision Record" document that explicitly answers all 10 open questions with rationale before implementation begins.

**Confidence:** HIGH

---

### 2. False Claim: MCP Exa "Already Configured"
**Evidence:** Plan states in Phase 4.1: `"Use MCP exa server via existing MCP client"` and `"Leverage MCP exa server (already configured)"` in Architecture Decisions.

**Verification:**
- Searched for mcp.json, .mcp.json: NOT FOUND
- Searched codebase for "exa" references: ZERO results in Go code
- Requirements Section 10.2 explicitly lists network search as an OPEN QUESTION

**Why this matters:** Phase 4 (Content Delivery) depends on this capability. Without it, content recommendation feature cannot be implemented.

**Fix:** Either (1) add MCP exa configuration as Phase 0 prerequisite task with setup instructions, or (2) implement custom HTTP-based search client with fallback strategy.

**Confidence:** HIGH

---

### 3. Module Naming Inconsistency: `user_profile` vs `profile`
**Evidence:**
- Plan consistently references `user_profile` module (e.g., Phase 1.1: "Must integrate with existing `user_profile` module")
- Actual codebase has `internal/modules/profile/` (verified via directory listing)
- Plan Phase 1.5 migration file: `migrations/sqlite/025_enhance_user_profile.sql` references table `user_profile`

**Why this matters:** Every code reference to `user_profile` module will fail. This is a systematic error affecting multiple phases.

**Fix:** Global find-replace in plan: `user_profile` module → `profile` module. Verify table name is actually `user_profile` or `user_profiles` in existing schema.

**Confidence:** HIGH

---

### 4. Migration Number Gap Without Explanation
**Evidence:**
- Latest migration in codebase: `023_add_chapter_to_questions.sql`
- Plan starts at: `024_create_onboarding_state.sql`
- No explanation of how to handle potential conflicts if migration 024 is created elsewhere

**Why this matters:** If development continues in parallel, migration number collisions will occur. SQLite migration systems typically fail on duplicate numbers.

**Fix:** Add explicit instruction: "Before starting Phase 1.1, run `git pull` and verify latest migration number. Adjust all subsequent migration numbers if conflicts exist."

**Confidence:** HIGH

---


### 5. Requirements Priority 1 Work Not Included in Plan
**Evidence:** Requirements Section 16 lists 5 "Priority 1: Critical for MVP" items that must be completed before implementation. Plan jumps directly to Phase 1 implementation without addressing these.

**Missing Priority 1 Items:**
1. ❌ "Define AI Model & Cost Strategy" - Plan assumes existing AI service without specifying model or budget
2. ❌ "Implement Network Search" - Plan assumes MCP exa exists (it doesn't)
3. ⚠️ "Design Database Schema" - Plan includes migrations but no holistic schema design document
4. ❌ "Define Difficulty Rubrics" - Plan says "AI-generated" but no initial rubrics provided
5. ❌ "Establish Guardrails" - Plan has zero mention of rate limits, quotas, or validation

**Why this matters:** Requirements explicitly state these "block all AI features." Skipping them guarantees implementation failure.

**Fix:** Add "Phase 0: Prerequisites" before Phase 1 with all 5 Priority 1 items as separate commits. Each must have acceptance criteria and verification steps.

**Confidence:** HIGH

---

## Major Findings (causes significant rework)

### 6. Onboarding Flow Lacks Concrete Implementation Details
**Evidence:** Phase 1.3 describes `OnboardingResponse` structure but doesn't specify:
- How many questions (requirements say "N-question" but N is undefined)
- Question generation logic (static list? AI-generated? Adaptive based on previous answers?)
- How to extract structured data from conversational responses (parsing strategy?)
- What happens if AI returns malformed JSON

**Why this matters:** "Conversational Q&A interface" is the core UX differentiator. Vague implementation will lead to multiple revision cycles.

**Fix:** Add detailed subsection to Phase 1.3:
- Define N=10 questions with specific topics (name, age, subjects, goals, availability, learning style, etc.)
- Specify extraction strategy: structured output format with JSON schema validation
- Add error handling: retry with simplified prompt, fallback to form-based input
- Include example prompt and expected response

**Confidence:** HIGH

---

### 7. Schedule Generation Algorithm Undefined
**Evidence:** Phase 2.3 says "AI generates realistic course schedules" but provides no algorithm or constraints:
- How to calculate minimum time required per chapter?
- How to handle availability conflicts?
- What's the logic for "maintaining logical dependencies"?
- How to validate schedule feasibility (requirements Section 15.10)?

**Why this matters:** Schedule quality is a key success metric (adherence rate >60%). Poor algorithm = user frustration.

**Fix:** Add algorithmic pseudocode to Phase 2.3 with validation steps for feasibility checking.

**Confidence:** HIGH

---

### 8. Difficulty Rubric Generation Has No Validation
**Evidence:** Phase 3.3 proposes AI-generated difficulty rubrics but no validation against real questions, no human review, no recalibration mechanism.

**Why this matters:** Difficulty calibration is a core quality metric. Unvalidated rubrics = inaccurate difficulty ratings.

**Fix:** Add validation step: generate rubric, test against 20 sample questions, calculate agreement rate (≥85%), iterate if needed.

**Confidence:** HIGH

---

### 9. Grading System Missing Partial Credit Logic
**Evidence:** Phase 5.2 describes `GradingResult` but requirements Section 5.5 explicitly requires "partial credit supported for multi-step problems." No specification of how partial credit is calculated.

**Why this matters:** Math/science problems require partial credit. Binary correct/incorrect is insufficient.

**Fix:** Add partial credit rules per question type, update `GradingResult` structure, include step-by-step evaluation in prompts.

**Confidence:** HIGH

---

### 10. Head Teacher Orchestration Lacks Concrete Triggers
**Evidence:** Phase 6.1 describes responsibilities but doesn't specify when `MonitorProgress` runs, what thresholds trigger adjustments, or how interventions are prioritized.

**Why this matters:** Without triggers, Head Teacher is passive. Requirements expect proactive orchestration.

**Fix:** Add trigger specification table with conditions, actions, priorities, and frequencies.

**Confidence:** HIGH

---


## Minor Findings (suboptimal but functional)

### 11. Commit Messages Don't Follow Project Convention
**Evidence:** Plan uses format like `feat: add onboarding state table` but project CLAUDE.md specifies Chinese commit format with specific prefixes (feat/fix/chore).

**Fix:** Update all commit message examples to match project convention or clarify that English is acceptable.

---

### 12. Flutter UI Complexity Underestimated
**Evidence:** Phase 1.6 says "reuse `ai_multimodal_message_input.dart` pattern" but conversational onboarding requires: progress tracking, skip/resume logic, state persistence, completion celebration. This is more than a simple reuse.

**Fix:** Acknowledge UI complexity, estimate 2-3 days for Flutter implementation per phase, not bundled as single commit.

---

### 13. Testing Strategy Absent Until Phase 7
**Evidence:** Plan defers all testing to Phase 7.4. Requirements expect "tests pass with >80% coverage" but no test-as-you-go approach.

**Fix:** Add test files alongside implementation in each phase. Update commit pattern: implementation commit + test commit.

---

### 14. No Rollback Strategy for Failed Migrations
**Evidence:** Plan proposes 9 new migration files but no rollback/down migrations or recovery strategy if migration fails mid-execution.

**Fix:** Add rollback SQL for each migration or document manual recovery steps.

---

## What's Missing (gaps not captured above)

- **Error Handling Strategy:** No specification of how to handle AI timeouts, rate limits, or malformed responses across all phases
- **Logging and Observability:** No mention of logging AI interactions, performance metrics, or debugging tools
- **Data Migration Plan:** How to migrate existing users to new schema? Backfill profile data?
- **API Versioning:** New endpoints added but no versioning strategy if breaking changes needed
- **Localization:** Requirements mention Chinese prompts but plan doesn't address i18n for UI strings
- **Performance Benchmarks:** No load testing or performance targets defined
- **Security Review:** No mention of input validation, SQL injection prevention, or API authentication
- **Deployment Strategy:** How to deploy 35 commits across 7 sprints? Continuous deployment or batched releases?

---

## Multi-Perspective Notes

### Executor Perspective (Can I actually implement this?)
- **Blocked on:** AI model selection, MCP exa setup, difficulty rubrics, guardrails definition
- **Ambiguous:** Onboarding question count, schedule algorithm, partial credit rules, trigger thresholds
- **Missing context:** How existing `profile` module works, what AI tools already exist, current prompt quality

### Stakeholder Perspective (Does this solve the problem?)
- **Concern:** Plan focuses on infrastructure but doesn't demonstrate how it delivers "professional-grade tutoring comparable to human expert teachers"
- **Missing:** User journey walkthrough showing how features connect end-to-end
- **Risk:** 35 commits over 7 sprints = 3-4 months. Is this timeline realistic for MVP?

### Skeptic Perspective (What could go wrong?)
- **AI Quality Risk:** Plan assumes AI will generate good prompts, accurate grades, realistic schedules. No validation or fallback.
- **Scope Creep Risk:** 35 commits is already large. Requirements have 50+ acceptance criteria. Mismatch likely.
- **Dependency Hell:** Each phase depends on previous phases. One delay cascades to all subsequent work.
- **Cost Explosion:** Heavy AI usage (onboarding, scheduling, teaching, grading, content search) with no cost controls.

---


## Ambiguity Risks (statements with multiple valid interpretations)

### Ambiguity 1: "Use existing AI service"
**Quote from plan:** `"Use existing AI service (internal/modules/ai) with Claude/Gemini/OpenAI clients"`

**Interpretation A:** Use whichever client is currently configured (check runtime config)
**Interpretation B:** Support all three clients with fallback logic
**Interpretation C:** Let user choose which client to use per feature

**Risk if wrong interpretation chosen:** If Interpretation A and no client is configured, all AI features fail. If Interpretation B, significant additional complexity for fallback logic.

---

### Ambiguity 2: "Conversational Q&A interface"
**Quote from plan:** `"Conversational chat interface (reuse ai_multimodal_message_input.dart pattern)"`

**Interpretation A:** Simple back-and-forth Q&A (AI asks, user answers, repeat)
**Interpretation B:** Natural language conversation where user can ask clarifying questions
**Interpretation C:** Guided wizard with conversational tone but structured flow

**Risk if wrong interpretation chosen:** Interpretation B requires complex dialog management. Interpretation C is simpler but may not meet "conversational" requirement.

---

### Ambiguity 3: "Professional-grade prompts"
**Quote from plan:** `"All prompts include: role definition, constraints, output format, examples"`

**Interpretation A:** Follow standard prompt engineering template (system/user/assistant pattern)
**Interpretation B:** Prompts must be validated by education professionals
**Interpretation C:** Prompts must achieve specific quality metrics (grading accuracy ≥90%)

**Risk if wrong interpretation chosen:** Interpretation A is achievable but may not meet "professional-grade" bar. Interpretation B requires external validation (not in plan).

---

## Verdict Justification

**Why REJECT:**

This plan cannot be executed as written due to 5 CRITICAL blockers:
1. Requirements open questions unanswered (foundational decisions missing)
2. False infrastructure claims (MCP exa doesn't exist)
3. Module naming errors (systematic throughout plan)
4. Priority 1 prerequisite work skipped (blocks all AI features)
5. Migration numbering conflicts (will cause deployment failures)

Additionally, 5 MAJOR findings would cause significant rework during implementation:
- Onboarding flow too vague to implement
- Schedule generation algorithm undefined
- Difficulty rubrics have no validation
- Grading system missing partial credit
- Head Teacher lacks concrete triggers

**Review Mode:** Started in THOROUGH mode. After discovering 5 CRITICAL findings in Phase 2 review, escalated to ADVERSARIAL mode. Expanded scope to check adjacent phases and uncovered additional issues in Phases 3-6.

**Realist Check Recalibrations:** None. All CRITICAL findings involve missing prerequisites or false claims that would cause immediate implementation failure. All MAJOR findings involve specification gaps that would require multiple revision cycles.

**What needs to change for ACCEPT:**

1. **Create Phase 0: Prerequisites** (5 commits)
   - Define AI model selection and cost strategy
   - Set up MCP exa or implement custom search
   - Create holistic database schema design document
   - Generate and validate initial difficulty rubrics (per subject)
   - Define guardrails (rate limits, quotas, validation rules)

2. **Fix systematic errors:**
   - Global replace: `user_profile` module → `profile` module
   - Verify MCP exa exists or remove all references
   - Add migration conflict detection instructions

3. **Add missing specifications:**
   - Onboarding: define N=10 questions with topics and extraction logic
   - Schedule generation: add algorithm pseudocode with validation
   - Difficulty rubrics: add validation process (20 samples, ≥85% agreement)
   - Grading: specify partial credit rules and structure
   - Head Teacher: add trigger table with conditions/actions/priorities

4. **Address gaps:**
   - Add error handling strategy for AI failures
   - Include test commits alongside implementation
   - Add rollback migrations
   - Define deployment strategy

5. **Answer requirements open questions** in separate ADR document before proceeding.

---


## Open Questions (unscored)

These questions arose during review and should be clarified before revision:

1. **Is the existing `profile` module sufficient?** - Plan assumes it needs enhancement, but current structure already has `SubjectProfiles`, `OverallProfile`, `LifeProfile` JSON fields. Are these adequate or do they need schema changes?

2. **What AI tools already exist?** - Found `QueryQuestionBank`, `QueryMaterials`, `AnalyzeMistakes`, `GetUserInfo` in codebase. Plan proposes creating similar tools. Should plan leverage existing tools or are new ones needed?

3. **Is course schedule already partially implemented?** - Found `course_schedule_tool.go` and `course_schedule_screen.dart` in codebase. Plan treats this as net-new. What's the current state?

4. **What's the current migration strategy?** - Migrations 020-023 exist. Is there a migration runner? Does it support rollback? Plan should document this.

5. **Are there existing prompt templates?** - Found `prompt_templates.go` in AI module. Plan proposes creating prompt library. Should plan extend existing system?

6. **What's the testing coverage baseline?** - Plan targets >80% coverage but doesn't state current coverage. What's the starting point?

7. **Is multi-user support planned?** - Requirements say "explicitly single-user focused" but some plan elements (rate limits, quotas) suggest multi-user. Clarify scope.

8. **What's the deployment model?** - Self-hosted or SaaS? Affects resource management, cost strategy, and guardrails design.

9. **Chinese vs English?** - Requirements mention Chinese prompts and 高考 standards. Plan examples are English. What's the actual language requirement?

10. **What's the timeline expectation?** - 35 commits across 7 sprints suggests 3-4 months. Is this acceptable for MVP? Requirements suggest urgency.

---

## Final Checklist

- ✅ Did I make pre-commitment predictions before diving in?
- ✅ Did I read every file referenced in the plan? (Verified: migrations, modules, AI tools)
- ✅ Did I verify every technical claim against actual source code? (Found multiple false claims)
- ✅ Did I simulate implementation of every task? (Identified multiple blocking gaps)
- ✅ Did I identify what's MISSING, not just what's wrong? (Listed 8 major gaps)
- ✅ Did I review from appropriate perspectives? (Executor, Stakeholder, Skeptic)
- ✅ Does every CRITICAL/MAJOR finding have evidence? (All findings cite specific plan sections or code)
- ✅ Did I run the self-audit? (All findings are HIGH confidence with concrete evidence)
- ✅ Did I run the Realist Check? (All CRITICAL findings cause immediate failure, no downgrades)
- ✅ Did I check whether escalation to ADVERSARIAL mode was warranted? (Yes, escalated after finding 5 CRITICAL issues)
- ✅ Is my verdict clearly stated? (REJECT)
- ✅ Are my severity ratings calibrated correctly? (5 CRITICAL block execution, 5 MAJOR cause rework)
- ✅ Are my fixes specific and actionable? (Each finding includes concrete remediation steps)
- ✅ Did I differentiate certainty levels? (All findings marked HIGH confidence)
- ✅ Did I resist rubber-stamping or manufacturing outrage? (Found real, verifiable issues)

---

## Summary

**REJECTED** due to 5 critical blockers and 5 major specification gaps. Plan demonstrates good architectural thinking but makes unvalidated assumptions about infrastructure, skips prerequisite work identified in requirements, and contains systematic errors that would cause immediate implementation failure.

The plan is recoverable with focused revision addressing the 5-point "What needs to change" list above. Estimated revision effort: 2-3 days to create Phase 0, fix systematic errors, and add missing specifications.

**Recommendation:** Do not proceed to implementation. Revise plan first, then re-submit for review.

---

**End of Review**
