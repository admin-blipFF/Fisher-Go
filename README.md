# FisherGO

Hong Kong fishing companion game: offline-first AFCD fish encyclopedia, catch logging, GPS fishing spots, Supabase backend, and daily leaderboard.

## Current status

FisherGO is now mobile-first, with Android as the primary product target. Web remains useful for demos, admin flows, fish encyclopedia previews, leaderboard checks, and fast UI validation, but the core game loop should be designed around native mobile capabilities.

Implemented so far:

- Flutter project templates for web, Windows, Android, and iOS.
- Supabase schema migration and RLS policy draft.
- Web-first fish encyclopedia screen.
- Offline-first repository path with local cache and bundled Hong Kong sample fish fallback.
- Catch log, leaderboard, profile, tutorial, announcements, boat vendor service, and game map foundations.

## Non-negotiable product constraints

- Offline-first fish encyclopedia is the first core feature.
- AI recognition must only classify against rows in `fish_species` from the authorized AFCD dataset.
- The app must never allow the AI to invent species names.
- Do not hardcode Supabase secrets in source code.
- Do not add paid APIs such as Google Cloud Vision or Stormglass until explicitly approved.
- Core gameplay decisions should favor native Android/mobile behavior over web convenience.
- Web must not become the limiting surface for GPS, camera, notification, haptics, offline sync, or App Store-quality retention features.

## Development commands

```bash
cd /c/Users/s0829/fishergo
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Build the Android debug APK after Android SDK setup:

```bash
flutter build apk --debug --dart-define=FISHERGO_MAPLIBRE=true
```

Android SDK setup on this Windows machine:

```powershell
choco install -y temurin17 androidstudio
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
flutter doctor --android-licenses
flutter doctor -v
flutter build apk --debug --dart-define=FISHERGO_MAPLIBRE=true
```

Build the web release:

```bash
flutter build web --dart-define=FISHERGO_MAPLIBRE=true
```

Windows can prepare Flutter code, tests, web builds, backend logic, shared mobile architecture, and Android builds once the Android SDK is installed. iOS simulator/device builds require macOS with Xcode or a macOS CI runner.

## Environment

The Flutter client does not package `.env` files. Public Supabase values are
provided at build time through `--dart-define` or the Vercel build environment:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key `
  --dart-define=FISHERGO_PRIVACY_URL=https://your-domain.example/privacy `
  --dart-define=FISHERGO_SUPPORT_EMAIL=support@your-domain.example
```

`FISHERGO_PRIVACY_URL` and `FISHERGO_SUPPORT_EMAIL` are optional public
release values. When omitted, the Profile screen does not show legal/support
links. The Vercel build reads the same names from its environment; the
protected Android release workflow reads them from the
`fishergo-android-release` environment.

Provider credentials such as `VECTOR_ENGINE_API_KEY` belong only in the
Supabase Edge Function environment. Fish recognition calls the authenticated
`recognize-fish` function and never sends a provider key from the client.

When Supabase values are omitted, the encyclopedia falls back to bundled fish
samples and the local cache.

## Supabase setup

Apply migrations manually or through Supabase CLI/MCP:

```bash
supabase db push
supabase db reset
```

If using the Supabase dashboard, run:

1. `supabase/migrations/0001_initial_schema.sql`
2. `supabase/seed.sql`

## Product roadpath

1. Android mobile foundation — analyzer clean, tests green, Android SDK installed, APK build green, Android package ID set, mobile permissions audited.
2. Core game loop — GPS spot discovery, fishing attempt, catch confirmation, collection unlock, coins, XP, daily tasks.
3. Native capture flow — camera/photo picker, location metadata, offline queue, Supabase sync.
4. Pokemon GO-level map layer — biome rules, spawn logic, distance checks, rare events, time/tide/weather hooks when approved.
5. Retention/social — leaderboard, achievements, crews/friends, limited events, notifications.
6. AI recognition — authorized species list only, user confirmation required, no invented fish names.
7. Admin and moderation — web/admin tools for announcements, events, catch review, analytics.

## Remaining environment notes

- Chrome web development and Android API 35 emulator verification work on this machine.
- Android smoke tests intentionally reject the connected Android 6/API 23 photo-frame device.
- iOS builds require macOS + Xcode and are deferred.
- Codex CLI may need `codex login --device-auth` if it reports `refresh_token_reused` or `token_expired`.
