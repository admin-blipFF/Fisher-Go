# FisherGO Production Quality Master Plan

> **For agentic workers:** Use `superpowers:subagent-driven-development` for independent workstreams or `superpowers:executing-plans` for sequential execution. Expand each workstream into a focused implementation plan before editing shared production code.

**Goal:** Turn the current FisherGO Flutter prototype into a secure, maintainable, location-accurate Android-first mobile game with a reliable web preview.

**Target architecture:** MapLibre renders real map geometry. FisherGO renders its selected avatar, fishing spots, interaction radius, events, effects, and HUD as a separate game overlay. Supabase owns authenticated data and server-only integrations. Hive remains an offline cache, not a second source of truth.

**Primary stack:** Flutter/Dart, MapLibre, Supabase Auth/Postgres/Storage/Edge Functions, Hive, Vercel, and Android emulator API 35.

---

## 1. Executive Decision

Stop treating the current `CustomPainter` background as the long-term map engine.

Adopt these rules:

1. Real vector data determines Hong Kong land, water, roads, buildings, piers, bearing, and zoom.
2. Seedream or ImageGen assets are materials and game objects only. They never determine coastline or road geometry.
3. Android is the release source of truth. Web remains a supported preview with the same game data and a reduced graphics preset when needed.
4. Fishing spots come from a verified registry. Development fixtures never appear in production.
5. Existing gameplay is migrated incrementally; do not rewrite the entire app.

MapLibre's [official Flutter plugin](https://github.com/maplibre/flutter-maplibre-gl) supports Android, iOS, and web, with style, camera, gestures, location, symbol, line, fill, and fill-extrusion APIs. It is the recommended proof-of-concept candidate, subject to the objective decision gate in Workstream 5.

## 2. Audit Findings

### P0: Production exposes privileged credentials

Current state (2026-08-01): the client-side `.env`/VectorEngine exposure and
direct provider call described below are historical incident findings. The
current client uses the authenticated `recognize-fish` Edge Function boundary,
the build artifact scan passes, and the remaining open actions are credential
rotation plus live provider-upgrade evidence. Keep the original evidence below
as the incident baseline; do not treat it as a description of the current
source tree.

Evidence:

- `pubspec.yaml:41` bundles `.env` as a Flutter asset.
- `scripts/vercel-build.sh:11` creates that file during production build.
- `lib/main.dart:44` loads it in the client.
- `lib/features/catches/data/fish_recognition_service.dart:17-18,66` reads and sends the VectorEngine key from the client.
- The deployed `/assets/.env` currently responds successfully instead of being absent.
- The local file contains privileged provider credentials, not only public client configuration.

Impact: anyone can retrieve the deployed asset, and immutable deployment caches can preserve it after a normal code edit.

Immediate owner action: rotate the VectorEngine key, Vercel token, Supabase personal/access token, and Google OAuth client secret. Never put rotated values into this repository or a Flutter asset.

### P0: Supabase RLS does not isolate player data

Evidence:

- `supabase/migrations/001_player_cloud_sync.sql:9,26,38` stores `user_id` as free-form text.
- Its policies at `:56-63` use `USING (true) WITH CHECK (true)`.
- Grants at `:66-68` do not enforce ownership.
- `supabase/migrations/0002_seed_and_policy.sql` allows unrestricted anonymous species inserts.

Impact: a public client may be able to read or modify another player's data.

### P1: Login and tutorial behavior is incorrect

- `lib/main.dart:62,121-125` automatically starts anonymous sign-in.
- `game_home_screen.dart:214` treats any session as sufficient to bypass identity choice.
- `profile_screen.dart:362,439-446` treats anonymous users as fully signed in.
- `game_home_screen.dart:58,320-321` permanently disables the tutorial through a debug constant.

Required sequence: login/guest choice, then skippable tutorial, then game. Guest-to-account upgrade must preserve progress.

### P1: The current map renderer has reached its architectural limit

- `game_map_renderer.dart` is over 4,500 lines.
- `paint()` at `:475-495` stacks procedural, micro-tile, seam, atmosphere, vector, and fallback layers.
- Production checks show stepped land polygons, rectangular surface blocks, weak roads, and synthetic water/land boundaries.
- Rotation works mechanically but rotates malformed geometry.
- `hk_terrain_mvp.json` is a multi-megabyte monolithic asset with very few buildings and only five fishing nodes.

Root cause: geometry ingestion, classification, projection, materials, labels, fallbacks, and gameplay objects are coupled in one painter. More textures cannot correct geometry or projection.

### P1: Development fishing points are in production

- Resolved on 2026-07-19: the debug `沙田希爾頓中心測試釣點` and its
  compile-time flag were removed from `game_home_screen.dart` and
  `public_app_config.dart`.
- The screen now loads active verified public-pier rows only; the broad island
  geocode seed remains quarantined.

There is no auditable source, safety status, access status, review date, or environment flag per point.

### P1: Release and operational readiness is incomplete

- `android/app/build.gradle.kts:29-31` signs release builds with the debug key.
- The next traceable release increments the app version to `0.1.1+2`; Play
  signing and internal-track distribution remain separate open gates.
- There is no repository CI, integration suite, visual-golden suite, crash reporting, or frame-performance gate.
- Production logs report missing Noto glyph coverage for Traditional Chinese.
- Flutter semantics expose almost no useful controls to accessibility or browser automation.

### P1: Assets and binaries are oversized

Measured baseline:

- Source assets: about 1.0 GiB and 1,540 files.
- Fish assets: about 913 MiB.
- Built web directory: about 148 MiB.
- Release APK: about 160 MiB.
- Backup and temporary files exist inside recursively bundled asset folders.

### P2: Feature boundaries are too broad

- `game_home_screen.dart`: over 4,700 lines.
- `catch_log_screen.dart`: over 2,300 lines.
- `profile_screen.dart`: about 1,950 lines.

These widgets combine UI, state, storage, authentication, content data, dialogs, and orchestration, making regression testing and parallel-agent work risky.

### Existing strengths

- `flutter analyze --no-pub` passes.
- All 191 current tests pass.
- Core loops already exist: GPS map, bite/haptic minigame, collection states, real-catch photo flow, daily rewards, avatar/profile, leaderboard, and announcements.

The test suite is useful but does not cover client-secret exposure, RLS isolation, visual geometry, release signing, or end-to-end authentication.

## 3. Delivery Gates

| Gate | Priority | Outcome | Dependency |
|---|---|---|---|
| 0 | P0 | Secrets removed, rotated, and server-proxied | None |
| 1 | P0 | Per-user database isolation | Gate 0 |
| 2 | P1 | CI, visual, release, and performance guardrails | Gate 0 |
| 3 | P1 | Correct auth, guest, tutorial, and upgrade flow | Gates 1-2 |
| 4 | P1 | Verified fishing-spot registry | Gate 1 |
| 5 | P1 | MapLibre proof and engine decision | Gate 2 |
| 6 | P1 | Production vector map plus game overlay | Gates 4-5 |
| 7 | P1 | Asset and runtime budgets | Gates 2 and 6 |
| 8 | P1 | Complete Android vertical slice | Gates 3-7 |
| 9 | P1 | Signed Android beta and monitored web preview | Gate 8 |
| 10 | P2 | Live operations and anti-cheat | Gate 9 |

Do not start Gates 5-10 while either P0 gate remains open.

## 4. Workstream 0: Credential Incident

**Modify**

- `pubspec.yaml`
- `scripts/vercel-build.sh`
- `lib/main.dart`
- `lib/features/catches/data/fish_recognition_service.dart`

**Create**

- `lib/core/config/public_app_config.dart`
- `supabase/functions/recognize-fish/index.ts`
- `test/security/client_build_secret_test.dart`
- `tool/check_client_artifacts_for_secrets.dart`

**Steps**

1. Rotate every exposed credential in its provider dashboard.
2. Remove `.env` from Flutter assets and stop generating it in Vercel builds.
3. Pass only the public Supabase URL and public anon/publishable key through `--dart-define`.
4. Move fish recognition to an authenticated Supabase Edge Function.
5. Store the model key only as a Supabase server secret.
6. Enforce CORS, MIME type, request-size, rate, and authenticated-user checks.
7. Rebuild and redeploy Vercel, replacing the deployment containing the cached asset.
8. Fail builds when `.env`, private keys, known provider secret names, or high-confidence token patterns appear in client artifacts.

**Acceptance**

- `/assets/.env` returns 404.
- `.env` is absent from asset manifests, web build, APK, and AAB.
- No privileged key is present in `main.dart.js` or Android assets.
- Recognition succeeds only through the server function.
- Unauthenticated and oversized requests are rejected.
- Secrets never appear in logs or snapshots.

## 5. Workstream 1: Database Isolation

**Create**

- `supabase/migrations/<timestamp>_repair_player_rls.sql`
- `supabase/migrations/<timestamp>_consolidate_player_schema.sql`
- `supabase/tests/player_rls_test.sql`

Do not rewrite applied migration history.

**Steps**

1. Inventory production row counts and active table usage.
2. Convert ownership to `uuid references auth.users(id) on delete cascade`.
3. Backfill valid identities before enforcing the foreign key.
4. Replace permissive policies with `USING (auth.uid() = user_id)` and matching `WITH CHECK`.
5. Remove anonymous catalog writes.
6. Choose one canonical profile, catch, and collection table per domain.
7. Migrate data before deprecating duplicate tables.
8. Keep service-role access inside trusted server functions only.

**Acceptance**

- User A cannot select, insert, update, or delete User B's rows.
- Anonymous clients read only explicitly public catalog data.
- Anonymous clients cannot mutate catalog data.
- Account deletion cascades or anonymizes owned data according to policy.
- Two-user RLS tests run in CI.

Current progress: the local and linked-safe player RLS suites pass. The legacy
`profiles`/`catches` proof now has a protected hosted path: because the managed
Supabase `auth` schema rejects synthetic user inserts in the linked pgTAP
runner, `tool/prepare_supabase_legacy_rls_test.dart` resolves two dedicated
disposable password users through Auth REST and renders their UUIDs into a
transaction-only fixture. The local rendered fixture passed 18 pgTAP
assertions; `.github/workflows/supabase-content-release.yml` runs it after
linked migrations and lint when the owner supplies the protected test-user
secrets. Gate 1 remains partial until that hosted run produces evidence.

## 6. Workstream 2: Quality Guardrails

**Create**

- `.github/workflows/flutter-ci.yml`
- `.github/workflows/supabase-ci.yml`
- `integration_test/startup_auth_flow_test.dart`
- `test/goldens/game_map/`
- `tool/check_asset_budget.dart`
- `docs/quality-gates.md`

**Required checks**

1. Format, analyze, and unit/widget tests.
2. Client artifact secret scan.
3. Supabase migration and RLS tests.
4. Flutter web release build.
5. Android release AAB build.
6. Asset-manifest and bundle budget.
7. Golden screenshots at 390x844 and 1440x900.
8. API 35 emulator smoke test for startup, map, rotation, spot selection, and minigame entry.

**Device rule**

- Never target the attached Android 6/API 23 photo-frame device.
- Use an Android emulator, API 35 by default.
- Add a preflight guard rejecting API 23 and the known photo-frame serial.

**Acceptance**

- Required checks block merge on failure.
- A release commit is traceable to web and Android artifacts.
- Golden updates require explicit visual review.

Current progress: the Web map benchmark now loads a reviewed structural visual
golden manifest for the 390x844 and 1440x900 gameplay viewports. It checks
dimensions, colour diversity/range, adjacent-sample change, dominant-colour
ceiling, and a successful OpenFreeMap response while allowing live OSM tile
pixels to change. The visual golden is independent from the still-open Web
motion budget. On 2026-08-01, the current Web release also passed the client
artifact secret scan and Web asset budget at a generated package size of
`89.6 MiB`. On 2026-08-03, the GitHub-connected Vercel project auto-deployed
commit `5692b7b` to both canonical production aliases. The deployed verifier
passed both roots, exact release ID `0.1.1+2-5692b7bb9aaa`, secret-asset
rejection, matching manifests, and cache headers. The live two-viewport smoke
also passed OpenFreeMap tile and visual-golden checks; motion remains open at
`33.3 ms` p95 / `2.47%` jank on `390x844` and `66.5 ms` p95 / `20.79%` jank
on `1440x900`.
The full-map/panorama modal now uses the same `GameMapLibre` vector surface as
the GameHome map instead of a second raster `FlutterMap` implementation. This
keeps camera gestures, GPS coordinates, OSM water/roads/buildings, selected
avatar, and fishing-spot callbacks consistent across both map views. The
API 35 `panorama_map_flow_test.dart` smoke passed on `emulator-5554`; the known
API 23 photo-frame serial was skipped. The Web motion budget and Android frame
time budget remain open gates and are not claimed closed by this consistency
change.

The API 35 CI smoke workflow now fails fast with `set -euo pipefail` and its
source contract covers all 12 startup, map, minigame, offline, reward,
permission, and photo profiles. The latest local suite has `418` passing
tests; this strengthens release evidence without claiming the still-open
Android or wide-screen Web motion budgets.

## 7. Workstream 3: Auth and Onboarding State Machine

**Create**

- `lib/features/auth/application/startup_flow_controller.dart`
- `lib/features/auth/domain/player_identity_state.dart`
- `test/features/auth/startup_flow_controller_test.dart`

**State model**

- `signedOut`: show login/guest choice.
- `guestLocal`: local progress plus upgrade call to action.
- `anonymousCloud`: cloud guest plus upgrade call to action.
- `authenticated`: named account and cloud sync.
- `tutorialPending`: shown only after identity choice.
- `ready`: enter the game.

**Steps**

1. Remove automatic anonymous sign-in from global startup.
2. Let the guest action deliberately create the chosen guest identity.
3. Replace `user != null` checks with explicit identity states.
4. Remove `_debugDisableTutorial`; use a debug-only feature flag when necessary.
5. Persist completion or skip per player identity.
6. Test guest-to-email and guest-to-Google upgrades.
7. Add clear account deletion, sign-out, and local/cloud data behavior.

**Acceptance**

- Login/guest choice appears before tutorial on a fresh install.
- Tutorial skip works and persists.
- Returning authenticated users do not repeat onboarding.
- Anonymous profiles show an upgrade action, never a blank identity.
- Upgrade preserves level, collection, catches, tasks, and inventory.

Current evidence: local guest data now migrates once into the first account
namespace, including profile progress, fish collection, the legacy global catch
queue, account-scoped boat rental state, and the account-scoped queue. Auth-
session restoration runs the same guarded migration, and focused tests verify
that a second account cannot receive the first guest's cache. The anonymous
Email-upgrade path now restores the local account namespace immediately after
`updateUser`; live Supabase email/Google upgrade and cloud conflict resolution
remain release gates. Native Android Google linking now uses the Supabase
Flutter `linkIdentity` launch path and the registered `fishergo://auth/callback`
scheme, while Web keeps the production HTTPS callback. A provider-level
identity smoke is available at
`tool/verify_supabase_auth_upgrade.dart` and requires a disposable test
account before it can produce live evidence.

## 8. Workstream 4: Verified Fishing-Spot Registry

**Create**

- Supabase `fishing_spots` table and migration.
- `lib/features/fishing_spots/domain/fishing_spot.dart`
- `lib/features/fishing_spots/data/fishing_spot_repository.dart`
- `lib/features/fishing_spots/application/nearby_spots_controller.dart`

Move development fixtures to `test/fixtures/` and remove production constants from `game_home_screen.dart`.

**Minimum fields**

- ID, Traditional Chinese name, optional English name.
- Latitude, longitude, coordinate precision.
- Shore, pier, rock, island, reservoir, pond, or boat type.
- Draft, community-reported, verified, or suspended status.
- Public access and legal/safety notes.
- Source, source reference, reviewer, review time, active flag.
- Habitat tags, species weights, and environment.

**Rules**

- Main game shows active, verified spots only.
- Interaction requires real proximity.
- Full map may browse distant verified spots.
- Never generate a fake spot to keep the screen busy.
- Marker art may be game-like; coordinates remain data-driven.

**Acceptance**

- The Sha Tin Hilton test point is absent from production.
- A location with no verified point within 500 m shows zero nearby spots and a full-map action.
- Every production spot has an auditable source and review date.
- Suspended points disappear without a client release.

Current progress: the bundled registry and additive Supabase migration
`0017_fishing_spot_habitat_weights.sql` now carry stable fish-ID weights for
Tung Chung/North Water, Sam Mun Tsai/Tai Po inner water, Tsing Ma waters, and
East Water. The clean local Supabase stack applied the migration and passed
the local database suite. The protected content-release workflow now includes
a downstream anon-key habitat verifier before hosted gameplay smoke; linked
production content deployment remains an owner-controlled action and has not
run in this workspace.

An API 35 current-source vertical-slice rerun passed on `emulator-5554` for
startup/auth, map rotation, GPS-centered verified-spot selection, the
bite-first minigame, Daily Task reward claim, offline reconnect,
denied-location recovery, and a real network-toggle recovery. The preflight
continued to exclude API 23 serial `0123456789ABCDEF`. This is correctness
evidence only; the Android native motion p95 gate remains open. Evidence is
`tmp/android-vertical-slice-smoke-20260803.json`.

## 9. Workstream 5: Map Engine Proof

**Candidates**

- A: Continue `CustomPainter`.
- B: MapLibre vector base plus FisherGO overlay. **Recommended.**
- C: Full 3D engine. Consider only if the MapLibre proof fails and a separate budget is approved.

**Reference locations**

- Sha Tin: urban roads and river.
- Victoria Harbour: coastline, piers, dense roads, and buildings.

**Proof**

1. Create an isolated map screen with the current Flutter version.
2. Load a legal vector-tile source and FisherGO-owned style JSON.
3. Render mapped land, all water, major/local roads, buildings, piers, and coastline.
4. Follow GPS at an approximately 500 m gameplay scale.
5. Support gesture rotation and compass reset on Android and web.
6. Add one selected-avatar overlay and three verified spot markers.
7. Benchmark Android emulator and current desktop/mobile web targets.
8. Verify attribution, caching terms, and expected monthly tile cost.

**Decision gate**

Adopt MapLibre only when:

- Sha Tin and Victoria Harbour topology is correct.
- Roads remain readable while tilted and rotated.
- No texture seams or terraced polygon artifacts appear.
- Player and spots remain accurate at bearings 0, 90, 180, and 270.
- Android p95 frame time is at most 20 ms during normal motion.
- Web remains interactable at 30 FPS or better on agreed devices.
- Camera, tap, and overlay behavior is consistent on Android and web.
- Licensing and operating cost are approved.

If the proof fails, record the failed metric before selecting another engine. Do not return to open-ended painter patching.

## 10. Workstream 6: Production Map and Overlay

**Target modules**

- `lib/features/map/domain/`: camera, viewport, geospatial models.
- `lib/features/map/data/`: style, tile source, offline-cache configuration.
- `lib/features/map/application/`: location and camera controllers.
- `lib/features/map/presentation/base_map/`: MapLibre host.
- `lib/features/map/presentation/game_overlay/`: avatar, spots, rings, events, effects.

**Layer order**

1. Vector land and water.
2. Roads, paths, buildings, and piers.
3. Subtle game materials driven by vector feature type.
4. Deterministic environmental props with density limits.
5. Fishing spots and event objects.
6. Selected player avatar and interaction radius.
7. HUD in screen space.

**Visual rules**

- Geometry always comes from vector data.
- Seamless, restrained textures preserve road readability.
- Water uses subtle animated highlight and depth tint, not a repeated full-screen image.
- Land variation uses deterministic seeds to avoid visible repetition.
- Fishing spots use depth, occlusion order, shadow, state color, and a clear tap target.
- The player marker uses selected character art and stays anchored to GPS.
- HUD never rotates with the map.

### Material-pattern experiment decision (2026-08-01)

An opt-in MapLibre `fill-pattern` candidate was tested over the real OSM
land-use and water polygons. This preserved coastline, roads, rivers,
buildings, camera rotation, and spot geometry, and the regenerated v2 grass
tile was visually cleaner than the first candidate. It was not promoted:
matched API 35 warm native proof measured p95 `54 ms` / `34.85%` jank for the
vector-color control versus `62 ms` / `43.88%` with patterns, with both runs
above the `20 ms` gate. The experiment-only style, asset registration, and
benchmark switch were removed. Future material work must first prove a stable
frame-time win and a seamless visual tile before it can re-enter the default
path.

The next Web wide-screen diagnostic removed only the OSM `building` fill
layer. It did not improve the 1440x900 motion tail (`66.6 ms` p95 in both
matched runs), and it regressed the 390x844 p95 from `16.8 ms` to `33.3 ms`.
Keep building footprints in the accepted style; future performance work must
target renderer/composition cost without weakening geographic context.

The final stable Web rebuild then passed both structural map goldens and
OpenFreeMap tile checks, with `55.52 FPS` / p95 `33.3 ms` on 390x844 and
`42.13 FPS` / p95 `66.6 ms` on 1440x900. This closes the current visual
rebaseline but leaves the wide-screen motion budget open.

The 2026-08-03 wide-screen zoom experiment was rejected after matched local
Web runs. Zoom `17.0` produced about `36 FPS` with p95 `66.6 ms` and
`26.11-28.57%` jank at 1440x900; zoom `17.75` reduced p95 to `50.1 ms` but
raised jank to `40.13%`. Both visual goldens passed, but the combined motion
budget did not, so the production camera remains at zoom `16.0` and future
work must target renderer/composition cost rather than hiding geography.

The 2026-08-03 Android merged-landcover diagnostic was also rejected after a
matched API 35 host-GPU run on `emulator-5554`. Merging the OSM grass, wood,
and farmland classes into one filtered fill kept map readiness and geography
intact, but gfx p95 stayed at `32 ms` while slow draw commands increased from
`88` to `110`; jank was `29.39%` versus `28.16%`, with no ANR in either run.
The opt-in style transformer and flag were removed, so the production Android
renderer remains unchanged and the 20 ms motion gate stays open. Evidence is
`tmp/android-map-benchmark-landcover-control-20260803.json` and
`tmp/android-map-benchmark-landcover-candidate-20260803.json`.

The follow-up `road-main` expression cleanup was retained after two matched
API 35 host-GPU pairs on `emulator-5554`. The layer already filters to
motorway, trunk, primary, secondary, and tertiary roads, so removing its
unreachable `minor/service` paint branches preserved road hierarchy and map
readiness while reducing slow draw commands from `105/133` to `98/112` and
slow bitmap uploads from `15/16` to `7/5`. The candidate remained ANR-free and
did not close the 20 ms motion gate; the evidence is
`tmp/android-map-benchmark-road-expression-control-api35.json`,
`tmp/android-map-benchmark-road-expression-candidate-api35.json`,
`tmp/android-map-benchmark-road-expression-control-api35-repeat.json`, and
`tmp/android-map-benchmark-road-expression-candidate-api35-repeat.json`.

The current-source textureless direct-Hybrid-Composition proof was also
rechecked on API 35. The HUD and real OSM map remained visible, but gfx p95 was
`53 ms` with `96.63%` jank and Flutter total p95 `105 ms`, so the product keeps
texture mode and the retained `tlhc_vd` composition. A native-only follow-up
then hid the `building-3d` layer only during camera motion and restored it at
idle. Its control/candidate p95 was `42/44 ms` and jank `9.66%/10.94%`; the
lower p99 did not offset the worse p95/jank, so that profile-only callback was
removed as well. Evidence is `tmp/android-map-benchmark-hc-textureless-current-
20260803.json`, `tmp/android-native-map-benchmark-building-motion-control-
20260803.json`, and `tmp/android-native-map-benchmark-building-motion-toggle-
20260803.json`.

The follow-up Android fill-antialias candidate was rejected after matched
API 35 host-GPU GameHome traces. It improved the isolated native proof from
`62 ms` to `58 ms` p95, but complete GameHome moved from `40 ms` to `46 ms`
and then `42 ms` on repeat, while Flutter p95 total moved from `53 ms` to
`61 ms` and `56 ms`; the candidate was removed. A native player/spot layer
candidate was also rejected: gfx p95 stayed at `40 ms`, slow draw commands
increased from `105` to `128`, and the full marker composition did not produce
a stable win. Both paths remain diagnostic-only or removed, and the 20 ms
Android motion gate stays open. Evidence is recorded in
`docs/quality-gates.md` and the referenced `tmp/` traces.

The 2026-08-03 building-base diagnostic was rejected after two matched API 35
host-GPU pairs on `emulator-5554`. Keeping real per-building heights while
replacing the `render_min_height` lookup with a constant zero preserved map
readiness and geography, but gfx p95 moved from `34` to `38 ms` on the first
pair and from `42` to `40 ms` on the repeat. The minor repeat improvement was
not stable enough to promote, so the dynamic extrusion base remains in the
production style and the 20 ms motion gate stays open. Evidence is
`tmp/android-map-benchmark-building-base-control-api35.json`,
`tmp/android-map-benchmark-building-base-candidate-api35.json`,
`tmp/android-map-benchmark-building-base-control-api35-repeat.json`, and
`tmp/android-map-benchmark-building-base-candidate-api35-repeat.json`.

The 2026-08-03 Web road-layer merge diagnostic was also rejected. A valid
query-gated style merged `road-medium` and `road-major` into one `road-main`
layer while preserving OpenFreeMap responses and both visual goldens, but
desktop p95 stayed `66.7 ms` in both control/candidate pairs. Candidate FPS
was `35.60/35.08` versus control `36.03/36.06`; the query and source contract
were removed after the matched repeats. The initial nested zoom-expression
shape was rejected by MapLibre before the valid A/B and is not production
code. Evidence is `tmp/web-map-benchmark-road-merge-control-390-1440.json`,
`tmp/web-map-benchmark-road-merge-candidate-390-1440.json`,
`tmp/web-map-benchmark-road-merge-control-repeat-390-1440.json`, and
`tmp/web-map-benchmark-road-merge-candidate-repeat-390-1440.json`.

The following Web raster-basemap diagnostic was rejected as well. A valid
query-gated Carto `light_nolabels` raster style loaded real OSM-derived
roads/water/land and preserved GPS camera, rotation, markers, tile responses,
and both visual goldens. The first desktop control/candidate pair measured
`41.31/39.53 FPS`, p95 `66.6/50.0 ms`, and jank `19.42%/23.86%`; the matched
repeat measured `41.54/36.00 FPS`, p95 `50.1/66.6 ms`, and jank
`20.77%/26.67%`. The candidate's pale cartographic surface also missed the
FisherGO game-map visual direction, so the query, source contract, and
temporary raster golden were removed. Evidence is
`tmp/web-map-benchmark-raster-control-390-1440.json`,
`tmp/web-map-benchmark-raster-candidate-390-1440-v4.json`,
`tmp/web-map-benchmark-raster-control-repeat-390-1440.json`, and
`tmp/web-map-benchmark-raster-candidate-repeat-390-1440.json`.

The Web native-player sprite diagnostic was then rejected. A build-gated
candidate registered the selected avatar body asset in a MapLibre-native
`MarkerLayer` and preserved OpenFreeMap responses, populated visual goldens,
GPS centering, and compass rotation. The first matched pair measured mobile
`54.99/55.38 FPS` with p95 `33.3/33.3 ms` and desktop `39.78/39.89 FPS` with
p95 `66.6/66.6 ms`; repeats measured mobile `54.30/54.64 FPS` and desktop
`38.40/40.36 FPS`, with desktop jank `20.42%/21.39%`. Browser inspection
confirmed the candidate showed the selected body but lost the existing
marker glow/navigation treatment, so the Web flag and asset path were
removed. The current Flutter marker remains the production Web path. Evidence
is `tmp/web-map-benchmark-native-player-control-390-1440.json`,
`tmp/web-map-benchmark-native-player-candidate-390-1440.json`,
`tmp/web-map-benchmark-native-player-control-repeat-390-1440.json`, and
`tmp/web-map-benchmark-native-player-candidate-repeat-390-1440.json`.

The next Web motion-only pixel-ratio candidate was rejected. The new
query-gated `?fishergo_motion_pixel_ratio=0.5` path attempted to lower WebGL
resolution only during camera motion and restore the adaptive baseline at
rest. The first implementation triggered a MapLibre near/far matrix error and
an `idle`/`setPixelRatio` recursion. A load-gated correction removed the
recursion, but the formal runner still timed out waiting for `flutter-view`
and produced no admissible candidate frame trace. The query hook was removed;
the accepted adaptive `0.75` idle preset remains unchanged. Evidence is
`tmp/web-map-benchmark-motion-pixel-control-390-1440-20260803.json` and
`tmp/web-map-benchmark-motion-pixel-candidate-diagnostic-20260803.json`.

The following Web canvas antialias candidate was also rejected. The new
query-gated `?fishergo_canvas_antialias=0` path disabled MapLibre WebGL MSAA
while keeping the style, GPS camera, tile source, and marker contract fixed.
Both matched pairs passed populated visual goldens and HTTP 200 OpenFreeMap
checks, but desktop repeats remained at p95 `66.6/66.7 ms` with about
`21%` jank and mobile showed no stable gain. The hook was removed because
canvas antialiasing is not the primary release-gate bottleneck. Evidence is
`tmp/web-map-benchmark-canvas-antialias-control-20260803.json`,
`tmp/web-map-benchmark-canvas-antialias-candidate-20260803.json`,
`tmp/web-map-benchmark-canvas-antialias-control-repeat-20260803.json`,
`tmp/web-map-benchmark-canvas-antialias-candidate-repeat-20260803.json`, and
`tmp/web-map-benchmark-canvas-antialias-diagnostic-20260803.json`.

**Migration**

1. Put the new map behind a feature flag.
2. Keep the old renderer as a temporary rollback.
3. Feed both from the same location, camera, and spot repositories.
4. Remove the old map after two passing release candidates.
5. Delete obsolete terrain assets only after rollback is no longer needed.

**Acceptance**

- Default camera shows approximately 500 m of useful local context.
- Hong Kong rivers, coastline, sea, and Victoria Harbour appear from map data.
- Roads remain readable without labels.
- Geometry, avatar-relative objects, and spots rotate consistently.
- Tap selection works after bearing and camera changes.
- No background rectangle, checkerboard join, stair-step polygon, or giant fallback fill appears.

## 11. Workstream 7: Asset and Runtime Performance

**Steps**

1. Generate a canonical production asset manifest.
2. Move backup, audit, temporary, and generation-source files outside `assets/`.
3. Stop recursively bundling folders when only a production subset is required.
4. Resize assets to display density and convert suitable images to supported modern formats.
5. Lazy-load encyclopedia media and optional audio.
6. Keep only nearby-gameplay assets in the startup bundle.
7. Cache map styles/tiles within licensing terms.
8. Profile image decode, GPU upload, raster cache, and overlay rebuilds.
9. Do not rebuild the map when only HUD state changes.

**Budgets**

- Web bootstrap, excluding lazy encyclopedia media: at most 15 MiB.
- Android store download target: below 100 MiB.
- No backup or temporary file in the Flutter asset manifest.
- Cached first usable map: at most 3 seconds.
- Uncached first usable map: at most 5 seconds on a normal Hong Kong mobile connection.
- Normal Android map motion: p95 frame time at most 20 ms.

The 2026-08-03 current-source Web release now uses an explicit map asset
allowlist rather than recursively bundling `assets/maps/`. The retired
`fishergo_overworld_imagegen_v3.png` is absent from the manifest; the package
measured `86.9 MiB`, a `2.75 MiB` reduction, while the arm64 AAB remained
`75.7 MiB`. The asset budget command passed and
`test/asset_budget_source_test.dart` now guards the allowlist.

## 12. Workstream 8: Android Vertical Slice

The release-candidate flow must pass end to end:

1. Fresh install.
2. Login or guest choice.
3. Complete or skip tutorial.
4. Correct location-permission sequence.
5. GPS-centered map, bearing rotation, and compass reset.
6. Approach and select a verified spot.
7. Wait for bite animation and haptics.
8. Pull the rod and resolve success/failure.
9. Unlock full-color fish icon after game catch.
10. Upload real-catch photo and add hook badge.
11. Advance and claim a daily-task reward.
12. Restart and verify persistence/sync.

Required evidence: controller tests, widget tests, map goldens, API 35 emulator integration, offline/reconnect test, and guest-upgrade test.

Current evidence: API 35 integration now covers startup/tutorial, bite-first
fishing, and daily-task claim persistence. The local guest migration and
reconnect coordinator have focused tests. The catch-log retry path now ignores
late callbacks after disposal and preserves the local queue when a remote retry
throws. CatchLogScreen now exposes the latest connectivity state while keeping
the production Connectivity stream as its default. The deterministic API 35
offline/reconnect integration and the real API 35 network-toggle smoke now
pass: the runner seeds the queue while radios are off, waits for the production
stream to attach, restores Wi-Fi, and verifies replay from 1 to 0. The API 35
emulator may report `mobile` instead of `none` during radio shutdown, so the
device proof asserts the real restore edge rather than a transport label. Real
Supabase photo upload and live email/Google guest-upgrade coverage remain open
before the vertical slice can be called release complete. The client now
has an authenticated private `catch-photos` Storage contract, a separate
`photo_storage_path` column, and a short-lived signed-URL resolver. The
catch-log screen now reads the current user's recent catches and resolves
private photo paths into short-lived signed URLs. Focused coverage is in
`test/catch_history_service_test.dart`; the remaining photo gate is the
configured-project upload/read-back smoke in
`tool/verify_supabase_catch_photo_storage.dart`.

The Android smoke path now has a repeatable API 35 preflight and runner. The
known API 23 photo-frame device remains excluded, and GameHome defers the
location permission prompt until the player taps the locate control so the
login/guest choice and skippable tutorial remain non-blocking. On 2026-08-01,
clean API 35 runs passed the user-fixed denied-location, location-service
disabled, and Android 14 selected-photo profiles; the GPS-free map and catch
photo entry remained usable. A separate clean API 35 lifecycle smoke paused
and resumed the app after a 45-degree map rotation, then successfully rotated
to 90 degrees, proving the GameHome surface remains actionable after resume.
The profile commands are now included in the final API 35 CI matrix.

The encyclopedia vertical slice now presents the discovery stage directly on
each card: unknown and encountered entries keep the species name hidden and
use the locked silhouette, a game catch exposes the full-color icon, and a
verified real catch keeps the photo-proof fish-hook badge. The card footer and
single accessibility label share `FishDiscoveryCopy`; focused artwork/copy
tests, the mobile layout widget test, the full 415-test suite, and analyzer
passed. The global telemetry installer now uses `??=` and leaves an existing
Flutter/integration error handler untouched. A fresh API 35 startup smoke then
passed identity, tutorial skip, GameHome, 0°→45° map rotation, and the visible
`未發現` card state; the runner explicitly skipped API 23 serial
`0123456789ABCDEF`.

The bite-first minigame and panorama MapLibre smoke passed on the same API 35
emulator. Both minigame surfaces expose live-region status announcements and
deterministic action labels for waiting, bite-ready, and resolved states. The
map camera bridge feeds normalized bearing to the GameHome direction HUD, and
`GameMapLibre` now applies the circular `0.25°` threshold before crossing the
native/Web event bridge, reducing small camera-noise callbacks without changing
HUD direction precision. The full 415-test suite, analyzer, API 35
`map_rotation_flow_test.dart`, and the GPS-centered
`map_spot_selection_flow_test.dart` passed on `emulator-5554`; the latter used
`22.354208,114.109537`, and API 23 remained excluded. A matched Web run still
measured 1440x900 p95 `66.7 ms` and jank `17.79%`, so the motion gates remain
open. The latest Web preview completed the remote Flutter build, release
manifest write, and client artifact scan, and is
`https://fishergo-26ejscz0a-klyeung-s-projects.vercel.app` (deployment
`dpl_2H1kpYLFTMZXQ4nduqt3bTzN5ypG`, `READY`). It remains a protected preview
check rather than a public-alias pass; no production alias promotion was
performed.

The next Android cache-lifecycle experiment was measured and rejected. Moving
`MapCachePolicy.configureOnce()` behind the first frame reduced cold readiness
from `3441 ms` to `1899 ms`, but native motion p95 rose from the `44 ms` control
to `48 ms` and then `61 ms` on a warm repeat, with jank near `49.5%`. The
production source was restored; cache policy remains bounded and initialized
with the map. Evidence is recorded in
`tmp/android-map-benchmark-masterplan-cache-deferred-20260801.json` and
`tmp/android-map-benchmark-masterplan-cache-deferred-warm-repeat-20260801.json`.

The following marker-composition experiment was also measured and rejected.
Moving Flutter markers outside `MapLibreMap.children` improved cold readiness to
`1514/1568 ms`, but projecting every marker with `toScreenLocations` on camera
events raised native motion p95 to `61 ms` and the warm repeat to `69 ms`, with
jank still about `49%`. The original MapLibre child composition was restored;
the API 35 rotation and GPS-centered spot-selection flows remained green. The
next motion investigation must avoid a Flutter-side geographic projection on
every camera event. Evidence is recorded in
`tmp/android-map-benchmark-masterplan-marker-overlay-boundary-20260801.json`
and
`tmp/android-map-benchmark-masterplan-marker-overlay-boundary-warm-repeat-20260801.json`.

A pure Dart Web-Mercator projection experiment was then measured and rejected.
The clean Android run measured p95 `61 ms` (warm `57 ms`); a frame-coalesced
variant measured `53 ms` (warm `61 ms`), all worse than the `44 ms` control, with
jank around `48-50%`. The Web visual golden and populated-map proof passed, but
matched 1440x900 motion measured p95 `66.6 ms` and jank `26.23%`, worse than the
`17.79%` control. The candidate flag, projection layer, and tests were removed
from the production path. The next camera-motion work therefore stays at the
native/plugin boundary rather than adding another Flutter-side projection loop.
Evidence is recorded in
`tmp/android-map-benchmark-masterplan-pure-marker-projection-20260801.json`,
`tmp/android-map-benchmark-masterplan-pure-marker-projection-warm-repeat-20260801.json`,
`tmp/android-map-benchmark-masterplan-pure-marker-projection-coalesced-20260801.json`,
`tmp/android-map-benchmark-masterplan-pure-marker-projection-coalesced-warm-repeat-20260801.json`,
and `tmp/web-map-benchmark-masterplan-pure-marker-projection-20260801.json`.

A local `maplibre_android 0.3.5` camera-boundary fork was then measured and
rejected. The candidate gated the plugin's per-camera Flutter `setState` on a
non-empty `MapLibreMap.children` tree, moved gameplay markers to native layers,
and kept attribution/compass outside the platform view. The clean API 35
host-GPU run measured gfx p95 `53 ms`, jank `50%`, and readiness `4381/4536 ms`;
the warm repeat measured p95 `61 ms`, jank `49.1%`, and readiness `1240/1518 ms`,
versus the retained p95 `44 ms` control. Flutter total p95 was `100/96 ms`, so
the fork did not produce a stable motion win. The dependency override, local
fork, and opt-in flag were removed; hosted MapLibre `0.3.5` and the original
Flutter marker path remain the default. Evidence is recorded in
`tmp/android-map-benchmark-masterplan-native-camera-pipeline-20260801.json`
and
`tmp/android-map-benchmark-masterplan-native-camera-pipeline-warm-repeat-20260801.json`.

The next native-only experiment isolated the landcover geometry cost without
Flutter platform-view composition. On API 35 `emulator-5554` with the Intel
UHD 630 host renderer, the clean full-style control measured `78 ms` p95,
`56.65%` jank, and `250 ms` p99; removing all `grass`, `wood`, and `park`
layers measured `46 ms` p95, `23.12%` jank, and `300 ms` p99. Warm repeats
measured `54/350 ms` p95/p99 for the full style and `48/300 ms` with all
landcover disabled. Single-layer clean diagnostics were no-grass `62/350 ms`,
no-wood `54/350 ms`, and no-park `54/300 ms`; no individual layer produced a
stable improvement over the warm control. Because the all-disabled version
removes the land texture that gives the game map its visual identity, the
production style remains unchanged. The proof activity keeps only a
profile-only `noLandcover` switch for future isolation work. Evidence is
recorded in
`tmp/android-native-map-benchmark-landcover-control-api35-20260801.json`,
`tmp/android-native-map-benchmark-landcover-disabled-api35-20260801.json`,
`tmp/android-native-map-benchmark-landcover-control-warm-api35-20260801.json`,
`tmp/android-native-map-benchmark-landcover-disabled-warm-api35-20260801.json`,
`tmp/android-native-map-benchmark-landcover-no-grass-api35-20260801.json`,
`tmp/android-native-map-benchmark-landcover-no-wood-api35-20260801.json`, and
`tmp/android-native-map-benchmark-landcover-no-park-api35-20260801.json`.

The follow-up native layer-family attribution pass was completed without
changing the production style. On API 35 `emulator-5554` with the Intel UHD
630 host renderer, the full-style control measured `58 ms` p95 and `38.91%`
jank. Removing roads, water, waterway, or pier layers did not produce a stable
motion win and would remove required geography. A water-outline-only candidate
also failed the repeat decision: control measured `62 ms` p95 / `38.68%` jank,
while the outline-disabled candidate measured `58 ms` / `46.82%`; both missed
the `20 ms` gate. The profile-only layer switches remain available for future
attribution, but they are not release configuration. The next Android motion
investigation should therefore stay at the native camera/render pipeline and
seek a stable frame-time reduction while preserving the full OSM layer family.
Evidence is recorded in
`tmp/android-native-map-benchmark-layer-control-api35-20260801.json`,
`tmp/android-native-map-benchmark-layer-no-roads-api35-20260801.json`,
`tmp/android-native-map-benchmark-layer-no-water-api35-20260801.json`,
`tmp/android-native-map-benchmark-layer-no-waterway-api35-20260801.json`,
`tmp/android-native-map-benchmark-layer-no-pier-api35-20260801.json`,
`tmp/android-native-map-benchmark-water-outline-control-api35-20260801.json`,
`tmp/android-native-map-benchmark-water-outline-disabled-api35-20260801.json`,
`tmp/android-native-map-benchmark-water-outline-control-repeat-api35-20260801.json`,
and
`tmp/android-native-map-benchmark-water-outline-disabled-repeat-api35-20260801.json`.

The next bounded Android render candidate was rejected at the
production-like GameHome boundary. `fill-antialias=false` on the OSM `grass`,
`wood`, `park`, and `water` fills looked promising in the isolated native
proof (`58 ms` p95 / `35.71%` jank on the repeat), but the complete
platform-view run measured `65 ms` p95 / `49.6%` jank, while the restored
production-style rerun measured `81 ms` / `48.76%`; candidate Flutter total
p95 was `137 ms` versus `116 ms` after restore. Both miss the `20 ms` gate and
the direction is not stable enough to promote. The production Dart style and
profile asset were restored; the profile-only switch remains for future
attribution, and no geography was weakened. The API 35 real GameHome rotation
flow and GPS-centered verified-spot selection flow still passed; the API 23
photo-frame serial remained excluded. Evidence is recorded in
`tmp/android-native-map-benchmark-fill-aa-control-api35-20260801.json`,
`tmp/android-native-map-benchmark-fill-aa-disabled-api35-20260801.json`,
`tmp/android-native-map-benchmark-fill-aa-control-repeat-api35-20260801.json`,
`tmp/android-native-map-benchmark-fill-aa-disabled-repeat-api35-20260801.json`,
`tmp/android-map-benchmark-fill-aa-production-api35-20260801.json`,
`tmp/android-map-benchmark-fill-aa-production-control-restored-api35-20260801.json`,
`tmp/android-map-benchmark-masterplan-baseline-20260801.json`,
`tmp/android-native-map-fill-aa-control-binary.png`, and
`tmp/android-native-map-fill-aa-disabled-binary.png`.

## 13. Workstream 9: Release Readiness

**Android**

1. Create a protected upload key and Play App Signing configuration.
2. Remove debug release signing.
3. Increment version/build number per release.
4. Produce AAB, symbols, privacy policy, screenshots, and data-safety answers.
5. Test denied permissions, limited photo access, location disabled, and resume.
6. Run Play internal testing before closed testing.

**Web**

1. Alias `fisher-go.app` and `www.fisher-go.app` to the same production deployment.
2. Post-deploy check canonical URL, Flutter startup, map load, rotation, and secret-asset absence.
3. Configure cache headers by asset class.
4. Keep a tested web graphics preset rather than scattered device checks.

Current progress: `scripts/deploy.sh` now requires the production Vercel token
and public Supabase build values, and refuses to promote non-canonical aliases
before it calls Vercel. The post-deploy verifier still remains the evidence
gate for the actual public deployment. On 2026-08-01, the current source built
an arm64 release AAB (`75.7 MiB`) and passed the client secret scan and asset
budget; `jarsigner` confirmed it is unsigned. Protected keystore signing and
Play internal-track installation therefore remain explicit owner gates.

The Windows-native companion `scripts/deploy.ps1` now provides the same
production path for this workspace. It refuses to run unless the operator
passes `-PromoteProduction`, and its latest Preview proof reached `READY` with
an authenticated manifest/bootstrap/secret-asset check. Because Windows
Application Control blocked the local `impellerc.exe`, the latest production
promotion used the equivalent remote Vercel build path; both custom aliases
now point to the verified deployment and the public browser smoke passed the
startup/tutorial/map visual checks.

The protected `.github/workflows/web-release.yml` manual workflow now owns the
CI path as well. It resolves the shared release ID, supplies public Supabase
build values and that identity to Vercel's remote build, then runs the
canonical alias verifier. It is source-tested and YAML-validated but has not
been dispatched; the manual remote deployment path has nevertheless completed
the current Web production promotion. The wide-screen motion budget remains
open after the production smoke (p95 `66.7 ms`, jank `20.94%`).

The protected `.github/workflows/web-production-smoke.yml` workflow now binds
the exact public release-manifest check to the Chromium guest/tutorial/map
smoke and uploads both viewport screenshots. Motion-budget enforcement is
opt-in until the wide-screen gate is closed.

The GitHub-connected Vercel project auto-deployed commit `69f3963` to
Production on 2026-08-03. The deployed verifier passed both custom aliases,
404 secret-asset checks, matching release manifests, and cache-header checks.
The live populated-map runner measured `56.84 FPS` / p95 `33.3 ms` /
`1.41%` jank at 390x844 and `42.23 FPS` / p95 `50.1 ms` / `19.34%` jank at
1440x900; the release boundary is healthy, while the wide-screen motion gate
remains open.

The Vercel build boundary now also fails closed when `VERCEL_ENV=production`
(or `FISHERGO_REQUIRE_SUPABASE=true`) and either public Supabase build value is
missing. Preview/local diagnostics retain the deliberate no-Supabase path;
the source contract and shell syntax checks pass.

The Web cache policy is now enforced by `test/vercel_headers_source_test.dart`.
Release entrypoints and unversioned map/runtime assets revalidate, while only
the build-ID-query-busted `main.dart.js` is immutable. Branding icons retain a
short one-day cache with stale-while-revalidate.

The deployed-Web verifier now checks those effective headers on each canonical
alias, including the root page, Flutter bootstrap, versioned Dart payload, and
release manifest. The source and stale-header regression tests pass. The
2026-08-03 live promotion and two-viewport smoke now provide current evidence
for the canonical aliases; only the desktop Web motion budget remains open in
this release boundary.

A preview-only Vercel deployment of the current source reached `READY` and was
checked through authenticated Vercel curl: root/bootstrap/release manifest
revalidate, the build-ID versioned Dart payload is immutable, the asset
manifest revalidates, and `/assets/.env` returns `NOT_FOUND`. It remains a
protected preview and does not change either production alias.

The protected Android release workflow now writes a Web companion manifest,
compares `release_id`, `app_version`, and `git_sha` with the Android manifest
before artifact scanning/upload, and retains both manifests in the signed
release artifact. It now preserves the signed arm64 APK, creates a separately
signed x86_64 APK for an API 35 release-config smoke, verifies all three
Android signatures, and uploads the minimum-60-frame map trace alongside the
release artifacts. The shared identity and workflow contracts are locally
tested; protected signing, the actual CI emulator run, and Play distribution
remain owner-controlled.

The restored production source was rebuilt for both release targets after the
rejected fill-AA experiment: Web package `89.6 MiB` and arm64 AAB `75.7 MiB`.
The client secret scan and asset-budget check passed; `jarsigner` still reports
the local AAB as unsigned. Its SHA256 is
`BEF81EA3EF3B5DDB8D877A3D307011BE310BAA268F698AB9DBE4D8676F1BF6AC`.

**Operations**

- Add crash reporting with release/environment tags. The bounded local
  telemetry contract now attaches both tags to every event; connecting the
  optional sink to an external crash/analytics service remains an owner-
  controlled operations action.
- Instrument map load, auth, minigame, upload, sync, and rewards. The current
  local events now include privacy-safe `durationMs` for catch upload/sync,
  MapLibre style-ready/map-idle, and fishing minigame completion.
- Track frame time, startup, API latency, and upload failure rate. The bounded
  local telemetry contract now carries the timing fields; remote delivery is
  opt-in and the external crash sink remains owner-controlled.
- Add kill switches for map style, events, recognition, and unsafe spots.
- Add privacy, account deletion, support, and report flows.

Current progress: the protected live-smoke workflow now verifies Supabase URL
and project-ref identity before running provider, gameplay, account-upgrade,
or photo-storage checks. The identity verifier is anon-key-only and
fail-closed when credentials are absent or the endpoint is unreachable.

## 14. Workstream 10: Live Game Systems

Begin only after the vertical slice is stable:

1. Remote daily and seasonal events.
2. Funnel analytics from install through day-2/day-7 return.
3. Location integrity and rate limits.
4. Community spot/catch moderation.
5. Push notifications with deliberate permission timing.
6. Server-authoritative rewards and leaderboard writes.
7. Content tools for habitats, spawn weights, announcements, and spot suspension.

Current progress: the first remote-event slice is now stable-ID based. Admin
event creation writes the selected `fish_id` while retaining `fish_name` for
legacy rows, active boost loading exposes both keys, and GameHome resolves the
boost through the shared fish-ID/name matcher. Migration
`0018_remote_event_fish_identity.sql` and its source contracts are green
locally; applying it to the linked Supabase project remains an owner-controlled
content release gate. The analytics slice now adds opt-in batched telemetry,
server-side sensitive-field filtering, project-local actor hashing, a rate
limit, migration `0019_privacy_safe_analytics_events.sql`, and a dependent
hosted ingestion smoke. Location integrity is now implemented in migration
`0020_location_integrity_for_fishing_sessions.sql`: only the new six-argument
server RPC can create a session, it checks proximity and accuracy, rate-limits
starts, and refuses the legacy bypass signature. CatchLog refreshes GPS before
the server-backed minigame and never falls back to local rewards for an
authenticated configured session. The hosted migrations and live smoke remain
owner-controlled; retention/cohort reporting, server-authoritative event
configuration, and real-catch moderation are now implemented locally and are
waiting on those hosted gates. The first retention slice is now implemented in
migration
`0021_admin_retention_report.sql`: admin-only D2/D7 cohort aggregation is
available through a security-definer RPC and is rendered in the Admin screen
without exposing actor hashes or raw events. Local pgTAP, source, and analyzer
evidence is green. Server-authoritative event configuration is now added in
`0022_server_event_configuration.sql`: GameHome consumes an authenticated
projection that joins active boosts to active parent events, and the release
workflow smoke validates its response. Migration
`0023_real_catch_moderation.sql` now forces player-submitted real catches to
`pending`, keeps them out of the public leaderboard until admin approval, and
gives admins a bounded queue with short-lived photo URLs. Local shape,
behavior, source, analyzer, and history tests are green. The local
event-configuration smoke returned a valid empty projection, and the full
local proof now passes `462` Flutter tests plus `265` pgTAP assertions.
Migration `0024_fishing_spot_content_constraints.sql` now adds admin-only
habitat/species-weight editing with bounded slug/fish-ID validation in both
the Admin tool and the database. The content-tool source/history tests are
green, and the local database proof now passes `263` pgTAP assertions.
Migration `0025_analytics_map_idle_event.sql` additively extends the
privacy-safe analytics allowlist for the new map-idle timing event, preserving
the existing security-definer filter and rate limit. Local reset, 20 pgTAP
files, 265 assertions, schema lint, and source tests are green; hosted
application remains owner-controlled. The hosted analytics smoke now submits
both `app_bootstrap` and `map_idle(durationMs)` before reporting success.
Notification opt-in timing is now implemented as a platform boundary: the
Profile prompt appears only after the first catch, persists enabled/declined/
deferred choices per account, and requests `POST_NOTIFICATIONS` through a
native Android 13+ callback. Web and unsupported platforms remain unavailable
without showing a misleading prompt. A denied permission exposes a system-
settings recovery action and refreshes when the app resumes; provider token
registration and live push delivery are intentionally still separate work.
Hosted migrations remain an owner-controlled gate; the latest source is
available as a Vercel Preview, not a production alias.

Migration `0026_catch_photo_bucket_constraints.sql` additively tightens the
private `catch-photos` bucket to an 8 MiB still-image MIME allowlist. The
Flutter upload boundary rejects video and unknown explicit extensions before
reading a file, and failed catch-row inserts clean up a newly uploaded object
without hiding the original retry error. Focused client/source tests are
green, and `supabase/tests/catch_photo_bucket_shape_test.sql` adds the CI
pgTAP shape proof. The protected content-release workflow now also runs the
linked RLS behavior test plus the current read-only or rollback-safe shape
suites for analytics, retention, catch-photo storage, fishing-spot content and
moderation, reward tickets, gameplay sessions, real-catch moderation, wallet
operations, and event configuration after applying migrations. The workflow
source contract passes, but applying and linting the migration bundle and
producing hosted evidence in the linked project remain owner-controlled.

## 15. Extraction Order

Avoid a repository-wide rewrite. Extract one tested boundary at a time:

1. Security/config and recognition proxy.
2. Auth/startup.
3. Fishing-spot repository.
4. Map base and game overlay.
5. Minigame controller.
6. Catch and collection repositories.
7. Daily-task/reward controller.
8. Profile and leaderboard.

Commit each boundary independently.

## 16. Verification Matrix

| Area | Automated evidence | Manual evidence |
|---|---|---|
| Secrets | Artifact scan | Deployed `/assets/.env` absent |
| RLS | Two-user SQL tests | Supabase policy review |
| Auth | Controller/integration tests | Fresh install and account upgrade |
| Map | Golden/reference-coordinate tests | Sha Tin and Victoria Harbour comparison |
| Rotation | Bearing tests | Android and web gestures |
| Spots | Repository filtering tests | Coordinate/source audit |
| Performance | Bundle/frame budgets | Emulator profiling |
| Gameplay | Vertical-slice integration | Outdoor GPS beta |
| Release | Signed AAB in CI | Play internal-track install |
| Web | Post-deploy smoke | iPhone Safari and desktop Chrome |

## 17. Definition of Done

- Every P0 finding is closed with evidence.
- No client secret or permissive player-data policy remains.
- Login/guest choice precedes a skippable tutorial.
- Real map data supplies land, water, roads, buildings, and piers.
- Map and game objects rotate together and remain coordinate-correct.
- Only verified spots appear in production.
- Selected avatar is the player marker.
- Fishing, collection, real-photo, reward, and sync flow passes on API 35.
- Web and Android meet size/frame budgets.
- Android uses production signing and installs from Play internal testing.
- Web deployment, Android artifact, migration, and telemetry share a traceable release version.

## 18. Handoff Rules

1. Read this document and `git status` before editing.
2. Start with Workstream 0, not visual work.
3. Never print or commit environment secrets.
4. Use additive Supabase migrations.
5. Add a failing test before each behavior change.
6. Keep workstreams in focused commits.
7. Report commands, screenshots, acceptance evidence, and unresolved risk at every gate.
8. Test Android only on an emulator; exclude the API 23 photo-frame device.
9. Keep the old map until the new map passes two release candidates.
10. Request owner action for credential rotation, provider billing/licensing, OAuth console, or Play signing access.
