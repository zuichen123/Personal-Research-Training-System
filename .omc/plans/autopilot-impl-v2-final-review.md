# Final Review: Implementation Plan v2

**Date:** 2026-03-11
**Reviewer:** Critic Agent
**Status:** REJECTED

---

## Executive Summary

The implementation plan has improved significantly from v1 and addresses most previous blockers:
- ✅ Module naming is now consistent (`profile` module, `user_profiles` table)
- ✅ Specification documents exist and are comprehensive
- ✅ Phase 0.4 correctly references prompt content from `prompt-templates.md`
- ✅ Prompt templates are professional and detailed

However, **3 CRITICAL blockers** prevent execution:

1. **Missing architecture decisions document** - Referenced but not provided
2. **Web search implementation violates ToS** - DuckDuckGo scraping is illegal and fragile
3. **AI service integration undefined** - No concrete implementation strategy

---

## Critical Findings (BLOCKS EXECUTION)

### 1. Missing Architecture Decisions Document ⛔
**Location:** Plan header line 8
**Evidence:** References `.omc/plans/architecture-decisions.md` but file not found

**Impact:** Executors lack critical context for:
- AI provider selection rationale
- Database schema design decisions
- Error handling strategies
- Migration rollback procedures
- Security considerations

**Required Fix:**
Create `architecture-decisions.md` with these sections:
- AI Provider Selection (which service, why)
- Database Design Rationale
- Error Handling Strategy
- Migration Strategy
- Security Considerations
- Cost Management

---

### 2. Web Search Implementation Violates Terms of Service ⛔
**Location:** `phase0-specifications.md` lines 74-95
**Evidence:**
```
URL: https://html.duckduckgo.com/html/?q={query}
Method: GET with User-Agent header
HTML Parsing Strategy: Extract result divs with class "result"
```

**Why This Is Critical:**
- DuckDuckGo explicitly prohibits automated scraping
- HTML structure changes frequently → parser breaks
- No official rate limiting → risk of IP blocking
- Will fail in production within weeks

**Required Fix:**
Replace with legal API. Recommended options:
1. **Brave Search API** (free tier: 2000 queries/month) ✅ RECOMMENDED
2. SerpAPI (paid, stable)
3. Bing Web Search API (free tier available)

Update Phase 0.2 specification with:
- API endpoint and authentication
- Rate limiting strategy
- Error handling for quota exceeded
- Fallback behavior when service unavailable

---

### 3. AI Service Integration Strategy Undefined ⛔
**Location:** Throughout plan (Phases 0.4, 1.3, 2.2, 3.3, 5.3, 7.2, 8.2)
**Evidence:** Plan references AI calls extensively but never specifies:
- Which AI provider/model (OpenAI? Claude? Local?)
- API key management
- How to load and execute prompts from `prompt_templates` table
- Error handling when AI unavailable
- Cost management (token limits, rate limiting)

**Impact:** Every phase depends on AI. Without concrete integration:
- Executors will implement inconsistent solutions
- Error handling will be fragmented
- Costs will be unpredictable
- Production failures will cascade

**Required Fix:**
Add to `architecture-decisions.md`:

```markdown
## AI Service Integration

**Provider:** [Specify: OpenAI GPT-4 / Anthropic Claude / Other]

**Configuration:**
- Environment variables: `AI_API_KEY`, `AI_MODEL`, `AI_BASE_URL`
- Timeout: 30 seconds
- Max retries: 3 with exponential backoff

**Prompt Execution Flow:**
1. Load template from `prompt_templates` table by name
2. Substitute variables using Go text/template
3. Construct request: system_role + task_description + user_input
4. Call AI service API
5. Parse JSON response according to output_format schema
6. Validate response structure
7. Return result or error

**Error Handling:**
- Network timeout → return user-friendly error
- Rate limit → exponential backoff, max 3 retries
- Invalid JSON → log error, return generic failure
- Service unavailable → degrade gracefully (skip AI features)

**Cost Management:**
- Token limit per request: 4000 input, 2000 output
- Daily user limit: 100 AI calls
- Log all AI calls for audit and cost tracking
```

---

## Major Findings (CAUSES SIGNIFICANT REWORK)

### 4. Phase 0.1 Verification Script Has Incorrect Database Path
**Location:** `phase0-specifications.md:36`
**Evidence:** `sqlite3 data/app.db ".tables"`

**Issue:** Database path `data/app.db` is assumed but not verified. Script will fail if path is different.

**Fix:** Add to Phase 0.1 task:
"First, locate database file using `find . -name '*.db' -type f` and update script with correct path."

---

### 5. Migration Numbering Ambiguity
**Location:** Plan Phase 0.3
**Evidence:** Starts with migration `024_` but doesn't verify current state

**Issue:** If current migration is not 023, all subsequent numbers are wrong.

**Fix:** Phase 0.1 acceptance criteria must output:
"Current migration: XXX, next migration should be: YYY"
If not 023, adjust all migration numbers before proceeding.

---

### 6. Onboarding Questions Are Chinese-Only
**Location:** `detailed-specifications.md:6-15`

**Issue:** All questions hardcoded in Chinese. No i18n strategy mentioned.

**Fix:** Either:
1. Document that v1 is Chinese-only (add to plan header)
2. Add i18n requirement to Phase 1.3 with translation table

---

### 7. Schedule Generation Lacks Conflict Detection
**Location:** Phase 2.2 `GenerateSchedule` function

**Issue:** No mention of checking existing schedules or preventing overlaps.

**Fix:** Add to Phase 2.2:
"Before generating, check if active schedule exists. If yes, prompt user: 'Replace existing schedule or create new?' Handle user choice appropriately."

---

## Minor Findings

8. No rollback strategy for migrations (down migrations not mentioned)
9. Test coverage requirements not specified
10. Flutter state management approach not specified (Provider? Riverpod? Bloc?)

---

## What's Missing (Gap Analysis)

**Authentication/Authorization:**
Plan assumes `user_id` exists but never explains login flow or session management.

**Data Migration for Existing Users:**
If database has existing users, how do they get onboarded? Is `onboarding_completed` nullable?

**Offline Support:**
Flutter app - what happens when backend unreachable? No offline mode specified.

**Performance Benchmarks:**
Acceptance criteria mention time limits but no load testing or optimization strategy.

**Monitoring/Observability:**
No logging, metrics, or error tracking. How will production issues be diagnosed?

**Deployment Strategy:**
38 commits - incremental deployment or all at once? No staging environment mentioned.

---

## Multi-Perspective Analysis

**Executor Perspective:**
- "Phase 0.2: Plan tells me to scrape DuckDuckGo but that's illegal. What should I actually use?"
- "Phase 1.3: How do I call the AI service? What library? What endpoint?"
- "Phase 2.2: Schedule generation calls AI - what if it returns invalid JSON?"

**Stakeholder Perspective:**
- "Why build web search from scratch instead of using existing tools?"
- "What's the total AI cost per user per month?"
- "Can we launch Phase 1-2 without Phase 3-8?"

**Skeptic Perspective:**
- "DuckDuckGo scraping will break within weeks. Technical debt from day 1."
- "38 commits is too many for one cycle. Should be 2-3 milestones."
- "No error handling strategy means first production bug cascades across all AI features."

---

## Verdict Justification

Review escalated to **ADVERSARIAL mode** after discovering web search ToS violation (Critical #2). This triggered deeper investigation revealing AI integration gap (#3) and missing architecture document (#1).

The plan is well-structured with comprehensive specifications, but three critical blockers prevent execution. These are not stylistic issues - they are missing implementation details that would cause immediate execution failure.

---

## Required Actions for ACCEPT

**Must Fix (CRITICAL):**
1. ✅ Create `architecture-decisions.md` with AI integration details
2. ✅ Replace DuckDuckGo scraping with legal API (recommend Brave Search)
3. ✅ Specify AI service configuration, error handling, and cost management

**Should Fix (MAJOR):**
4. ✅ Verify database path in Phase 0.1
5. ✅ Add migration numbering verification to Phase 0.1
6. ✅ Add schedule conflict detection to Phase 2.2

**Nice to Fix (MINOR):**
7. Document language support (Chinese-only or i18n)
8. Add rollback strategy for migrations
9. Specify test coverage requirements

---

## Conclusion

**Status:** REJECTED - Not ready for execution

**Reason:** Three critical implementation details are missing or incorrect. These must be resolved before any executor can begin work.

**Next Steps:**
1. Create architecture decisions document
2. Fix web search implementation (use legal API)
3. Define AI service integration strategy
4. Re-submit for review

**Estimated Time to Fix:** 2-4 hours

---

**Review completed:** 2026-03-11
**Reviewer:** oh-my-claudecode:critic (Opus 4.6)
