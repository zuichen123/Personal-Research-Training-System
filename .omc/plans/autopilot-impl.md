# PRTS Renaming Implementation Plan (REVISED)

## Phase 1: Go Backend Module Rename

### Task 1.1: Update Go module declaration
- **Files**: `go.mod`
- **Action**: Change `module self-study-tool` → `module prts`
- **Verification**: `go mod tidy` succeeds

### Task 1.2: Batch replace Go import paths
- **Files**: All `*.go` files
- **Action**: Replace `"self-study-tool/` → `"prts/`
- **Command**: `find . -name "*.go" -type f -exec sed -i.bak 's|"self-study-tool/|"prts/|g' {} + && find . -name "*.bak" -delete`
- **Verification**: `go build ./cmd/server` succeeds

### Task 1.3: Clean Go cache
- **Command**: `go clean -cache -modcache`
- **Verification**: Command completes

### Task 1.4: Run Go tests
- **Command**: `go test ./...`
- **Verification**: All tests pass

## Phase 2: Flutter Package Rename (SEQUENTIAL)

### Task 2.1: Update Flutter package name
- **Files**: `apps/flutter_client/pubspec.yaml`
- **Action**: Change `name: flutter_client` → `name: prts_client`, update description
- **Verification**: YAML syntax valid

### Task 2.2: Update Android namespace
- **Files**: `apps/flutter_client/android/app/build.gradle.kts`
- **Action**:
  - Line 9: `namespace = "com.selfstudy.tool.flutter_client"` → `namespace = "com.prts.app"`
  - Line 24: `applicationId = "com.selfstudy.tool.flutter_client"` → `applicationId = "com.prts.app"`
- **Verification**: `cd apps/flutter_client/android && ./gradlew tasks` succeeds

### Task 2.3: Update Android application label
- **Files**: `apps/flutter_client/android/app/src/main/AndroidManifest.xml`
- **Action**: Change `android:label="flutter_client"` → `android:label="PRTS"`
- **Verification**: XML syntax valid

### Task 2.4: Rename Kotlin package directory
- **Action**:
  - Create directory: `apps/flutter_client/android/app/src/main/kotlin/com/prts/app/`
  - Copy `MainActivity.kt` from `com/selfstudy/tool/flutter_client/` to new location
  - Update package declaration in MainActivity.kt: `package com.prts.app`
  - Delete old directory: `apps/flutter_client/android/app/src/main/kotlin/com/selfstudy/`
- **Verification**: `cd apps/flutter_client/android && ./gradlew assembleDebug` succeeds

### Task 2.5: Update iOS configuration
- **Files**: `apps/flutter_client/ios/Runner.xcodeproj/project.pbxproj`, `apps/flutter_client/ios/Runner/Info.plist`
- **Action**: Change bundle identifier from `com.selfstudy.tool.flutterClient` → `com.prts.app`
- **Verification**: File syntax valid

### Task 2.6: Update macOS configuration
- **Files**: `apps/flutter_client/macos/Runner/Configs/AppInfo.xcconfig`
- **Action**:
  - Line 8: `PRODUCT_NAME = flutter_client` → `PRODUCT_NAME = prts_client`
  - Line 11: `PRODUCT_BUNDLE_IDENTIFIER = com.selfstudy.tool.flutterClient` → `PRODUCT_BUNDLE_IDENTIFIER = com.prts.app`
- **Verification**: File syntax valid

### Task 2.7: Update Linux CMake configuration
- **Files**: `apps/flutter_client/linux/CMakeLists.txt`
- **Action**:
  - Line 7: `set(BINARY_NAME "flutter_client")` → `set(BINARY_NAME "prts_client")`
  - Line 10: `set(APPLICATION_ID "com.selfstudy.tool.flutter_client")` → `set(APPLICATION_ID "com.prts.app")`
- **Verification**: File syntax valid

### Task 2.8: Update Windows CMake configuration
- **Files**: `apps/flutter_client/windows/CMakeLists.txt`
- **Action**:
  - Line 3: `project(flutter_client LANGUAGES CXX)` → `project(prts_client LANGUAGES CXX)`
  - Line 7: `set(BINARY_NAME "flutter_client")` → `set(BINARY_NAME "prts_client")`
- **Verification**: File syntax valid

### Task 2.9: Update web configuration
- **Files**: `apps/flutter_client/web/manifest.json`, `apps/flutter_client/web/index.html`
- **Action**: Update name fields to "PRTS" or "Personal Research & Training System"
- **Verification**: JSON/HTML syntax valid

### Task 2.10: Clean and rebuild Flutter
- **Command**: `cd apps/flutter_client && flutter clean && flutter pub get && flutter analyze`
- **Verification**: No errors reported

## Phase 3: Build Scripts Update

### Task 3.1: Update build scripts
- **Files**: `scripts/build-cross.sh`
- **Action**: Change `APP="self-study-tool"` → `APP="prts"`
- **Verification**: Script syntax valid

### Task 3.2: Update PowerShell build script (if exists)
- **Files**: `scripts/build-cross.ps1`
- **Action**: Change `$APP = "self-study-tool"` → `$APP = "prts"`
- **Verification**: Script syntax valid

### Task 3.3: Test backend build
- **Command**: `./scripts/build-cross.sh`
- **Verification**: Binaries created as `prts-*` in `dist/`

## Phase 4: Documentation Update

### Task 4.1: Update main README
- **Files**: `README.md`
- **Action**: Verify "Personal Research & Training System (PRTS)" is used consistently
- **Verification**: Manual review

### Task 4.2: Update Flutter client README
- **Files**: `apps/flutter_client/README.md`
- **Action**: Update project name references to PRTS
- **Verification**: Manual review

### Task 4.3: Update CLAUDE.md
- **Files**: `CLAUDE.md`
- **Action**: Note that Notion database name "Self-Study-Tool" remains unchanged (external dependency)
- **Verification**: Manual review

## Phase 5: Final Verification

### Task 5.1: Full backend build and test
- **Command**: `go build ./cmd/server && go test ./...`
- **Verification**: Build succeeds, all tests pass

### Task 5.2: Full Flutter Windows build
- **Command**: `cd apps/flutter_client && flutter build windows --release`
- **Verification**: Build succeeds without errors

### Task 5.3: Verify all platforms
- **Command**: `cd apps/flutter_client && flutter build apk --debug`
- **Verification**: Android build succeeds

### Task 5.4: Commit changes
- **Command**: `git add -A && git status --short`
- **Verification**: Review changes before commit
- **Commit message**: `refactor: rename project to PRTS (Personal Research & Training System)`

## Execution Order

**Sequential execution (NO parallelization for Flutter):**
1. Phase 1: Tasks 1.1 → 1.2 → 1.3 → 1.4
2. Phase 2: Tasks 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 → 2.7 → 2.8 → 2.9 → 2.10
3. Phase 3: Tasks 3.1 → 3.2 → 3.3
4. Phase 4: Tasks 4.1, 4.2, 4.3 (can be parallel)
5. Phase 5: Tasks 5.1 → 5.2 → 5.3 → 5.4

**Note**: Root directory rename removed - should be done manually outside Git after committing all changes.

## Rollback Strategy

If any phase fails:
- Before commit: `git checkout .` restores all files
- After commit: `git revert HEAD` undoes the commit
- Database remains compatible (no schema changes)
