# Phase 0 Detailed Specifications

## 0.1 State Verification Script

**File:** `scripts/verify_state.sh`

**Purpose:** Verify current codebase state before implementation

**Script Content:**
```bash
#!/bin/bash

echo "=== Self-Study-Tool State Verification ==="
echo ""

# Check latest migration
echo "1. Latest Migration:"
LATEST_MIGRATION=$(ls migrations/sqlite/*.sql | sort -V | tail -1)
echo "   $LATEST_MIGRATION"
MIGRATION_NUM=$(basename "$LATEST_MIGRATION" | cut -d'_' -f1)
echo "   Next migration should be: $(printf "%03d" $((10#$MIGRATION_NUM + 1)))"
echo ""

# Check module names
echo "2. Module Structure:"
ls -1 internal/modules/
echo ""

# Check table names
echo "3. Database Tables:"
sqlite3 data/app.db ".tables" 2>/dev/null || echo "   Database not found or empty"
echo ""

# Check profile table schema
echo "4. Profile Table Schema:"
sqlite3 data/app.db ".schema user_profiles" 2>/dev/null || \
sqlite3 data/app.db ".schema profiles" 2>/dev/null || \
echo "   Profile table not found"
echo ""

# Check AI module
echo "5. AI Module Status:"
if [ -f "internal/modules/ai/service.go" ]; then
    echo "   ✓ AI service exists"
    grep -q "Client interface" internal/modules/ai/service.go && echo "   ✓ Client interface found"
else
    echo "   ✗ AI service not found"
fi
echo ""

# Check MCP configuration
echo "6. MCP Configuration:"
if [ -f ".kiro/settings/mcp.json" ] || [ -f ".claude/settings/mcp.json" ]; then
    echo "   ✓ MCP config exists"
else
    echo "   ✗ No MCP config (expected - will use custom web search)"
fi
echo ""

echo "=== Verification Complete ==="
```

**Output:** Report showing current state for planning adjustments

---

## 0.2 Web Search Client Specification

**File:** `internal/pkg/websearch/client.go`

**Implementation Details:**

### API Choice: DuckDuckGo HTML
- **URL:** `https://html.duckduckgo.com/html/?q={query}`
- **Method:** GET with User-Agent header
- **Rate Limiting:** 1 request per 2 seconds (client-side delay)
- **Timeout:** 5 seconds per request
- **No API Key Required**

### HTML Parsing Strategy:
```
1. Fetch HTML page
2. Parse with golang.org/x/net/html
3. Extract result divs with class "result"
4. For each result:
   - Title: .result__a text
   - URL: .result__a href (decode from DDG redirect)
   - Snippet: .result__snippet text
5. Return max 10 results
```

### Error Handling:
- Network timeout → return empty results
- Parse error → return empty results
- Rate limit hit → wait and retry once
- All errors logged but not exposed to user

### Code Structure:
```go
type Result struct {
    Title   string
    URL     string
    Snippet string
}

type Client struct {
    httpClient *http.Client
    lastRequest time.Time
    mu sync.Mutex
}

func NewClient() *Client
func (c *Client) Search(query string) ([]Result, error)
func (c *Client) parseHTML(body io.Reader) ([]Result, error)
```

**Test:** Real search for "golang tutorial" should return 5+ results

---

## 0.3 Prompt Templates Table

**Migration:** `024_create_prompt_templates.sql`

**Schema:**
```sql
CREATE TABLE prompt_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL,
    system_role TEXT NOT NULL,
    task_description TEXT NOT NULL,
    output_format TEXT NOT NULL,
    examples TEXT,
    variables TEXT,
    version INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prompt_templates_category ON prompt_templates(category);
CREATE INDEX idx_prompt_templates_name ON prompt_templates(name);
```

---

## 0.4 Seed Prompt Templates

**Migration:** `025_seed_prompt_templates.sql`

**Source:** Use content from `.omc/plans/prompt-templates.md`

**SQL Structure:**
```sql
INSERT INTO prompt_templates (name, category, system_role, task_description, output_format, variables)
VALUES
('onboarding_assistant', 'onboarding',
 'You are a friendly educational assistant...',
 'Conduct a 10-question onboarding interview...',
 '{"question": "string", "step": "integer", "is_final": "boolean"}',
 'user_name,current_step'),

('schedule_generator', 'scheduling',
 'You are an expert educational planner...',
 'Generate a weekly study schedule...',
 '{"schedule": [...]}',
 'user_profile,availability,subjects,goals,level'),

-- ... (6 more prompts from prompt-templates.md)
```

**Validation:** After migration, `SELECT COUNT(*) FROM prompt_templates` should return 8

---

## Module Naming Clarification

**Correct Names:**
- **Module directory:** `internal/modules/profile` (verified in codebase)
- **Table name:** `user_profiles` (plural, standard convention)
- **Go package:** `package profile`
- **Service struct:** `profile.Service`

**All references in plan must use:**
- Module: `profile` (not `user_profile`)
- Table: `user_profiles` (plural)
- Import: `"self-study-tool/internal/modules/profile"`
