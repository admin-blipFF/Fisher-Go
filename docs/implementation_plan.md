# FisherGO MVP Implementation Plan

Goal: Build a simple, working Hong Kong fishing app MVP with an offline-first fish encyclopedia and Supabase backend.

Architecture: Flutter feature folders, repository pattern for remote/local data, Supabase as source of truth, Hive as offline cache.

## Phase 1 — App shell

- Initialize Flutter app.
- Add dependencies.
- Configure Supabase from `.env`.
- Create app shell with bottom navigation.

Verification:
- `flutter analyze`
- `flutter test`
- app launches on emulator/device

## Phase 2 — Supabase schema

- Create `profiles`, `fish_species`, `catches`, `daily_leaderboard`.
- Enable RLS.
- Add read/write policies.
- Seed 5 fish species.

Verification:
- migration applies cleanly
- authenticated user can read `fish_species`
- user can only create/read own `catches`

## Phase 3 — Offline-first encyclopedia

- Implement local cache service.
- Fetch remote species on startup.
- Persist species locally.
- Render grid from local cache when offline.

Verification:
- first launch loads Supabase data
- second launch works with network disabled

## Phase 4 — Catch logging

- Manual species selection.
- Photo picker.
- Optional coordinates.
- Offline pending queue.
- Sync when online.

## Phase 5 — Leaderboard

- Today ranking.
- Realtime subscription.
- Scores from catches: 1 point per catch + 1 for new species.

## Phase 6 — AI recognition

- Edge Function accepts image URL.
- Classification restricted to `fish_species` rows.
- User confirmation required.
