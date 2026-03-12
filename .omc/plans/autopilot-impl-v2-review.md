# Implementation Plan v2 Review - Self-Study-Tool Enhancement

**Reviewer:** oh-my-claudecode:critic
**Date:** 2026-03-11
**Review Mode:** THOROUGH

---

## VERDICT: REJECT

---

## Overall Assessment

The revised plan (v2) addresses 3 of 5 critical blockers but introduces new critical issues and fails to adequately resolve specification gaps. While Phase 0 prerequisites are a significant improvement, the plan still contains false claims, incomplete specifications, and systematic errors that would block execution.

---

## Pre-commitment Predictions vs Actual Findings

**Predicted Issues:**
1. Requirements open questions partially answered but not all 10
2. Web search implementation may lack error handling
3. Module naming might still have inconsistencies
4. Migration verification script may be incomplete
5. Prompt templates may lack concrete content

**Actual Findings:**
- ✅ Prediction #1 CONFIRMED: Only 6 of 10 questions answered in architecture-decisions.md
- ✅ Prediction #2 CONFIRMED: Web search has basic timeout but no retry/fallback detail
- ✅ Prediction #3 CONFIRMED: Plan still uses `user_profile` in multiple places
- ✅ Prediction #4 CONFIRMED: Verification script has no acceptance criteria detail
- ✅ Prediction #5 CONFIRMED: Prompt seeding says "8 core prompts" but no actual content

---

## Critical Findings (blocks execution)

### 1. Requirements Open Questions Still Incomplete
**Evidence:** Architecture-decisions.md answers 6 of 10 questions. Missing answers:
- Question 7: "Prompt Engineering Approach" - Says "structured JSON prompts" but doesn't specify WHO writes initial prompts or WHAT quality bar they must meet
- Question 8: "Module Naming" - Says "verify table name is `user_profiles`" but doesn't actually verify it
- Question 9: "Migration Strategy" - Says "check for conflicts" but doesn't specify the CHECK PROCESS
- Question 10: "Head Teacher Initialization" - Says "created on first onboarding completion" but requirements ask "when does it initialize?" (before/during/after onboarding?)

**Why this matters:** These are still foundational decisions. "Verify table name" is not an answer - the answer IS the table name.

**Fix:** Complete all 10 answers with concrete values, not instructions to verify later.

**Confidence:** HIGH

---

### 2. False Claim: "Seed Professional Prompts" Without Content
**Evidence:** Phase 0.4 says `"Insert 8 core prompts: onboarding, schedule_gen, math_grading, english_grading, science_grading, difficulty_rubric, homework_gen, orchestration"` but provides ZERO actual prompt content.

**Verification:** No prompt text in plan. Migration file `025_seed_prompt_templates.sql` doesn't exist yet, so content is undefined.

**Why this matters:** Phase 1+ depend on these prompts. Without actual content, implementation cannot proceed. "Professional-grade" prompts require expert design, not placeholder names.

**Fix:** Include actual prompt content in plan appendix OR defer prompt creation to each phase where they're used. Cannot claim "seed prompts" without the prompts.

**Confidence:** HIGH

---

### 3. Module Naming Still Inconsistent
**Evidence:** Plan v2 still contains `user_profile` references:
- Phase 1.1: `"FOREIGN KEY (user_id) REFERENCES user_profiles(id)"` - uses `user_profiles` (plural)
- Phase 0.1: Says "verify module names" but doesn't state the CORRECT name
- Architecture-decisions.md: Says "Use `profile` (not `user_profile`)" but then says "Verify actual table name is `user_profiles`"

**Why this matters:** Inconsistency between module name (`profile`) and table name (`user_profiles`) is normal, but plan doesn't clarify this. Executor will be confused.

**Fix:** Add explicit statement: "Module path is `internal/modules/profile`, table name is `user_profiles` (plural)." Update all references to be consistent.

**Confidence:** HIGH

---

### 4. Phase 0.1 Verification Script Has No Specification
**Evidence:** Phase 0.1 says `"Check migration number, verify module names, confirm table schema"` with acceptance `"Script outputs current state report"` but provides:
- No script content
- No specification of WHAT to check
- No format for "state report"
- No error handling if checks fail

**Why this matters:** This is the foundation for all subsequent phases. Without concrete specification, executor cannot write the script.

**Fix:** Specify script requirements:
```bash
# Must check:
# 1. Latest migration number (ls migrations/sqlite/ | sort | tail -1)
# 2. Module exists (test -d internal/modules/profile)
# 3. Table schema (sqlite3 query: .schema user_profiles)
# Output format: JSON with {latest_migration, modules_found, tables_found}
```

**Confidence:** HIGH

---

### 5. Web Search Implementation Lacks Critical Details
**Evidence:** Phase 0.2 says `"HTTP client for DuckDuckGo HTML search, parse results to JSON"` but doesn't specify:
- DuckDuckGo HTML endpoint URL
- HTML parsing strategy (which CSS selectors?)
- Result structure (title, url, snippet?)
- Error handling beyond "5s timeout"
- Rate limiting (DuckDuckGo blocks aggressive scrapers)

**Why this matters:** DuckDuckGo HTML scraping is fragile and may violate ToS. Without concrete implementation details, this will fail or require multiple revision cycles.

**Fix:** Either (1) specify exact implementation with URL, selectors, and anti-blocking strategy, OR (2) use a proper search API (SerpAPI, Brave Search API) with API key.

**Confidence:** HIGH

---

## Major Findings (causes significant rework)

### 6. Onboarding Flow Still Lacks Concrete Questions
**Evidence:** Phase 1.3 says `"GetNextQuestion(userID, step) (Question, error)"` but doesn't define:
- How many steps (N=?)
- What each question asks
- How to extract structured data from conversational responses

**Previous review flagged this.** Plan v2 doesn't address it.

**Why this matters:** Core UX feature. Cannot implement without knowing the actual questions.

**Fix:** Add appendix with 10 specific questions and extraction logic for each.

**Confidence:** HIGH

---

### 7. Schedule Generation Algorithm Still Undefined
**Evidence:** Phase 2.2 says `"AI generates personalized schedule"` but provides no algorithm, constraints, or validation logic.

**Previous review flagged this.** Plan v2 doesn't address it.

**Why this matters:** Schedule quality is a key success metric. Vague "AI generates" is not a specification.

**Fix:** Add algorithmic pseudocode or at minimum specify constraints (max hours/day, dependency ordering, availability matching).

**Confidence:** HIGH

---

### 8. Difficulty Rubric Generation Has No Validation
**Evidence:** Phase 3.2 creates `difficulty_rubrics` table but no validation process.

**Previous review flagged this.** Plan v2 doesn't address it.

**Why this matters:** Unvalidated rubrics = inaccurate difficulty ratings.

**Fix:** Add validation step in Phase 3.3 with sample questions and agreement threshold.

**Confidence:** HIGH

---

### 9. Grading System Still Missing Partial Credit
**Evidence:** Phase 5.3 says `"GradeAnswer(questionID, answer) (GradingResult, error)"` but requirements Section 5.5 requires partial credit for multi-step problems. No specification of how partial credit is calculated.

**Previous review flagged this.** Plan v2 doesn't address it.

**Fix:** Add partial credit rules to GradingResult structure and prompt templates.

**Confidence:** HIGH

---

### 10. Head Teacher Orchestration Lacks Triggers
**Evidence:** Phase 8.2 says `"MonitorProgress(userID) error - periodic check"` and Phase 8.3 says `"runs orchestration every 1 hour"` but doesn't specify:
- What thresholds trigger interventions
- What actions are taken
- How interventions are prioritized

**Previous review flagged this.** Plan v2 doesn't address it.

**Fix:** Add trigger specification table with conditions, actions, and priorities.

**Confidence:** HIGH

---

## What's Missing

- **Actual prompt content** for 8 templates (Phase 0.4 claims to seed them but provides no content)
- **Onboarding questions** (10 specific questions with extraction logic)
- **Schedule algorithm** (constraints, validation, feasibility checking)
- **Difficulty validation** (process for testing rubrics against real questions)
- **Partial credit rules** (how to calculate for multi-step problems)
- **Orchestration triggers** (when/why/how Head Teacher intervenes)
- **Error handling strategy** across all AI interactions
- **Rollback migrations** for all 12 new migration files
- **Test specifications** (what to test in each phase)

---

## Multi-Perspective Notes

### Executor Perspective
- **Blocked on:** Prompt content, onboarding questions, schedule algorithm, verification script spec
- **Ambiguous:** Web search implementation, module vs table naming, migration conflict resolution
- **Cannot proceed:** Phase 0.4 cannot be implemented without actual prompt text

### Stakeholder Perspective
- **Concern:** Plan claims to address all blockers but actually defers critical decisions ("verify later", "check before each phase")
- **Risk:** 38 commits is even larger than v1 (35). Scope keeps growing.

### Skeptic Perspective
- **Red flag:** "Seed professional prompts" without providing the prompts is a placeholder, not a plan
- **Red flag:** Web search via DuckDuckGo HTML scraping will likely fail or get blocked
- **Red flag:** Multiple "verify" and "check" instructions that should have been done BEFORE planning

---

## Verdict Justification

**Why REJECT:**

Plan v2 addresses 3 of 5 original blockers:
1. ✅ Added Phase 0 prerequisites
2. ✅ Removed MCP exa false claim (replaced with custom search)
3. ❌ Module naming still inconsistent
4. ✅ Migration strategy defined (but incomplete)
5. ❌ Missing specifications NOT added (5 major gaps remain)

**New critical issues introduced:**
- Phase 0.4 claims to seed prompts without providing prompt content
- Phase 0.1 verification script has no specification
- Web search implementation lacks critical details
- Architecture decisions incomplete (4 of 10 questions unanswered)

**Review Mode:** THOROUGH (did not escalate to ADVERSARIAL - issues are specification gaps, not systematic failures)

**What needs to change for ACCEPT:**

1. **Complete all 10 architecture decisions** with concrete answers (not "verify later")
2. **Provide actual prompt content** for Phase 0.4 or defer prompt creation to usage phases
3. **Specify verification script** requirements in Phase 0.1
4. **Fix web search** - either specify exact implementation or use proper API
5. **Clarify module naming** - state explicitly: module=`profile`, table=`user_profiles`
6. **Add missing specifications** from previous review:
   - 10 onboarding questions with extraction logic
   - Schedule generation algorithm with constraints
   - Difficulty rubric validation process
   - Partial credit calculation rules
   - Orchestration trigger table

---

## Open Questions

1. **Why defer critical decisions?** Architecture-decisions.md says "verify table name" instead of stating it. This should have been verified BEFORE planning.
2. **Where are the prompts?** Phase 0.4 cannot be implemented without actual prompt text. Are they being written separately?
3. **Is DuckDuckGo scraping legal?** Their ToS may prohibit automated scraping. Has this been checked?
4. **What's the actual table name?** Plan uses both `user_profile` and `user_profiles`. Which is correct?

---

## Final Checklist

- ✅ Pre-commitment predictions made
- ✅ All referenced files read
- ✅ Technical claims verified against codebase
- ✅ Implementation simulation conducted
- ✅ Gap analysis performed
- ✅ Multi-perspective review conducted
- ✅ Evidence provided for all CRITICAL/MAJOR findings
- ✅ Self-audit completed
- ✅ Realist check completed
- ✅ Verdict clearly stated
- ✅ Fixes are specific and actionable

---

**End of Review**
