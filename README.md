# FisherGO

Hong Kong fishing companion MVP: offline-first AFCD fish encyclopedia, catch logging, Supabase backend, and daily leaderboard.

## Current status

This repository is a Phase 1/2 scaffold because Flutter CLI is not installed on this machine yet.
Codex CLI was attempted, but its ChatGPT auth token is expired and must be re-login before autonomous Codex runs can continue.

## Non-negotiable product constraints

- Offline-first fish encyclopedia is the first core feature.
- AI recognition must only classify against rows in `fish_species` from the authorized AFCD dataset.
- The app must never allow the AI to invent species names.
- Do not hardcode Supabase secrets in source code.
- Do not add paid APIs such as Google Cloud Vision or Stormglass until explicitly approved.

## Next commands after installing Flutter

```bash
cd /c/Users/s0829/fishergo
flutter create --platforms=ios,android .
flutter pub add supabase_flutter flutter_dotenv hive hive_flutter path_provider connectivity_plus image_picker geolocator uuid
flutter pub get
flutter analyze
flutter test
```

Then copy values:

```bash
cp .env.example .env
# fill SUPABASE_URL and SUPABASE_ANON_KEY
```

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

1. Project setup and app shell
2. Supabase schema + RLS
3. Offline-first fish encyclopedia
4. Manual catch logging with offline queue
5. Daily leaderboard
6. AI recognition after MVP stability
7. HK Spot Analyst placeholder only
