# Player Progress Daily Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Phase 2 FisherGO progress spine: XP, level, daily streak, and daily fishing tasks for successful Android minigame catches.

**Architecture:** Add a focused Hive-backed `PlayerProgressService` under the profile feature. The service owns pure reward math and persistent progress state; the fishing overlay calls it only after a successful catch reveal so failed attempts do not advance progress.

**Tech Stack:** Flutter, Dart, Hive, `flutter_test`.

---

### Task 1: Progress Service Model And Reward Rules

**Files:**
- Create: `lib/features/profile/data/player_progress_service.dart`
- Create: `test/player_progress_service_test.dart`

- [ ] **Step 1: Write failing tests**

Create tests that verify a first successful catch grants XP, coins, level progress, daily task credit, and streak state; a second catch of the same fish on the same day grants repeat rewards without resetting the streak.

- [ ] **Step 2: Run red test**

Run: `flutter test test/player_progress_service_test.dart`
Expected: fail because `PlayerProgressService` does not exist.

- [ ] **Step 3: Implement minimal service**

Create immutable result/state models plus `recordGameCatch`, `loadState`, and `resetForTest`.

- [ ] **Step 4: Run green test**

Run: `flutter test test/player_progress_service_test.dart`
Expected: pass.

### Task 2: Hook Successful Minigame Catches

**Files:**
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`

- [ ] **Step 1: Write or extend test coverage if behavior can be isolated**

The progress service is already unit-tested; the widget overlay is private and animation-driven, so integration is verified through analyzer/build/emulator smoke.

- [ ] **Step 2: Add progress import and call**

After `FishCollectionService.markGameCaught(fish.fishId)`, call `PlayerProgressService.recordGameCatch` with fish ID, reward, rarity, and whether it is a first catch.

- [ ] **Step 3: Surface reward feedback**

Show a short snackbar including XP, coins, level, and daily task progress after the catch result is revealed.

### Task 3: Verification

**Files:**
- Test: `test/player_progress_service_test.dart`
- Verify app: Android debug APK and emulator smoke

- [ ] Run: `flutter analyze`
- [ ] Run: `flutter test`
- [ ] Run: `flutter build apk --debug`
- [ ] Install/launch on `FisherGO_API35` emulator and scan logcat for fatal, permission, and map warning signatures.
