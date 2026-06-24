# FisherGO MVP Implementation Plan

Goal: Build a Hong Kong fishing mobile game with an offline-first fish encyclopedia, GPS fishing loop, catch logging, Supabase backend, and daily leaderboard.

Current priority: Android-first mobile product development. Chrome web remains a fast preview/demo/admin target, but native mobile behavior is the product source of truth for GPS, camera, offline sync, notifications, haptics, and app lifecycle.

Architecture: Flutter feature folders, repository pattern for remote/local/sample data, Supabase as source of truth when configured, Hive as offline cache, bundled sample species as a no-credential web fallback.

## Phase 1 — Mobile foundation

- Keep Flutter analyzer clean.
- Keep full test suite green.
- Keep web build usable for preview/admin, but do not design gameplay around web limitations.
- Install and configure Android SDK.
- Audit Android permission needs: location, camera/photo library, notifications, and app lifecycle.
- Prepare shared code so Android APK builds without source restructuring.
- Use Android application ID `com.fishergo.app`.

Verification:
- `flutter analyze`
- `flutter test`
- `flutter doctor -v`
- `flutter build apk --debug`
- `flutter build web`

## Phase 2 — Supabase schema

- Create `profiles`, `fish_species`, `catches`, `daily_leaderboard`.
- Enable RLS.
- Add read/write policies.
- Seed 5 fish species.

Verification:
- migration applies cleanly
- authenticated user can read `fish_species`
- user can only create/read own `catches`

## Phase 3 — Web-first offline encyclopedia

Status: keep as cross-platform encyclopedia foundation, but no longer the product driver.

- Render responsive fish grid in Chrome.
- Use repository order: Supabase remote when configured → Hive cache → bundled Hong Kong sample fish.
- Persist remote results locally when available.
- Keep the app useful with placeholder `.env` values.
- Show Pokemon-style locked/unlocked state.
- Show danger badges and basic habitat/scientific-name details for unlocked fish.

Verification:
- `flutter analyze`
- `flutter test`
- `flutter build web`
- Chrome shows fish cards even without Supabase credentials

## Phase 4 — Web catch logging

Reframe as native mobile catch logging, with web as a fallback/demo surface.

- Manual species selection first.
- Native camera/photo flow on mobile.
- GPS location with permission handling.
- Local pending queue.
- Sync to Supabase only when credentials are configured.

## Phase 5 — Web leaderboard

- Today ranking.
- Realtime subscription if Supabase configured.
- Scores from catches: 1 point per catch + 1 for new species.
- Local demo leaderboard when offline/no credentials.

## Phase 6 — AI recognition

- Edge Function accepts image URL.
- Classification restricted to `fish_species` rows.
- User confirmation required.
- No paid API until approved.

## Mobile-first game loop

- GPS spot discovery and distance checks.
- Fishing attempt minigame.
- Catch confirmation with photo/location/time metadata.
- Fish collection unlock state.
- Coins, XP, streaks, daily tasks, and event boosts.
- Push notification hooks when app credentials are ready.

## Deferred platform work

- iOS build validation on macOS.
