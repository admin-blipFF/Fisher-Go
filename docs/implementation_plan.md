# FisherGO MVP Implementation Plan

Goal: Build a simple, working Hong Kong fishing app MVP with an offline-first fish encyclopedia and Supabase backend.

Current priority: Web-first development. Chrome is the primary runtime for design, testing, and demos. Android/iOS remain supported by the Flutter project but are deferred until the web MVP is stable and Android SDK is installed.

Architecture: Flutter feature folders, repository pattern for remote/local/sample data, Supabase as source of truth when configured, Hive as offline cache, bundled sample species as a no-credential web fallback.

## Phase 1 — Web app shell

- Initialize Flutter app.
- Add dependencies.
- Configure `.env` without hardcoding secrets.
- Create app shell with bottom navigation.
- Verify in Chrome first.

Verification:
- `flutter analyze`
- `flutter test`
- `flutter run -d chrome`

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

- Manual species selection first.
- Browser file upload for photo.
- Optional location with browser permission.
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

## Deferred mobile work

- Android SDK setup.
- Android APK build.
- iOS build validation on macOS.
