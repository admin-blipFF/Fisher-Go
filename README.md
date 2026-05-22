# FisherGO

Hong Kong fishing companion MVP: offline-first AFCD fish encyclopedia, catch logging, Supabase backend, and daily leaderboard.

## Current status

FisherGO is now web-first. Chrome is the primary development and preview target. Android/iOS builds are later phases after the web MVP is stable and Android SDK is installed.

Implemented so far:

- Flutter project templates for web, Windows, Android, and iOS.
- Supabase schema migration and RLS policy draft.
- Web-first fish encyclopedia screen.
- Offline-first repository path with local cache and bundled Hong Kong sample fish fallback.
- Placeholder screens for catch log, leaderboard, and profile.

## Non-negotiable product constraints

- Offline-first fish encyclopedia is the first core feature.
- AI recognition must only classify against rows in `fish_species` from the authorized AFCD dataset.
- The app must never allow the AI to invent species names.
- Do not hardcode Supabase secrets in source code.
- Do not add paid APIs such as Google Cloud Vision or Stormglass until explicitly approved.

## Web-first development commands

```bash
cd /c/Users/s0829/fishergo
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Build the web release:

```bash
flutter build web
```

## Environment

A local `.env` is needed because Flutter declares it as an asset. Use placeholder values for local web MVP work:

```bash
cp .env.example .env
```

When Supabase is ready, replace the placeholders:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

If these remain placeholders, the encyclopedia automatically uses the bundled fish samples and local cache.

## Supabase setup

Apply migrations manually or through Supabase CLI/MCP:

```bash
supabase db push
supabase db reset
```

If using the Supabase dashboard, run:

1. `supabase/migrations/0001_initial_schema.sql`
2. `supabase/seed.sql`

## MVP phases

1. Project setup and app shell — done
2. Supabase schema + RLS — drafted
3. Web-first offline fish encyclopedia — in progress
4. Manual catch logging with offline queue
5. Daily leaderboard
6. AI recognition after MVP stability
7. HK Spot Analyst placeholder only

## Remaining environment notes

- Chrome web development works on this machine.
- Android SDK is not installed yet, so Android APK builds are deferred.
- Codex CLI may need `codex login --device-auth` if it reports `refresh_token_reused` or `token_expired`.
