#!/bin/bash

echo "=== Self-Study-Tool State Verification ==="
echo ""

# Check latest migration
echo "1. Latest Migration:"
LATEST_MIGRATION=$(ls migrations/sqlite/*.sql 2>/dev/null | sort -V | tail -1)
if [ -n "$LATEST_MIGRATION" ]; then
    echo "   $LATEST_MIGRATION"
    MIGRATION_NUM=$(basename "$LATEST_MIGRATION" | cut -d'_' -f1)
    NEXT_NUM=$(printf "%03d" $((10#$MIGRATION_NUM + 1)))
    echo "   Next migration should be: $NEXT_NUM"
else
    echo "   No migrations found"
fi
echo ""

# Check module names
echo "2. Module Structure:"
ls -1 internal/modules/ 2>/dev/null || echo "   Modules directory not found"
echo ""

# Check database tables
echo "3. Database Tables:"
if [ -f "data/app.db" ]; then
    sqlite3 data/app.db ".tables" 2>/dev/null
else
    echo "   Database not found at data/app.db"
fi
echo ""

# Check profile table schema
echo "4. Profile Table Schema:"
if [ -f "data/app.db" ]; then
    sqlite3 data/app.db ".schema user_profiles" 2>/dev/null || \
    sqlite3 data/app.db ".schema profiles" 2>/dev/null || \
    echo "   Profile table not found"
else
    echo "   Database not found"
fi
echo ""

# Check AI module
echo "5. AI Module Status:"
if [ -f "internal/modules/ai/service.go" ]; then
    echo "   ✓ AI service exists"
    grep -q "Client interface" internal/modules/ai/service.go && echo "   ✓ Client interface found" || echo "   ✗ Client interface not found"
else
    echo "   ✗ AI service not found"
fi
echo ""

echo "=== Verification Complete ==="
