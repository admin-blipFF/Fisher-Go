# FisherGO Agent Prompt

Build FisherGO phase by phase. Start with Phase 1 only unless instructed otherwise.

Stack: Flutter, Supabase, PostgreSQL, Supabase Auth, Supabase Storage, Supabase Realtime, Hive local cache.

Rules:
1. Work phase by phase.
2. Show a short implementation plan before each phase.
3. After each phase, report files created, files modified, tests run, artifacts, and limitations.
4. Do not skip RLS.
5. Do not hardcode Supabase keys.
6. AI recognition must only classify against existing `fish_species` rows from the AFCD dataset.
7. Do not add paid APIs yet.

Phase 1: Flutter app shell, Supabase config, bottom navigation.
Phase 2: Database schema, RLS, seed data.
Phase 3: Offline-first fish encyclopedia.
Phase 4: Manual catch logging + offline sync.
Phase 5: Daily leaderboard.
Phase 6: AI recognition after MVP stability.
Phase 7: HK Spot Analyst placeholder only.
