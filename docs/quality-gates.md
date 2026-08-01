# FisherGO Quality Gates

Last updated: 2026-08-01

## Current verification snapshot (2026-08-01)

- The production deployment captured by this quality snapshot is the clean
  `a11b22a` commit with
  release ID `0.1.1+2-a11b22a422a9`. Vercel deployment
  `https://fishergo-gdnj5rzy3-klyeung-s-projects.vercel.app` is `READY` and
  owns both `fisher-go.app` and `www.fisher-go.app`. The approved deployed-web
  verifier passed both roots, both `/release-manifest.json` responses, both
  `/assets/.env` rejection checks, and the effective cache policy on
  2026-08-01.

- The post-push production browser smoke reached both viewports with
  populated OpenFreeMap tiles and passing visual goldens. The exploratory
  motion readings were `53.95 FPS` / `33.4 ms` p95 / `5.58%` jank at 390x844
  and `41.07 FPS` / `66.6 ms` p95 / `18.54%` jank at 1440x900, so the
  desktop gate and the narrowly missed mobile gate remain open. Evidence:
  `tmp/web-map-benchmark-production-a11b22a-20260801.json`.

- The Windows-native production release path is available at
  `scripts/deploy.ps1` and fails closed before reading credentials unless
  `-PromoteProduction` is supplied. On this host, Windows Application Control
  blocked the local Flutter `impellerc.exe` invocation, so the same release
  inputs were sent through the verified remote Vercel build path. The earlier
  dirty-release evidence is retained here for diagnosis; the current clean
  production deployment is recorded above at
  `https://fishergo-pvlnkixhi-klyeung-s-projects.vercel.app` with release ID
  `0.1.1+2-8eabcee9251e-dirty-20260801175814`; both canonical aliases were
  promoted and the public manifest/bootstrap/secret-asset verifier passed.

- The production deploy scripts now pass the exact release ID, Git SHA, and
  public Supabase build values to Vercel's remote `vercel-build.sh` step. The
  dedicated `FISHERGO_DEPLOY_RELEASE_ID` channel takes precedence over a stale
  project-level release variable; the upload-side
  `.fishergo-deploy-release-id` provenance file is now the authoritative
  fallback and is cleaned up after deployment. The
  protected `.github/workflows/web-release.yml` manual workflow uses the
  `fishergo-web-release` environment and the same canonical alias verifier;
  it has been source-tested but not dispatched from this workspace.

- Production deployment now fails closed when `git status --porcelain` reports
  any worktree change. The Bash and PowerShell paths perform this check before
  importing `.env` or reading deployment credentials, so a release manifest
  cannot silently become a dirty, non-reproducible production artifact.
  Uncommitted work remains deployable only through the protected preview path.

- Vercel cache headers are now source-tested by asset class. HTML, Flutter
  bootstrap/manifests, the service worker, and the MapLibre tuning script use
  `no-cache, no-store, must-revalidate`; unversioned Flutter assets and
  CanvasKit use revalidation; only build-ID-query-busted `main.dart.js` is
  immutable. Favicon and launcher icons use a one-day cache with
  stale-while-revalidate, preventing stale map/runtime assets from surviving
  a release while retaining a small branding-cache benefit.

- Operations telemetry now records privacy-safe `durationMs` metrics for catch
  upload, catch sync, MapLibre style-ready/map-idle, and fishing minigame
  completion events. Unit and source contracts pass; remote analytics delivery
  remains opt-in and the external crash sink remains owner-controlled.

- `tool/verify_deployed_web.dart` now validates the effective `Cache-Control`
  headers on both canonical aliases for the root page, Flutter bootstrap,
  versioned `main.dart.js`, and release manifest. The successful fake-alias
  path and stale-header rejection are covered by
  `test/deployed_web_verifier_test.dart`; the current production deployment
  was rerun through this verifier on 2026-08-01.

- A preview-only Vercel deployment of the current source reached `READY` at
  `https://fishergo-64djpm3eo-klyeung-s-projects.vercel.app`
  (`dpl_7RJw2UBUWQo8goJge3d1KKuyuKUh`). Authenticated Vercel curl evidence
  showed the root, bootstrap, and release manifest using
  `no-cache, no-store, must-revalidate`, the build-ID versioned
  `main.dart.js` using `public, max-age=31536000, immutable`, the asset
  manifest using revalidation, and `/assets/.env` returning `NOT_FOUND`.
  The preview remains protected and is not a production alias.

- The production browser smoke now passes the fresh guest identity flow,
  tutorial skip, MapLibre canvas, OpenFreeMap tile response, and visual golden
  at both `390x844` and `1440x900`. The mobile trace measured `53.06 FPS`,
  `33.3 ms` p95, and `4.14%` jank; the desktop trace measured `38.33 FPS`,
  `66.7 ms` p95, and `20.94%` jank. The desktop motion budget therefore
  remains explicitly open even though visual/map correctness passed.

- The Web benchmark now retries Flutter semantics promotion while waiting for
  the guest action, preventing a cold-browser false failure. GameHome startup
  now serializes the initial auth callback, identity dialog, and tutorial
  dialog with an in-flight gate; API 35 fresh-install startup smoke and the
  production browser smoke both pass after the fix.

- A protected manual `.github/workflows/web-production-smoke.yml` now binds
  the release-manifest check to the browser smoke. It verifies both canonical
  aliases, runs the same Chromium guest/tutorial/MapLibre flow at mobile and
  desktop viewports, uploads the JSON and screenshots, and leaves the known
  desktop motion budget as an explicit opt-in enforcement gate.

- The first remote-event content slice now uses stable fish catalog IDs. Admin
  event writes persist `fish_id` while retaining the legacy `fish_name`, and
  GameHome resolves boosts by ID before falling back to the display name. The
  additive `0018_remote_event_fish_identity.sql` migration and source contract
  passed locally; hosted application remains an owner-controlled Supabase
  content-release action.

- The Workstream 10 analytics slice now has an opt-in Supabase transport. The
  client batches privacy-filtered telemetry behind
  `FISHERGO_ANALYTICS_ENABLED`, while migration
  `0019_privacy_safe_analytics_events.sql` stores only a project-local actor
  hash through an allowlisted security-definer RPC with server-side field
  filtering and a per-actor rate limit. Local reset, 183 pgTAP assertions,
  public-schema lint, Dart tests, analyzer, and the hosted-smoke source
  contract passed. Hosted application and live ingestion remain owner-gated.

- The hosted analytics smoke now submits both `app_bootstrap` and the additive
  `map_idle` event with a bounded `durationMs` field, so the release workflow
  exercises the same allowlist used by the client telemetry boundary.

- The location-integrity slice now uses migration
  `0020_location_integrity_for_fishing_sessions.sql`. The six-argument start
  RPC validates player latitude/longitude, GPS accuracy, spot proximity and a
  six-starts-per-minute limit; it stores only a verification flag, bounded
  distance and accuracy diagnostics. The legacy three-argument RPC has no
  execute privilege. CatchLog refreshes GPS before opening the server-backed
  minigame and refuses a local reward fallback when an authenticated Supabase
  session cannot obtain a verified server session.

- A Web native fishing-spot layer candidate was measured and rejected. It
  preserved the OpenFreeMap visual golden and click-query contract, but the
  matched desktop run moved from `38.33 FPS` / `20.94%` jank to `37.57 FPS` /
  `22.99%` jank. The default Flutter marker path is retained; the candidate
  was reverted after the run. Evidence:
  `tmp/web-map-benchmark-native-spots-default-20260801.json`.

- The local Workstream 10 bundle now reaches migration `0025`. Retention uses
  the admin-only aggregate RPC from `0021_admin_retention_report.sql`, while
  GameHome reads active event boosts through the parent-event-validated
  projection in `0022_server_event_configuration.sql`. The local event
  configuration smoke returned a valid empty list, and the full local proof
  passed with `462` Flutter tests and `265` pgTAP assertions, including the
  real-catch moderation and fishing-spot content source/history coverage. The linked
  project still ends at remote `0011`, so these changes remain owner-gated.

- The current source was deployed as a Vercel Preview and reached `READY` at
  `https://fishergo-jecl5jll2-klyeung-s-projects.vercel.app`. It is deliberately
  not aliased to `fisher-go.app` or `www.fisher-go.app`; no production
  promotion is claimed by this preview.

- The MapLibre `fill-pattern` material experiment was rejected after a matched
  API 35 warm comparison. The real OSM geometry remained correct and the v2
  grass tile looked materially better than the earlier mirrored candidate,
  but native p95 rose from `54 ms` / `34.85%` jank on the control to `62 ms` /
  `43.88%` with patterns; both miss the `20 ms` gate. The opt-in wiring,
  profile-only style, and generated v2 asset were removed, so the production
  map remains the stable vector-color style. Evidence:
  `tmp/android-native-map-benchmark-material-v2-control-warm-api35-20260801.json`,
  `tmp/android-native-map-benchmark-material-v2-patterns-warm-api35-20260801.json`,
  and `tmp/android-native-material-v2-patterns-api35-raw.png`.

- The native MapLibre layer-family attribution pass was completed on API 35
  `emulator-5554` with the Intel UHD 630 host renderer. The control measured
  p95 `58 ms` / `38.91%` jank; removing roads, water, waterway, or pier layers
  did not produce a stable improvement and would remove required map meaning.
  Removing only the water fill outline was also rejected after a repeat:
  control p95 was `62 ms` / `38.68%` jank versus `58 ms` / `46.82%` with the
  outline disabled. Both miss the `20 ms` native motion gate, so the full
  vector geography remains the production default. The profile-only activity
  and benchmark switches are retained for attribution diagnostics; they are
  not production settings. Evidence:
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

- The Android 3D fill-render candidate was rejected at the production-like
  GameHome boundary. The isolated native proof suggested an improvement when
  `fill-antialias=false` was applied to OSM `grass`, `wood`, `park`, and `water`
  fills (`58 ms` p95 / `35.71%` jank on the repeat), but the complete
  platform-view run measured `65 ms` p95 / `49.6%` jank, while the restored
  production-style rerun measured `81 ms` / `48.76%`; the candidate's Flutter
  total p95 was `137 ms` versus `116 ms` after restore. Both miss the `20 ms`
  gate and the direction is not stable enough to promote. The production Dart
  style and profile asset were restored; the profile-only switch remains for
  future attribution, and no geography was weakened. Evidence:
  `tmp/android-native-map-benchmark-fill-aa-control-api35-20260801.json`,
  `tmp/android-native-map-benchmark-fill-aa-disabled-api35-20260801.json`,
  `tmp/android-native-map-benchmark-fill-aa-control-repeat-api35-20260801.json`,
  `tmp/android-native-map-benchmark-fill-aa-disabled-repeat-api35-20260801.json`,
  `tmp/android-map-benchmark-fill-aa-production-api35-20260801.json`,
  `tmp/android-map-benchmark-fill-aa-production-control-restored-api35-20260801.json`,
  `tmp/android-map-benchmark-masterplan-baseline-20260801.json`,
  `tmp/android-native-map-fill-aa-control-binary.png`, and
  `tmp/android-native-map-fill-aa-disabled-binary.png`.

- The restored production source was rebuilt for both release targets after
  the rejection: Web package `89.6 MiB` and arm64 AAB `75.7 MiB`. The client
  secret scan and asset-budget check passed for the current outputs;
  `jarsigner` still reports the local AAB as unsigned. The AAB SHA256 is
  `BEF81EA3EF3B5DDB8D877A3D307011BE310BAA268F698AB9DBE4D8676F1BF6AC`.

- The Web building-footprint diagnostic was also rejected. Removing the
  OSM `building` fill layer kept the 1440x900 visual proof populated but left
  motion p95 at `66.6 ms` and jank at `17.62%`, versus `66.6 ms` / `17.92%`
  for the current style; the 390x844 candidate regressed p95 from `16.8 ms`
  to `33.3 ms`. The diagnostic query was removed, so Web keeps real building
  footprints while the wide-screen motion gate remains open. Evidence:
  `tmp/web-map-benchmark-current-20260801.json` and
  `tmp/web-map-benchmark-no-buildings-current-20260801.json`.

- The final Web rebuild after removing the diagnostic passed both structural
  visual goldens and OpenFreeMap tile checks. The stable run measured
  `55.52 FPS` / p95 `33.3 ms` / `2.89%` jank at 390x844 and `42.13 FPS` /
  p95 `66.6 ms` / `18.1%` jank at 1440x900. The wide-screen motion gate is
  still open; the remaining tail is MapLibre/WebGL rendering work rather than
  missing map geometry. Evidence:
  `tmp/web-map-benchmark-final-current-20260801.json` and
  `test/goldens/game_map/manifest.json`.

- A Web all-fill-outline diagnostic was measured against the current source.
  The 390x844 and 1440x900 visual goldens stayed populated, but the matched
  desktop run remained at `66.6 ms` p95 (`40.48 FPS`, `18.81%` jank) versus
  the current control's `66.6 ms` p95 (`40.68 FPS`, `20.69%` jank). It did not
  close the p95 gate and is not promoted; the query-gated diagnostic was
  removed after the comparison. Evidence:
  `tmp/web-map-benchmark-masterplan-baseline-current-20260801.json` and
  `tmp/web-map-benchmark-masterplan-no-fill-outlines-20260801.json`.

- The API 35 CI smoke workflow now uses `set -euo pipefail` and has a source
  contract covering all 12 integration flows, the fixed API 35 emulator,
  GPS-centered spot coordinates, offline network toggle, and permission
  profiles. The new contract and the full `418`-test suite passed locally;
  YAML parsing and diff hygiene also passed. This hardens failure reporting;
  it does not claim the still-open Android motion budget.

- On 2026-08-01, the API 35 startup/auth smoke was rerun after replacing
  fixed-duration `pumpAndSettle` calls with bounded state waits. The flow now
  waits for the identity dialog, tutorial, GameHome, bearing update, and the
  asynchronously loaded encyclopedia filter before asserting each state. The
  clean run passed in `22` seconds on `emulator-5554`, covering identity,
  guest entry, tutorial skip, GameHome, `0°` to `45°` rotation, encyclopedia
  filters, and undiscovered fish cards. The preflight explicitly skipped API
  23 serial `0123456789ABCDEF`; this closes the startup test-sequencing gate,
  not the separate Android motion-budget or hosted Supabase gates. Evidence:
  `integration_test/startup_auth_flow_test.dart`,
  `test/startup_auth_flow_source_test.dart`, and
  `tool/run_android_integration_smoke.ps1`.

- On 2026-08-01, the Android motion rebaseline separated diagnostic overhead
  from the renderer. After restarting the API 35 host-GPU AVD, matched profile
  runs with map-performance telemetry on/off measured native p95 `57/61 ms`
  respectively; the difference is not a stable gain, so no telemetry or
  production renderer change was made. A one-widget `top-status` HUD removal
  then measured p95 `89 ms` and a warm repeat `93 ms`, versus the same-day
  full-HUD control `57 ms`; it is rejected. These traces keep real OSM water,
  land, roads, buildings, piers, and interactive location flow intact.
  Evidence:
  `tmp/android-map-benchmark-masterplan-current-perf-on-repeat-20260801.json`,
  `tmp/android-map-benchmark-masterplan-current-no-perf-20260801.json`,
  `tmp/android-map-benchmark-masterplan-top-status-hidden-20260801.json`, and
  `tmp/android-map-benchmark-masterplan-top-status-hidden-warm-20260801.json`.

- The protected Android release workflow now writes a Web companion
  `release-manifest.json` with the same release inputs and verifies
  `release_id`, `app_version`, and `git_sha` against the Android manifest before
  scanning or uploading artifacts. Both manifests are retained in the signed
  release artifact for later evidence review. Matching and deliberate-mismatch
  tests pass in `test/release_manifest_verifier_test.dart`; signing remains
  owner-controlled.

- `flutter test --no-pub`: **422 tests passed**, including the bite-first
  controller, GameHome delegation contract, map/spot/collection coverage, and
  security source checks. The new telemetry contract covers sensitive-field
  removal, bounded local buffering, sink failure isolation, and critical
  operation boundaries. The release kill-switch contract covers events, fish
  recognition, and public fishing spots.
- On 2026-08-01, encyclopedia cards made the discovery state explicit in both
  the visible card footer and a single deterministic accessibility label:
  unknown/encountered fish keep the name hidden and use the locked silhouette,
  game catches show the full-color icon, and verified real catches retain the
  photo-proof fish-hook badge. Focused asset/copy tests, the 411px widget layout
  test, the full 415-test suite, and `flutter analyze` passed. The startup
  telemetry installer now uses `??=` so it does not replace Flutter's existing
  integration/crash handler. A fresh API 35 startup smoke then passed identity,
  tutorial skip, GameHome, 0°→45° rotation, and the visible `未發現` card state;
  the runner explicitly skipped API 23 serial `0123456789ABCDEF`.
- On 2026-08-01, MapLibre camera move events began feeding the normalized native
  or Web bearing back to the GameHome direction HUD through a lightweight
  `ValueNotifier`; camera gestures no longer leave the displayed direction
  stale or rebuild the map surface on every frame. Focused map tests, the full
  `418`-test suite, analyzer, and `map_rotation_flow_test.dart` passed on API 35
  `emulator-5554`; the API 23 photo-frame serial was skipped. The verified
  source is available at
  `https://fishergo-3rseg561n-klyeung-s-projects.vercel.app`; this is a Vercel
  preview only and no production alias was promoted.
- On 2026-08-01, both bite-first minigame surfaces gained live-region status
  announcements and deterministic action labels for waiting, bite-ready, and
  resolved states without changing the bite timing, haptics, or strike rules.
  The focused minigame tests, full **415-test** suite, analyzer, and clean API
  35 `fishing_minigame_flow_test.dart` passed on `emulator-5554`; the API 23
  photo-frame serial `0123456789ABCDEF` was explicitly skipped. The verified
  Web preview is
  `https://fishergo-jbwwg396k-klyeung-s-projects.vercel.app` (deployment
  `dpl_GTbg66zwixom2517gdDEsuV9EDM9`, `READY`); no production alias was
  promoted.
- On 2026-08-01, `GameMapLibre` moved its circular `0.25°` bearing threshold
  to the native/Web event bridge, so small camera noise no longer crosses into
  the parent HUD callback. The full 415-test suite, analyzer, API 35 rotation
  flow, and the GPS-centered Tsing Yi spot-selection flow passed on
  `emulator-5554`; the latter used `22.354208,114.109537`, while the API 23
  photo-frame serial remained excluded. A matched Web run kept the map visual
  golden populated but measured 1440x900 p95 `66.7 ms` and jank `17.79%`, so
  the Web/Android motion gates remain open. Evidence:
  `tmp/web-map-benchmark-masterplan-bearing-throttle-20260801.json`,
  `integration_test/map_rotation_flow_test.dart`, and
  `integration_test/map_spot_selection_flow_test.dart`.
- The marker-motion simplification, marker-off attribution, and Web pixel-ratio
  `0.625` experiments were rejected: none improved the wide-screen motion gate
  without an unacceptable or unstable trade-off. The retained Web preset stays
  at adaptive pixel ratio `0.75` with the existing geographic style.
- An Android cache-lifecycle candidate was also rejected. Deferring
  `MapCachePolicy.configureOnce()` until after the first frame improved cold
  readiness from `3441 ms` to `1899 ms` and warm readiness to `1384 ms`, but
  native motion p95 measured `48 ms` on the clean run and `61 ms` on the warm
  repeat, versus the `44 ms` control; jank stayed near `49.5%`. The source was
  restored to configure the bounded cache policy during map initialization.
 Evidence: `tmp/android-map-benchmark-masterplan-cache-deferred-20260801.json`
 and `tmp/android-map-benchmark-masterplan-cache-deferred-warm-repeat-20260801.json`.
- A Flutter marker-composition candidate was also rejected. Moving the marker
  layer outside `MapLibreMap.children` reduced cold style/idle readiness to
  `1514/1568 ms`, but the per-camera `toScreenLocations` projection path raised
  native motion p95 to `61 ms` and the warm repeat to `69 ms`; jank remained
  about `49%`. The original MapLibre child composition was restored and the
  API 35 rotation and GPS-centered spot-selection flows still passed. Evidence:
  `tmp/android-map-benchmark-masterplan-marker-overlay-boundary-20260801.json`
  and
  `tmp/android-map-benchmark-masterplan-marker-overlay-boundary-warm-repeat-20260801.json`.
- A pure Dart Web-Mercator marker projection candidate was rejected after
  matched Android and Web measurement. On Android, the clean run measured
  p95 `61 ms` (warm `57 ms`) and the coalesced-frame variant measured `53 ms`
  (warm `61 ms`), all worse than the `44 ms` control; jank stayed around
  `48-50%`. On Web, the populated visual golden passed, but 1440x900 motion
  measured p95 `66.6 ms` with jank `26.23%`, worse than the `17.79%` control.
  The candidate was removed from the production path; the existing MapLibre
  camera projection remains in use while the next investigation moves into
  the native/plugin camera pipeline. Evidence:
  `tmp/android-map-benchmark-masterplan-pure-marker-projection-20260801.json`,
  `tmp/android-map-benchmark-masterplan-pure-marker-projection-warm-repeat-20260801.json`,
  `tmp/android-map-benchmark-masterplan-pure-marker-projection-coalesced-20260801.json`,
  `tmp/android-map-benchmark-masterplan-pure-marker-projection-coalesced-warm-repeat-20260801.json`,
  and `tmp/web-map-benchmark-masterplan-pure-marker-projection-20260801.json`.
- A local `maplibre_android 0.3.5` camera-boundary fork was also rejected. The
  candidate gated the plugin's per-camera Flutter `setState` on a non-empty
  `MapLibreMap.children` tree, moved gameplay markers to native layers, and
  kept attribution/compass outside the platform view. The clean API 35
  host-GPU run measured gfx p95 `53 ms`, jank `50%`, and readiness
  `4381/4536 ms`; the warm repeat measured p95 `61 ms`, jank `49.1%`, and
  readiness `1240/1518 ms`, versus the retained p95 `44 ms` control. Flutter
  total p95 was `100/96 ms`, so the fork did not produce a stable motion win.
  The dependency override, fork, and opt-in flag were removed; hosted
  MapLibre `0.3.5` and the original Flutter marker path remain the default.
  Evidence:
  `tmp/android-map-benchmark-masterplan-native-camera-pipeline-20260801.json`
  and
  `tmp/android-map-benchmark-masterplan-native-camera-pipeline-warm-repeat-20260801.json`.
- A native-only landcover isolation experiment was measured on API 35
  `emulator-5554` with the Intel UHD 630 host renderer. The clean full-style
  control measured `78 ms` p95, `56.65%` jank, and `250 ms` p99; removing all
  `grass`, `wood`, and `park` layers measured `46 ms` p95, `23.12%` jank, and
  `300 ms` p99. The warm control was `54/350 ms` p95/p99 with `35.86%` jank,
  while the all-landcover-disabled warm repeat was `48/300 ms` with `26.05%`
  jank. Single-layer clean diagnostics were no-grass `62/350 ms`, no-wood
  `54/350 ms`, and no-park `54/300 ms` p95/p99; none proved a stable win over
  the warm control, and the all-disabled result removes the game map's land
  texture. Keep the default landcover style unchanged; retain only the
  profile-only `-DisableLandcover` isolation switch for future diagnostics.
  Evidence:
  `tmp/android-native-map-benchmark-landcover-control-api35-20260801.json`,
  `tmp/android-native-map-benchmark-landcover-disabled-api35-20260801.json`,
  `tmp/android-native-map-benchmark-landcover-control-warm-api35-20260801.json`,
  `tmp/android-native-map-benchmark-landcover-disabled-warm-api35-20260801.json`,
  `tmp/android-native-map-benchmark-landcover-no-grass-api35-20260801.json`,
  `tmp/android-native-map-benchmark-landcover-no-wood-api35-20260801.json`, and
  `tmp/android-native-map-benchmark-landcover-no-park-api35-20260801.json`.
- `flutter analyze --no-pub`: **passed with no diagnostics**; `git diff --check`
  also passed.
- On 2026-08-01, the final source rebuilt a Web release with
  `FISHERGO_MAPLIBRE=true` and a local release ID. The client artifact secret
  scan passed and the Web asset budget passed; the generated Web package was
  `89.6 MiB`. The latest Vercel preview completed its remote Flutter build,
  release-manifest write, and client artifact scan, and is `READY` at
  `https://fishergo-26ejscz0a-klyeung-s-projects.vercel.app` (deployment
  `dpl_2H1kpYLFTMZXQ4nduqt3bTzN5ypG`). It remains a protected preview rather
  than a public-alias pass; no production alias promotion was performed.
- The Vercel build boundary now fails closed for production when either public
  Supabase build value is absent, while retaining the no-Supabase preview/local
  diagnostic path. The source contract and shell syntax checks pass in
  `test/deploy_script_source_test.dart` and `scripts/vercel-build.sh`.
- On 2026-08-01, the current source also built an arm64 Android release AAB at
  `75.7 MiB`. The client secret scan and asset budget passed. `jarsigner`
  correctly reported the local artifact as unsigned, so this is a build and
  packaging proof only; protected keystore signing and Play internal-track
  installation remain open release gates.
- On 2026-08-01, the full-map/panorama modal was migrated from the legacy
  raster `FlutterMap` surface to the same `GameMapLibre` vector renderer used
  by GameHome. This makes GPS centering, camera gestures, rotation, OSM water,
  roads, buildings, avatar projection, and fishing-spot callbacks share one
  production path. The new `panorama_map_flow_test.dart` passed on API 35
  `emulator-5554` after a clean install, including open, MapLibre mount, and
  close. Preflight explicitly skipped API 23 serial `0123456789ABCDEF`.
  The no-MapLibre widget-test fallback remains behind the existing feature flag;
  it is not a production map path.
- On 2026-08-01, fresh-install API 35 map correctness checks passed on
  `emulator-5554`: `map_rotation_flow_test.dart` verified the bearing control,
  `map_spot_selection_flow_test.dart` used GPS `22.354208013,114.109537072`
  and selected the verified spot after rotation, and
  `panorama_map_flow_test.dart` opened and closed the production MapLibre
  panorama surface. Each run reported `ANDROID_SMOKE_API=35` and explicitly
  skipped API 23 serial `0123456789ABCDEF`. These are correctness proofs only;
  the separate Android motion p95 gate remains open.
- On 2026-08-01, the real API 35 network-toggle smoke passed on
  `emulator-5554`: the runner skipped API 23 serial `0123456789ABCDEF`,
  disabled airplane mode/Wi-Fi/data before the Flutter app attached, kept a
  seeded catch queue at `待備份：1 筆`, restored Wi-Fi after the production
  `Connectivity` listener was ready, and verified automatic replay to
  `待備份：0 筆`. The runner reported `ANDROID_SMOKE_NETWORK_ON=PASS` and
  `ANDROID_SMOKE_NETWORK_RESTORED`. API 35 can report `mobile` rather than
  `none` while its radios are disabled, so this proof asserts the real
  post-restore Wi-Fi edge and queue replay instead of requiring a particular
  pre-restore transport label. Evidence: `integration_test/offline_network_toggle_flow_test.dart`
  and `tool/run_android_integration_smoke.ps1`.
- On 2026-08-01, the additive fishing-spot habitat migration was applied to a
  clean local Supabase stack. P017/P018 carry Tung Chung runway bream weights,
  P045/P046/P047/P050 carry Sam Mun Tsai/Tai Po inner-water mullet weights,
  P051-P054 carry Tsing Ma grouper/catfish weights, and P035/P036/P043 carry
  East Water pond-fish/red-bream/chicken-fish weights. The bundled offline
  registry carries the same stable fish IDs. Local `supabase test db --local`
  passed 163 assertions and `supabase db lint --local --schema public
  --fail-on error` found no schema errors. Applying `0017` to the linked
  production project remains an owner-controlled content release action.
- On 2026-08-01, the protected Supabase content-release path gained a hosted
  habitat verifier. After the dependent smoke job starts, it checks the target
  project ref and reads only active, verified, public rows through PostgREST
  with the anon key, then validates representative habitat tags and stable fish
  IDs for P017, P035, P045, and P051. Missing credentials exit `2`; hosted data
  drift or a project mismatch exits non-zero. Local execution skipped as
  expected because hosted secrets are not present. Evidence:
  `tool/verify_supabase_fishing_spot_habitat.dart`,
  `test/supabase_fishing_spot_habitat_verifier_source_test.dart`, and
  `.github/workflows/supabase-content-release.yml`. The linked project was not
  changed in this workspace.
- On 2026-08-01, a fresh-install API 35 host-GPU MapLibre benchmark reran on
  `emulator-5554` with the API 23 serial excluded by preflight. It produced
  `311` valid native frames, gfx p95/p99 `44/57 ms`, `47.59%` janky frames,
  Flutter total p95 `73 ms`, and no ANR. This confirms the Android 20 ms motion
  gate remains open; evidence is
  `tmp/android-map-benchmark-masterplan-baseline-20260801.json`.
- The Android tall-building density candidate was rejected on 2026-08-01.
  Its OSM height filter preserved the 3D layer but measured gfx p95 `48 ms`
  versus the matched complete-building baseline `44 ms`, with slow draw
  commands `96` versus `83` and bitmap uploads `22` versus `13`. Readiness
  improved, but motion did not; the flag and transformer were removed.
  Evidence: `tmp/android-map-benchmark-building-density-tall-20260801.json`.
- On 2026-08-01, the standalone protected Supabase live-smoke workflow gained
  a first-step project identity gate. It requires the URL, anon key, and
  project ref, rejects non-HTTPS or mismatched Supabase hosts, and confirms the
  public Auth settings endpoint is reachable before provider, gameplay,
  account-upgrade, or photo checks run. Missing credentials exit `2`; no
  service-role value is accepted or printed. Evidence:
  `tool/verify_supabase_project_identity.dart`,
  `test/supabase_project_identity_source_test.dart`, and
  `test/supabase_live_smoke_workflow_source_test.dart`.
- The production `scripts/deploy.sh` path now fails closed before calling
  Vercel when `VERCEL_TOKEN`, `SUPABASE_URL`, or `SUPABASE_ANON_KEY` is absent,
  and rejects any alias pair other than `fisher-go.app` plus
  `www.fisher-go.app`. The source contract is covered by
  `test/deploy_script_source_test.dart`; no deployment was performed by this
  change.
- On 2026-08-01, the Web map benchmark was made deterministic by granting
  Playwright a fixed Sha Tin geolocation (`22.3819, 114.1874`, 15 m accuracy)
  in each isolated viewport context. The current Web release then produced a
  populated OSM proof at both viewports: `56.68 FPS`, p95 `33.3 ms`, and
  `0.71%` jank at 390x844; `42.88 FPS`, p95 `50.0 ms`, and `17.29%` jank at
  1440x900. The mobile trace is within the exploratory motion budget, while
  the desktop p95/jank gate remains open. Evidence:
  `tmp/web-map-benchmark-current-20260801-geolocation.json` and
  `test/web_map_benchmark_runner_source_test.dart`.
- On 2026-08-01, the marker projection cache was verified on the current
  source: the full `407`-test suite and Web release/secret scan passed, the
  Web map proof stayed populated at both viewports, and API 35 rotation plus
  GPS-centered spot selection both passed after a clean install. The Android
  repeat still reports an open native motion gate (`44/40 ms` p95 across two
  runs, `65/53 ms` p99, and `46.44%/47.11%` jank), so the cache is retained as
  a low-risk allocation reduction rather than a performance-gate fix.
- Release provenance is now carried by every structured telemetry event as
  `releaseId`, using the same `FISHERGO_RELEASE_ID` passed to Web and protected
  Android builds and written to `release-manifest.json`. Events also carry an
  `environment` tag: explicit `FISHERGO_ENVIRONMENT` wins, otherwise release
  builds default to `production` and debug/profile builds to `development`.
  Focused source tests, the full `409`-test suite, Web release build, and
  client secret scan passed; the local manifest proof used
  `local-accepted-20260801`.
- On 2026-08-01, the clean default Web release was rebuilt without temporary
  motion-experiment defines and rerun through the isolated geolocation
  benchmark. The populated OSM proof measured `57.41 FPS`, p95 `16.8 ms`, and
  `2.79%` jank at 390x844; 1440x900 measured `41.52 FPS`, p95 `66.6 ms`, and
  `18.36%` jank with 31 bounded long tasks totaling `1,692 ms`. Mobile remains
  within the exploratory budget; the desktop motion gate remains open. Evidence:
  `tmp/web-map-benchmark-final-default-20260801.json`,
  `output/playwright/web-map-proof-390x844.png`, and
  `output/playwright/web-map-proof-1440x900.png`.
- A global Flutter/platform error boundary now records privacy-safe `app_error`
  events in the existing bounded telemetry buffer. Framework errors include
  only `source`, `fatal`, and the Flutter library; async platform errors include
  only `source`, `fatal`, and the error type. Exception messages and stack traces
  are intentionally excluded. The release ID is attached by the same telemetry
  path. Unit and source contracts pass; connecting this buffer to an external
  crash sink remains an owner-controlled operations task.
- The accepted source was deployed to a Vercel Preview and reached `READY`:
  `https://fishergo-57vee2ch7-klyeung-s-projects.vercel.app` (deployment
  `dpl_2ftbrMrcv2t1uqB4i1zRtC7Vurpb`). The custom production aliases were not
  promoted; production release remains an owner-controlled action.
- The deployed-web verifier now accepts `--release-id` and fails when either
  public alias serves a different manifest. The current production aliases
  both passed the new exact-release check for `0.1.1+2-8eabcee9251e`; both
  roots returned `200` and both `/assets/.env` paths returned `404`.
- A controlled API 35 host-GPU experiment moved both the player avatar and
  fishing spots into MapLibre native layers. It preserved map readiness and
  correctness but measured gfx p95 `53 ms`, p99 `69 ms`, and `44.72%` jank,
  versus the retained Flutter-marker path; it remains opt-in diagnostic only.
  Evidence: `tmp/android-map-benchmark-native-all-marker-api35-20260801.json`.
- A Web opt-in native-player candidate preserved the selected avatar and a
  populated map, but the 1440x900 trace remained `43.14 FPS`, p95 `50 ms`,
  and `18.14%` jank versus the retained `43.28 FPS`, `50 ms`, and `17.97%`.
  It was rejected, and Web keeps the Flutter avatar overlay. Evidence:
  `tmp/web-map-benchmark-native-player-20260801.json`.
- Profile now contains owner-configured privacy, support, and prefilled problem
  report actions. Empty build-time values keep the panel hidden; the final
  public URL and mailbox remain owner/legal release actions.
- On 2026-07-30, the complete local regression reran after the Web motion
  style became the default, the encyclopedia lazy-media contract was added,
  the public fishing-spot filter was tightened, and the location-access
  boundary was added, CatchLog permission timing was tightened, and the
  account-deletion source boundary was added: 359 tests
  passed,
  `flutter analyze --no-pub` passed, Dart formatting reported no changes,
  JavaScript syntax checks passed, and the client artifact secret scan passed
  against `build/web`. This closes the source/build regression check for the
  current slice; it does not close the Android or Web motion-performance gates.
- The Supabase Auth provider verifier now checks the public
  `/auth/v1/settings` endpoint before live upgrade/photo smoke. Against the
  configured project it passed `google_enabled=true` and
  `anonymous_enabled=true`; the verifier emits only booleans and never reads
  service-role or OAuth client secrets.
- The anonymous private catch-photo smoke was rerun on 2026-07-30 with the
  bounded REST runner and passed upload, signed read-back, object cleanup, and
  sign-out. The account-upgrade smoke remains intentionally protected behind
  disposable email/password credentials.
- The public fishing-spot repository now requires `active`, `verified`, and
  `public_access=true` on both remote and bundled paths. A configured remote
  registry remains authoritative, so an empty or failed remote response still
  produces zero map spots instead of reviving stale fixture coordinates.
  Coverage: `test/fishing_spot_repository_test.dart` and
  `test/fishing_spot_registry_test.dart`.
- The 2026-07-30 release artifact budget check also passed: Web package
  `89.5 MiB` and arm64 release AAB `75.4 MiB`. The AAB now packages only the
  mobile WebP fish set, silhouettes, and the locked silhouette; generated and
  backup icon sources are excluded from both Flutter assets and Vercel input.
  The Web figure is the complete package size, not the much smaller first-use
  transfer measured by the bootstrap capture.
- After the asset manifest change, the API 35 emulator smoke was rerun on
  `emulator-5554`; the complete Android vertical slice passed:
  `startup_auth_flow_test.dart`, `fishing_minigame_flow_test.dart`,
  `daily_task_reward_flow_test.dart`, and `offline_reconnect_flow_test.dart`.
  The API 23 photo-frame serial `0123456789ABCDEF` was explicitly skipped by
  preflight. The run was repeated after restarting the API 35 host-GPU AVD
  with constrained emulator memory because an earlier host-memory-starved
  attempt timed out before the test process attached; that attempt is not
  treated as product evidence.
- The Android location boundary is now explicit and unit-tested: a disabled
  location service, a denied permission, and a permanently denied permission
  each produce a distinct state without blocking the GPS-free map fallback.
  The API 35 startup smoke was rerun after this change and passed the
  login-first, tutorial-skip, GameHome, rotation, and encyclopedia flow;
  preflight again skipped the API 23 photo-frame serial.
- CatchLog no longer requests location when the fish-log screen opens. Location
  access is deferred to the explicit `定位` action, and Android 14's selected
  photo permission is declared for limited gallery access. The updated API 35
  startup smoke passed after rebuilding the Android debug APK; permission
  grants remained deferred in the clean-install runner, while the app stayed
  on the login-first path without a startup prompt.
- On 2026-07-31, the Android permission surface was narrowed to the shipped
  CatchLog behavior: it uses `ImageSource.gallery` only, so CAMERA was removed
  from the manifest and from smoke/benchmark grant lists. The rebuilt APK
  declares location, gallery, and selected-photo permissions only; an API 35
  clean-install startup smoke passed on `emulator-5554`, while preflight
  explicitly skipped the API 23 photo-frame serial.
- On 2026-07-31, a fresh API 35 startup smoke ran on `emulator-5554` after
  starting the `FisherGO_API35` AVD. Login-first, tutorial skip, GameHome, and
  teardown passed. The API 23 photo-frame serial `0123456789ABCDEF` was
  explicitly skipped; clean-install runtime grants were deferred by the
  runner and the app still showed no startup permission prompt.
- On 2026-07-31, the remaining fresh API 35 vertical-slice flows also passed
  on `emulator-5554`: bite-first fishing, daily-task reward claim persistence,
  and offline catch-queue reconnect. These runs also explicitly skipped the
  API 23 photo-frame. Flutter emitted a non-blocking `maplibre_android`
  Kotlin Gradle Plugin compatibility warning; the app build and tests passed,
  but the plugin upgrade remains a dependency follow-up before a future
  Flutter toolchain makes that warning fatal.
- On 2026-08-01, the dependency state was rechecked against pub.dev. The
  `maplibre` and `maplibre_android` packages remain on stable `0.3.5`, with no
  newer official package release available to remove the warning. The current
  plugin still applies `kotlin-android` from its own Gradle build; this is
  recorded as a dependency-owner follow-up, not patched in the FisherGO app.
- On 2026-08-01, the API 35 map-rotation integration flow passed on
  `emulator-5554`: after guest entry and tutorial skip, the GameHome control
  advanced the accessible bearing state from `0°` to `45°` to `90°`. The
  preflight explicitly skipped API 23, and the existing MapLibre KGP warning
  remained non-blocking. Evidence: `integration_test/map_rotation_flow_test.dart`.
- On 2026-08-01, the API 35 GPS-centered fishing-spot flow passed on
  `emulator-5554` with `emu geo fix 114.109537072 22.354208013`: the app waited
  for the live fix after the identity/tutorial gates, rendered the verified
  `青衣公眾碼頭` marker, rotated to `45°`, and opened the spot detail card after
  tapping the marker. API 23 was explicitly skipped. The MapLibre GPS camera
  update now uses a cancellation-safe immediate move, preventing a location
  recenter from racing the bearing animation. Evidence:
  `integration_test/map_spot_selection_flow_test.dart`.
- After the marker-motion notifier change, both map integration flows were
  rerun on API 35 `emulator-5554`: `map_rotation_flow_test.dart` and
  `map_spot_selection_flow_test.dart` passed with clean app-data resets. The
  spot flow again used the GPS-centered 青衣 coordinate and selected the
  verified marker after rotation; the API 23 photo-frame was skipped by
  preflight. This refreshes the rotation/tap evidence for the current
  renderer, not the earlier build.
- The latest current-source rerun repeated all four integration flows on
  `emulator-5554`: startup/auth, bite-first minigame, daily-task claim, and
  offline reconnect all passed after each debug APK install. The runner again
  skipped API 23; on the clean installs after the first flow, runtime grants
  were deferred because the package was not installed when preflight ran, and
  the flows that do not require location/photo access remained green. This is
  gameplay evidence, not a substitute for the separate denied/limited
  permission device matrix.
- The Android smoke runner now installs the debug APK before clearing app data
  and granting runtime permissions, so clean-install permission evidence is no
  longer attempted against an absent package. The corrected API 35 startup
  rerun reported `ANDROID_SMOKE_APP_DATA=CLEARED` and
  `ANDROID_SMOKE_PERMISSIONS=GRANTED` on `emulator-5554`; API 23 was skipped
  by the same preflight. This closes the runner sequencing defect, while the
  denied/limited permission matrix remains a separate manual gate.
- A dedicated API 35 `deny-location` profile now revokes fine/coarse location,
  marks both permissions `user-fixed`, and runs
  `location_permission_denied_flow_test.dart`. On `emulator-5554`, the app
  showed `定位權限已永久拒絕，請到系統設定重新開啟。` while keeping the
  GPS-free map and `全景地圖` usable; API 23 was skipped. Limited-photo and
  location-service-disabled profiles remain separate follow-up cases.
- The API 35 `location-disabled` profile also passed with
  `location_service_disabled_flow_test.dart`: the app showed
  `請先開啟手機定位服務。` without blocking the GPS-free map, and the runner
  reported `ANDROID_SMOKE_LOCATION_RESTORED=emulator-5554` in cleanup. The
  three tested runtime states are now grant, user-fixed denied, and service
  disabled; the selected-photo profile is covered separately below.
- The API 35 `limited-photo` profile now revokes
  `READ_MEDIA_IMAGES`, grants `READ_MEDIA_VISUAL_USER_SELECTED`, and passed
  `limited_photo_permission_flow_test.dart` on `emulator-5554` after a clean
  app-data reset. The FisherGO catch-log and `選擇相片` entry remained usable;
  API 23 was skipped. Selecting an actual item in the Android system Picker is
  still a manual release check.
- On 2026-08-01, the three permission profiles were rerun from clean API 35
  installs on `emulator-5554`: user-fixed denied location, disabled location
  service, and selected-photo access all passed, with API 23 explicitly skipped.
  The runner restored the emulator location service after the disabled-service
  run. A new `app_resume_flow_test.dart` also paused and resumed GameHome after
  a 45-degree rotation, then verified the map remained visible and advanced to
  90 degrees after resume. These four checks are now included in the final API
  35 CI matrix; actual Android Picker item selection remains a manual check.
- Real-catch feedback now distinguishes local proof persistence from wallet
  confirmation: the catch and photo remain in the local queue, but the UI only
  displays `+20 金幣` when the wallet service returns a valid balance. A failed
  server claim reports that the reward is waiting for confirmation instead of
  promising coins that were not credited. The regression is covered by
  `test/real_catch_reward_feedback_source_test.dart`.
- After the real-catch feedback change, the API 35 `limited-photo` smoke was
  rerun on `emulator-5554` with a clean app-data reset and passed again;
  `limited_photo_permission_flow_test.dart` kept the catch-photo entry usable.
  The API 23 photo-frame remained excluded by preflight.
- A fresh current-source API 35 host-GPU profile benchmark on
  `emulator-5554` observed MapLibre p95/p99 `30/32 ms`, `23.29%` janky frames,
  58 slow draw commands, and no ANR after one warm-up round. Map readiness was
  observed at `1.864/1.903 s`; Gate 2 remains open because the 20 ms motion
  target is not met. Evidence: `tmp/android-map-benchmark-restarted-api35.json`.
- On 2026-07-31, a second current-source API 35 host-GPU profile benchmark
  completed on the same `emulator-5554` after one warm-up round. It captured
  656 frames with p95/p99 `30/32 ms`, `21.04%` janky frames, 80 slow draw
  commands, and no ANR; map readiness/style-idle was `427/437 ms`. The repeat
  confirms that the map is valid and interactive, but the 20 ms motion target
  remains open. Evidence:
  `tmp/android-map-benchmark-current-api35-20260801.json`.
- On 2026-08-01, the map painter removed its per-cell terrain-grid rescans by
  precomputing grid dimensions once per painter. The Android benchmark runner
  was also aligned with the product's explicit location flow: it now taps
  `重新定位` before measuring the GPS-centered map. The readiness-gated API 35
  repeat captured 512 native frames at p95/p99 `34/46 ms`, `40.82%` janky,
  Flutter total p95 `45 ms`, and no ANR. This is a valid measurement and a
  safe structural improvement, but it does not close the 20 ms motion gate.
  Evidence: `tmp/android-map-benchmark-grid-cache-api35-perf-20260801.json`.
- On 2026-08-01, the Android marker motion path began reducing Flutter marker
  work only while the camera is moving: spot labels are hidden in a fixed-size
  marker box and marker animation is paused, then restored at camera idle. The
  API 35 host-GPU candidate measured p95/p99 `44/61 ms`, `46.93%` janky, and
  no ANR; a same-session disabled control measured `57/73 ms`, `47.29%`
  janky. This is a partial, variance-sensitive improvement and does not close
  the 20 ms motion gate. The benchmark harness was also corrected to accept
  the same location control when its live GPS label is `GPS <accuracy>m`.
  Evidence:
  `tmp/android-map-benchmark-marker-motion-optimization-retry-api35-20260801.json`,
  `tmp/android-map-benchmark-marker-motion-disabled-control-api35-20260801.json`,
  and `tool/android_map_benchmark.ps1`.
- The marker-motion implementation was then changed to a notifier-only update:
  `ValueListenableBuilder` rebuilds the marker overlay without calling
  `setState` on the parent `GameMapLibre` platform-view host. The fresh API 35
  trace measured gfx p95/p99 `46/61 ms`, Flutter total p95 `63 ms`, and no ANR.
  It is a structural improvement over the earlier setState candidate's
  Flutter p95 `77 ms`, but the native 20 ms motion gate remains open.
  Evidence: `tmp/android-map-benchmark-marker-motion-notifier-api35-20260801.json`.
- The marker layer now caches its stable geographic point list and only
  rebuilds it when the marker list changes, avoiding per-camera-rebuild list
  allocation while preserving projection and tap behavior. Two clean-install
  API 35 host-GPU repeats measured gfx p95/p99 `44/65 ms` and `40/53 ms`, jank
  `46.44%/47.11%`, no ANR, and valid readiness. The p95/p99 tail is
  directionally lower than the notifier-only trace, but the 20 ms gate remains
  open. Evidence:
  `tmp/android-map-benchmark-marker-point-cache-api35-20260801.json` and
  `tmp/android-map-benchmark-marker-point-cache-api35-20260801-repeat.json`.
- A native-spot-only Android build was also measured with the Flutter player
  overlay retained. It preserved the native query path but measured p95/p99
  `46/73 ms`, `45.91%` janky, and style/map idle `2675/2731 ms`; it remains an
  opt-in correctness path rather than a performance default.
  Evidence: `tmp/android-map-benchmark-native-spot-only-motion-api35-20260801.json`.
- On 2026-07-31, the current-source readiness-gated API 35 host-GPU benchmark
  was rerun from the installed profile APK with one warm-up round and the
  explicit location action. It captured 418 valid frames at gfx p95/p99
  `36/53 ms`, `42.11%` janky frames, 131 slow UI-thread samples, 20 slow bitmap
  uploads, 89 slow draw commands, Flutter total p95 `58 ms`, readiness/style
  idle `1241/1323 ms`, and no ANR. The trace is valid but fails the 20 ms
  motion gate; no renderer change is promoted from this run. Evidence:
  `tmp/android-map-benchmark-masterplan-current-api35.json`.
- On 2026-07-31, a native MapLibre composition candidate was benchmarked on
  the same API 35 host-GPU emulator with native spot/player layers and Flutter
  markers disabled. Readiness was valid at `415/442 ms` and there was no ANR,
  but the trace measured p95/p99 `31/46 ms`, `39.46%` janky frames, 95 slow
  draw commands, and Flutter total p95 `46 ms`; it was rejected and production
  defaults were left unchanged. Evidence:
  `tmp/android-map-benchmark-native-layers-api35.json`.
- On 2026-07-31, an Android compact-style candidate was also benchmarked with
  Flutter avatar/spot interaction preserved and 3D extrusion disabled.
  Readiness was valid at `367/391 ms` with no ANR; p95/p99 was `30/32 ms`,
  janky frames `27%`, slow draw commands `75`, and Flutter total p95 `34 ms`.
  It remains rejected because it misses the 20 ms gate and is a visual
  downgrade from the accepted Android 3D style. Evidence:
  `tmp/android-map-benchmark-compact-style-api35.json`.
- On 2026-07-31, the MapLibre surface gained a fail-safe load boundary: the
  normal MapLibre map remains the default, but if `style-ready` is not received
  within 15 seconds the screen switches to the local OSM-derived geometry
  fallback and loads the terrain dataset asynchronously. This avoids a blank or
  unusable map when the remote style cannot initialize; it does not change the
  open 20 ms motion-performance gate. The source contract, analyzer, Web
  release build, client artifact scan, and API 35 startup smoke all passed.
- On 2026-07-31, the admin operations slice gained fishing-spot moderation:
  an admin-only console can read draft/suspended rows and update only
  `active`, `verification_status`, `public_access`, reviewer, and review time.
  The migration keeps anonymous/public reads limited to active verified spots,
  removes authenticated insert/delete privileges, and gates the update policy
  through `public.is_admin()`. Focused source contracts, the local pgTAP shape
  suite, the full Flutter suite, Web build/secret scan, and API 35 startup smoke
  all passed. The migration still requires owner-controlled Supabase deploy.
- The local Supabase verification for migration `0012_fishing_spot_moderation.sql`
  passed on 2026-07-31: `supabase db lint --local --schema public
  --fail-on error` reported no schema errors, and all four pgTAP files passed
  with `74` assertions. The local Supabase stack was stopped after the run;
  this is local evidence only and does not claim the linked production project
  has applied the migration.
- On 2026-07-31, migration `0013_real_catch_leaderboard.sql` aligned the
  remote `catches` table with the real-photo sync payload
  (`is_real_catch_proof`, `recognized_species_id`,
  `recognition_confidence`, and `verified_at`). It also adds a bounded,
  privacy-safe `get_public_leaderboard` RPC that returns verified catch fields
  without `user_id`, coordinates, notes, or photo paths. The leaderboard now
  uses this RPC when the remote path is available and keeps its local data as a
  fail-safe fallback. Focused tests, analyzer, local migration apply, schema
  lint, full Flutter tests, Web secret scan, and API 35 startup smoke passed.
- A protected owner-controlled workflow now exists at
  `.github/workflows/supabase-content-release.yml`. It requires the
  `fishergo-content-release` environment, links with the owner-provided
  `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, and
  `SUPABASE_DB_PASSWORD`, runs the content source contracts, applies linked
  migrations with `supabase db push --linked --include-all --yes`, then runs
  linked pgTAP and public-schema lint. It is manual-only and has not run
  against the linked production project in this workspace.
- On 2026-07-31, the app gained a privacy-safe telemetry contract with a
  bounded local buffer and an optional sink. Bootstrap, MapLibre readiness and
  fallback, catch synchronization, and reward claims now emit structured
  events; identity, location, token, photo-path, and note fields are removed
  before buffering or delivery. Each event includes release and environment
  provenance. With no sink configured, this slice performs no telemetry network
  request. Focused tests, the full Flutter suite, Web analyze, and Web release
  build passed.
- On 2026-07-31, operational kill-switches were added as safe build-time
  defines: `FISHERGO_EVENTS_ENABLED`, `FISHERGO_RECOGNITION_ENABLED`, and
  `FISHERGO_SPOTS_ENABLED`. They default to enabled, while a disabled build
  returns no event labels/multipliers, rejects recognition before reading or
  sending the photo, and returns no public fishing spots. Both default and
  all-disabled behavior tests passed.
- On 2026-07-31, migration `0014_server_authoritative_rewards.sql` added an
  atomic wallet boundary: authenticated clients spend through a locked,
  idempotent RPC, claim admin grants in the same transaction that credits the
  profile, and receive positive reward adjustments through a bounded RPC. The
  coin ledger is not directly writable or readable by the client; profile coin,
  earned-coin, and delete privileges are removed while avatar/equipment fields
  remain writable. Flutter uses the RPC first and keeps only a temporary
  `PGRST202` fallback for projects that have not applied 0014 yet. Local
  Supabase lint passed; six pgTAP suites passed with 112 assertions, including
  idempotency, insufficient-balance, grant-targeting, and privilege behavior.
  Full server validation of gameplay reward events remains a Workstream 10
  follow-up.
- On 2026-07-31, the current-source API 35 daily-task reward smoke passed on
  `emulator-5554` after a clean app-data reset. The preflight explicitly
  skipped API 23 serial `0123456789ABCDEF`.
- On 2026-07-31, gameplay reward tickets were added in migration
  `0015_gameplay_reward_tickets.sql`. The server now owns reward-kind
  allowlists, daily fixed amounts, per-kind caps, idempotency keys, virtual
  catch/checkpoint rate limits, and the same-transaction wallet credit; the
  authenticated role no longer has access to the generic 0014 adjust RPC.
  Daily announcement, daily task, virtual catch, checkpoint, and real-catch
  callers now declare their ticket kind and a non-sensitive claim key. Local
  Supabase lint passed and eight pgTAP suites passed with 134 assertions.
  Full validation that a client actually completed the bite/gameplay event
  remains the next anti-cheat hardening step.
- On 2026-08-01, remote event boosts were hardened against translated-name
  drift. The admin surface now writes the selected stable fish ID, the client
  reads both `fish_id` and legacy `fish_name`, and spawn selection resolves the
  multiplier through the shared fish-ID/name matcher. Local source tests and
  analyzer passed; migration `0018` has not been applied to the linked project.
- On 2026-08-01, analytics ingestion was added as migration `0019`. The local
  Supabase stack reset through `0019`, all 12 pgTAP files passed with 183
  assertions, and `supabase db lint --local --schema public --fail-on error`
  found no schema errors. The hosted probe is wired after migration apply and
  habitat verification; local runs use the explicit disposable email/password
  fallback when anonymous sign-ins are disabled in local `config.toml`, while
  the hosted workflow remains anonymous-only.
- On 2026-08-01, migration `0020` added server-side location integrity for
  virtual fishing sessions. Local reset, 13 pgTAP files, 201 assertions, the
  targeted Flutter source suite, and targeted analyzer all passed. The hosted
  migration and live smoke remain owner-controlled; no hosted schema was
  changed by this task.
- On 2026-08-01, migration `0021_admin_retention_report.sql` added an
  admin-only aggregate retention RPC. It returns cohort size and D2/D7 counts
  and rates without actor keys or raw events, and the Admin screen now renders
  the report. Local reset, 15 pgTAP files, 218 assertions, source tests, and
  analyzer passed; the hosted migration remains owner-controlled.
- On 2026-08-01, migration `0022_server_event_configuration.sql` added the
  authenticated event projection used by GameHome. It joins boost rows to
  active parent events, preserves stable fish IDs, and is covered by local
  behavior/shape tests plus a hosted smoke that validates every returned
  multiplier. The client no longer reads the raw boost table for gameplay.
- On 2026-08-01, migration `0023_real_catch_moderation.sql` added an
  admin-reviewed pending/approved/rejected/suspended boundary for real-catch
  evidence. A trigger prevents player self-approval, the public leaderboard
  now returns approved catches only, and admins receive short-lived signed
  photo URLs in the moderation queue. Local reset passed 19 pgTAP files with
  254 assertions plus the focused Flutter source/history tests; the hosted
  migration remains owner-controlled.
- On 2026-08-01, migration `0024_fishing_spot_content_constraints.sql` added
  admin-only habitat/species-weight content constraints for fishing spots.
  The Admin screen now exposes a bounded editor for slug habitat tags and
  stable `fish-###` spawn weights, while the database remains authoritative
  for allowed keys and values. Local reset/test coverage passed 20 pgTAP files
  with 263 assertions; hosted application remains owner-controlled.
- On 2026-08-01, additive migration `0025_analytics_map_idle_event.sql`
  extended the privacy-safe analytics allowlist for the new map-idle timing
  event without rewriting migration `0019`. It replaces the security-definer
  RPC with the same privacy filter and rate limit plus `map_idle`; local reset,
  20 pgTAP files, 265 assertions, schema lint, and source tests passed. Hosted
  application remains owner-controlled.
- On 2026-08-01, the notification opt-in boundary was added without coupling
  the app to a delivery provider. The Profile screen only offers Android
  notification permission after the first catch; `稍後` defers for seven days,
  while an explicit denial stays quiet. Android 13+ uses a native permission
  callback, and Web/unsupported platforms fail closed as unavailable. A denied
  Android permission now exposes a system-settings recovery action and refreshes
  when the app resumes. The permission bridge, account-scoped preference store,
  Android debug build, and focused source/policy tests are green; Firebase token
  registration and live push delivery remain a separate owner-controlled release
  gate.
- The current-source API 35 daily-task smoke was rerun after the ticket caller
  integration on `emulator-5554`; the flow passed 1/1. API 23 serial
  `0123456789ABCDEF` was explicitly skipped. The non-blocking
  `maplibre_android` Kotlin Gradle Plugin warning remains a dependency
  follow-up.
- On 2026-07-31, migration `0016_server_validated_fishing_sessions.sql` added
  one-time server-issued bite sessions. The server now checks the spot/lure
  boundary, bite window, pull elapsed time, clock drift, one-time resolution,
  and session-to-fish binding before a virtual-catch ticket can credit coins;
  the legacy four-argument virtual ticket explicitly rejects bypass attempts.
  Local Supabase lint passed, all ten pgTAP suites passed with 163 assertions,
  and the full Flutter suite passed with 397 tests. Web release and debug APK
  builds plus the client artifact secret scan also passed.
- On 2026-08-01, the protected Supabase live-smoke workflow gained a hosted
  gameplay-session check. It creates an anonymous test identity, selects an
  active verified public spot, verifies an early pull becomes `resolved_miss`,
  resolves a second session inside the server bite window, checks idempotent
  replay, and claims a session-bound virtual-catch ticket. The tool uses only
  the public anon key, has bounded HTTP/cleanup timeouts, and exits non-zero on
  a real hosted failure; local execution correctly skipped because hosted
  Supabase secrets are not present. Evidence:
  `tool/verify_supabase_gameplay_session.dart` and
  `test/supabase_gameplay_session_smoke_source_test.dart`.
- The API 35 fishing-minigame smoke passed 1/1 on `emulator-5554` after a
  clean install. The preflight explicitly skipped API 23 serial
  `0123456789ABCDEF`; runtime permission grants were deferred by the emulator,
  and the existing `maplibre_android` KGP warning remains non-blocking.
- On 2026-07-31, the telemetry slice was deployed to a fresh Vercel Preview
  and inspected as `READY`: deployment
  `dpl_EkNim8R5ooKnxjCgKvq3AuooiFqS`, URL
  `https://fishergo-4llip7254-klyeung-s-projects.vercel.app`. The deployment
  target is `preview`; `fisher-go.app` and `www.fisher-go.app` aliases remain
  unchanged.
- On 2026-07-31, the telemetry and operational kill-switch slice was redeployed
  to a fresh Vercel Preview and inspected as `READY`: deployment
  `dpl_69zwAb5JWVFe7AVsFswHPb3g4ujm`, URL
  `https://fishergo-2mu6jax7i-klyeung-s-projects.vercel.app`. The deployment
  target is `preview`; Production aliases remain unchanged.
- On 2026-07-31, the 0014 wallet-integration slice was deployed to a fresh
  Vercel Preview and inspected as `READY`: deployment
  `dpl_8HWicRNXXxsZkgxuUUaj7xSVRRaT`, URL
  `https://fishergo-oup8b5l65-klyeung-s-projects.vercel.app`. The deployment
  target is `preview`; `fisher-go.app` and `www.fisher-go.app` remain unchanged.
- On 2026-07-31, the 0015 gameplay reward-ticket slice was deployed to a fresh
  Vercel Preview and inspected as `READY`: deployment
  `dpl_AeY2JPTSF9tLthuGxy5wAXEKaJFj`, URL
  `https://fishergo-g2c5o7f3c-klyeung-s-projects.vercel.app`. The deployment
  target is `preview`; `fisher-go.app` and `www.fisher-go.app` remain unchanged.
- The 0015 Preview was redeployed after removing coordinates from checkpoint
  claim keys; final inspection is `READY`: deployment
  `dpl_unEBBw7FgGjo3AcLVJkeG1HjRPhZ`, URL
  `https://fishergo-k1lrpi80c-klyeung-s-projects.vercel.app`. Production aliases
  remain unchanged.
- On 2026-07-31, the server-session client slice was deployed to a fresh
  Vercel Preview and inspected as `READY`: deployment
  `dpl_Ey9uymvxztoBkwMsQmFnwzPFUodA`, URL
  `https://fishergo-nw89rtv9i-klyeung-s-projects.vercel.app`. The deployment
  target is `preview`; `fisher-go.app` and `www.fisher-go.app` remain unchanged.
- The Preview was redeployed after moving encyclopedia unlock behind confirmed
  wallet credit; final inspection is `READY`: deployment
  `dpl_9wquy4BhTQ71UwJPAFfr75e7QGgT`, URL
  `https://fishergo-qdhtd9ncc-klyeung-s-projects.vercel.app`. Production aliases
  remain unchanged.
- On 2026-07-31, the current real-catch reward-feedback slice was deployed to a
  fresh Vercel Preview: URL
  `https://fishergo-24ek2hpos-klyeung-s-projects.vercel.app`. The deployment
  target is `preview`; `fisher-go.app` and `www.fisher-go.app` remain unchanged.
- After the telemetry changes, the debug APK rebuilt successfully and the
  API 35 startup smoke passed on `emulator-5554` from identity selection through
  tutorial skip into GameHome. The API 23 photo-frame serial
  `0123456789ABCDEF` was explicitly skipped. The non-blocking
  `maplibre_android` Kotlin Gradle Plugin warning remains a dependency
  follow-up.
- On 2026-07-30, the post-production renderer repeat on the same API 35
  host-GPU emulator passed map readiness and minimum-frame validity with no
  ANR. The 484-frame trace measured p95/p99 `30/34 ms`, `31.61%` janky frames,
  62 slow draw commands, and readiness `2.014/2.018 s`; this confirms the
  geography/topology path remains functional but does not close Gate 2.
  Evidence: `tmp/android-map-benchmark-release-gate-20260730.json`.
- The release-signing fail-closed check was also executed locally on
  2026-07-30: with all `FISHERGO_ANDROID_*` signing values absent and
  `FISHERGO_REQUIRE_RELEASE_SIGNING=true`, Gradle stopped before packaging with
  the expected protected-signing error. No distributable artifact was claimed.
- The Android release workflow now produces separate Dart symbol directories
  for the AAB and APK and fails closed if both symbol files are not present.
- The self-service account-deletion source boundary is now protected by an
  explicit `[functions.delete-account] verify_jwt = true` entry in
  `supabase/config.toml`. The local function source and cleanup contract are
  covered, but the hosted Edge Function deployment and disposable-account
  deletion smoke remain open until a Supabase management token is provided.
  Catch-photo cleanup re-reads from offset zero after each deletion page, so
  shrinking Storage listings cannot skip objects; this invariant is covered
  by `test/delete_account_source_test.dart`.
- A protected manual workflow now provides the owner-controlled hosted path:
  `.github/workflows/supabase-account-deletion-release.yml` deploys the
  JWT-protected function with `SUPABASE_ACCESS_TOKEN` and runs the bounded
  disposable-account smoke in `tool/verify_supabase_account_deletion.dart`.
  Its first step runs the deletion source contracts before deployment. The
  workflow is source-verified and fail-closed, but has not run because the
  required protected environment secrets are not present in this workspace.
  A local unsigned x64 proof built an AAB (`74.2 MiB`) and APK (`93.7 MiB`),
  each with a `3.99 MiB` `app.android-x64.symbols` file. These are artifact
  contract proofs only; protected signing is still required for Play upload.
- The live Supabase Auth provider configuration check was executed on
  2026-07-30 using only the public URL and anon key: `google_enabled=true` and
  `anonymous_enabled=true`. The provider gate passed; anonymous-to-account
  identity-preservation smoke still requires the protected smoke email/password
  credentials in the release environment.
- The bounded auth-upgrade runner now verifies the full identity transition:
  the initial `/auth/v1/signup` response must be `is_anonymous=true`, the
  upgraded response must preserve the same user ID, and it must no longer be
  anonymous. The source contract passes; live execution still requires a
  disposable owner-provided email/password pair.
- Account deletion is now source-ready: the Profile confirmation flow clears
  the local account namespace only after a successful `delete-account` Edge
  Function response. The function removes current `profiles`, `catches`,
  `daily_leaderboard`, and `coin_grant_claims` rows, legacy player rows,
  private catch photos, and the Auth user. The hosted Edge Function
  deployment, live deletion smoke, privacy-policy URL, and Play Data Safety
  owner review remain open. Inventory: `docs/store-release-data-safety.md`.
- The Android GameHome and direct native benchmark runners now reject traces
  with fewer than 60 frames and record `minimum_frame_count`. This prevents
  partial emulator startup, ADB recovery, or SurfaceSync samples from being
  reported as performance evidence; the minimum-frame source contracts are
  covered by `test/android_map_benchmark_source_test.dart` and
  `test/android_native_map_benchmark_source_test.dart`.
- On 2026-07-30, the current source was deployed successfully to a fresh
  Vercel preview after the remote Flutter build and client artifact scan
  completed. The CLI inspection reports `READY`, preview target, and
  deployment id `dpl_jEJidcdM35bdu46PuxTALDWA5Anr`.
  Preview: `https://fishergo-fvfisruc1-klyeung-s-projects.vercel.app`.
  The project keeps Preview deployments behind Vercel login protection, so a
  browser capture of this preview redirects to the Vercel login page; public
  Web smoke evidence must continue to use the production alias.
- On 2026-07-30, after the renderer candidate was removed, the stable current
  source was deployed to Vercel Production and inspected as `READY`. Deployment
  `dpl_B5gWrj17V1jRtuy3gWPCgG7SNzNh` owns both `fisher-go.app` and
  `www.fisher-go.app`; the production build completed the client artifact scan.
  The desynchronized WebGL context remains query-gated and was not promoted
  to the production default; the preview URL is recorded in the task log.
- On 2026-07-30, after enabling the measured adaptive Web pixel-ratio preset,
  the current source was redeployed to Vercel Production and inspected as
  `READY`. Deployment `dpl_JCwvBp3xBeu3qSRBtCm5tnMo3cwc` owns both
  `fisher-go.app` and `www.fisher-go.app`; the remote Flutter build and client
  artifact secret scan completed successfully. Mobile Web keeps native canvas
  resolution while wide screens use `pixelRatio: 0.75`; the explicit
  `?fishergo_pixel_ratio=1` query remains available for A/B verification.
- On 2026-07-30, after tightening the public fishing-spot query to require
  `public_access=true`, the Web release was redeployed and inspected as
  `READY`. Deployment `dpl_83YnCMvLDwDthq5xYnAKWxociyHM` owns both
  `fisher-go.app` and `www.fisher-go.app`; the remote Flutter build and client
  artifact secret scan completed successfully.
- On 2026-07-30, release `0.1.1+2` was deployed to Vercel Production and
  inspected as `READY`. Deployment `dpl_3byFbd7RDnELCreSn3ay96gZPCBf` owns
  both `fisher-go.app` and `www.fisher-go.app`; the remote Flutter build and
  client artifact secret scan completed successfully.
  Deployment URL: `https://fishergo-dovtu65uz-klyeung-s-projects.vercel.app`.
- After the explicit location-service and permission-state change, the same
  `0.1.1+2` source was redeployed to Vercel Production and inspected as
  `READY`. Deployment `dpl_D9EXGeGWXvuRUCvDWr6Cp98oDCii` owns both
  `fisher-go.app` and `www.fisher-go.app`; the remote Flutter build, manifest,
  and client artifact secret scan completed successfully.
  Deployment URL: `https://fishergo-pcgz8te2l-klyeung-s-projects.vercel.app`.
- After deferring CatchLog location access and declaring Android 14 selected
  photo access, the current `0.1.1+2` source was redeployed to Vercel
  Production and inspected as `READY`. Deployment
  `dpl_EraBH5TXr7RFSeBC2jd3GRsip4db` owns both `fisher-go.app` and
  `www.fisher-go.app`; the remote Flutter build, manifest, and client artifact
  secret scan completed successfully.
  Deployment URL: `https://fishergo-8a06nhbn8-klyeung-s-projects.vercel.app`.
- On 2026-07-31, the current dirty worktree was published to a new Vercel
  Preview deployment and inspected as `READY`. Deployment
  `dpl_5SAiXEjGxkhmA6m4JHSeTFj9NK9S` is available at
  `https://fishergo-onmse5774-klyeung-s-projects.vercel.app`. The production
  aliases remain on `dpl_EraBH5TXr7RFSeBC2jd3GRsip4db`; this Preview was not
  promoted because the source now includes account-deletion UI while the
  protected hosted Edge Function deployment and live deletion smoke are still
  pending.
- On 2026-07-31, the current source with the MapLibre timeout fallback was
  deployed to a new Vercel Preview and inspected as `READY`. Deployment
  `dpl_CnN5HL2ABcA6btDjnfkixmpL4YKA` is available at
  `https://fishergo-fbzzzn8ot-klyeung-s-projects.vercel.app`. The Production
  aliases remain unchanged.
- On 2026-07-31, the current source with the admin fishing-spot moderation
  console was deployed to a new Vercel Preview and inspected as `READY`.
  Deployment `dpl_3YpPyWTPBBLAEgqSoiqERuFLnjSk` is available at
  `https://fishergo-bndvqyyih-klyeung-s-projects.vercel.app`. Production
  aliases remain unchanged; Supabase moderation writes are unavailable until
  migration `0012_fishing_spot_moderation.sql` is applied remotely.
- On 2026-07-31, the current source with the real-catch schema alignment and
  cloud-first leaderboard was deployed to a new Vercel Preview and inspected
  as `READY`. Deployment `dpl_GwmVhQNHjDErg1cYxZTXFzQTTF3V` is available at
  `https://fishergo-cx72z1fb5-klyeung-s-projects.vercel.app`. Production aliases
  remain unchanged.
- The local `0.1.1+2` Android profile artifact was verified with package
  metadata `versionCode=2`, `versionName=0.1.1`; asset-budget and client-secret
  scans passed. This remains a profile/smoke artifact, not a signed Play
  release; protected upload-key credentials are still required before beta
  distribution.
- The same build now emits `release-manifest.json` through
  `tool/write_release_manifest.dart`; it carries the shared app version,
  release id, build id/time, and Git SHA fields for Web and protected Android
  artifacts. Vercel serves it with no-cache headers so release provenance is
  not hidden behind a stale CDN response.
- The Web benchmark dependency is now pinned in `package.json` and
  `package-lock.json`; CI uses `npm ci`, matching the local runner instead of
  installing an untracked package ad hoc.
- On 2026-07-30, a Playwright CLI runtime proof against the latest local
  `build/web` reached the login-first shell, showed the live OpenFreeMap
  geometry with roads, water, buildings, and the HUD, and captured
  `output/playwright/current-build-runtime-proof.png`. The local build had no
  Supabase public defines, so its Google action was correctly disabled; this
  is a local startup/map proof, not an OAuth-provider pass.
- A separate local release build supplied the non-secret `.env` public values
  through `--dart-define=SUPABASE_URL` and
  `--dart-define=SUPABASE_ANON_KEY`; the first-launch identity dialog rendered
  an enabled teal `Google 登入` button in
  `tmp/google-config-local-proof.png`. Vercel lists both public variables for
  Preview and Production. The remaining auth gate is provider-level live
  Google sign-in and identity upgrade, not button availability.
- On 2026-07-30, the linked remote RLS shape/behavior suite passed all `39`
  assertions using `npx supabase test db --linked` on the two remote fixtures.
  A schema-scoped linked lint also passed with
  `npx supabase db lint --linked --schema public --fail-on error`; the CLI's
  unscoped lint still reports missing helper functions in the remote
  `extensions` test-support schema, so it is not used as the public-schema
  release gate.
- `tool/run_android_integration_smoke.ps1` now has a 180-second timeout,
  optional `-ClearAppData` fresh-state setup, and API/device/PID/logcat
  diagnostics before returning exit code `124`. The known API 23 photo-frame
  serial remains rejected by preflight.
- `.github/workflows/flutter-quality.yml` now invokes that same runner for all
  12 API 35 integration flows with `set -euo pipefail`, so CI also enforces
  the API gate, clean-state setup, and bounded timeout instead of calling raw
  `flutter test` directly.
- `.github/workflows/android-map-benchmark.yml` now provides a manual,
  evidence-first API 35 host-GPU benchmark. It builds the profile APK with
  MapLibre performance telemetry, requires map readiness, runs one warm-up
  round, and uploads the JSON trace plus a screenshot for 14 days. The 20 ms
  budget is opt-in through `enforce_frame_budget`, so known failing metrics are
  recorded without blocking ordinary push CI.
- `.github/workflows/web-map-benchmark.yml` now provides a manual,
  evidence-first Web benchmark. It builds the release client, serves the exact
  output locally in CI, runs Playwright Chromium at 390x844 and 1440x900, and
  uploads the JSON trace plus both screenshots for 14 days. The 30 FPS / 33.3
  ms p95 / 5% jank budget is opt-in through `enforce_frame_budget` while the
  hosted runner's baseline is being established.
- On 2026-07-30, the API 35 fishing integration initially exposed a stale-qemu
  attach timeout. After stopping the orphaned qemu process, removing only its
  AVD lock files, rebooting `FisherGO_API35`, and running with
  `-ClearAppData`, the runner completed the bite-first fishing flow on
  `emulator-5554` with `All tests passed!`. The runner also tolerates Flutter
  warning records while preserving the Flutter exit code.
- On 2026-07-30, the same runner completed all four API 35 flows sequentially
  on `emulator-5554`: startup/auth, bite-first fishing, offline reconnect, and
  daily-task reward. Each flow rebuilt and installed its own debug APK; the
  batch ended with `ANDROID_SMOKE_BATCH=PASS`. The only build noise was the
  existing `maplibre_android` Kotlin Gradle Plugin migration warning.
- After the verified-spot fail-closed and remote `species_weights` wiring
  changes, the clean API 35 bite-first flow was rerun on `emulator-5554` and
  passed. The runner reported `ANDROID_SMOKE_API=35` and explicitly skipped
  serial `0123456789ABCDEF` (the API 23 photo frame); the only remaining build
  noise was the existing MapLibre KGP migration warning.
- After the public fishing-spot visibility filter, the latest source rebuilt a
  profile APK successfully and API 35 `emulator-5554` reran both
  `startup_auth_flow_test.dart` and `fishing_minigame_flow_test.dart`; both
  passed. Preflight again skipped serial `0123456789ABCDEF`; the complete
  four-flow vertical slice remains covered by the earlier recorded proof.
- After the Web main-road style change, the API 35 bite-first flow was rerun
  on `emulator-5554` with `-ClearAppData` and passed again. The runner reported
  `ANDROID_SMOKE_API=35`, skipped serial `0123456789ABCDEF`, and ended with
  `All tests passed!`; no Android gameplay regression was observed.

## Gate 0: Client Secret Boundary

Status: **PARTIAL - build boundary and live photo sync pass; provider rotation and live auth-upgrade smoke remain open**

The Flutter client no longer packages `.env` or calls the VectorEngine provider
directly. Fish recognition crosses the authenticated `recognize-fish` Supabase
function boundary, and the local web/APK artifact scanner passes for the current
builds.

Latest evidence:

- `dart tool/check_client_artifacts_for_secrets.dart build/web`: passed.
- `dart tool/check_client_artifacts_for_secrets.dart build/app/outputs`: passed
  across approximately 1.49 GB of debug/profile/release outputs using bounded
  streaming reads, including tokens split across chunk boundaries.
- `flutter test --no-pub integration_test/startup_auth_flow_test.dart
  -d emulator-5554`: passed on Android API 35 after a clean app install;
  identity choice, guest mode, tutorial skip, and GameHome semantics all
  completed. The same test is wired into the CI API 35 emulator job.
- `flutter test --no-pub --dart-define=FISHERGO_MAPLIBRE=true
  integration_test/fishing_minigame_flow_test.dart -d emulator-5554`: passed
  on Android API 35 after a clean install; the tutorial entered the real
  bite-first overlay and exposed `魚食餌！`, `浮標急震，立即抽竿`, and the
  `抽竿！` action, then completed the deterministic tutorial catch and
  verified the revealed `assets/fish/mobile_webp/010.webp` Image widget. The
  same test also covers the overlay teardown gesture race.
- On 2026-07-22, `tool/run_android_integration_smoke.ps1` passed the fresh
  startup flow on `emulator-5554` after the API 35 preflight. The runner
  explicitly skips the API 23 photo frame and makes runtime permission grants
  best-effort for an already-installed package. GameHome no longer requests
  location during startup; the location prompt is now triggered only by the
  locate control, so identity choice and the skippable tutorial cannot be
  blocked by an Android system dialog. Source coverage is in
  `test/location_permission_sequence_source_test.dart` and
  `test/android_smoke_preflight_source_test.dart`.
- On 2026-07-22, the API 35 emulator reran the offline reconnect and daily
  task reward integration flows after the account-scoping change; both passed
  on clean installs. The offline flow preserved and replayed the pending catch
  queue, while the reward flow persisted a claimed task in account state.
- The catch-result regression now renders the caught fish's full-color
  `iconAsset` instead of its locked/silhouette asset. The source contract is
  covered by `test/fishing_minigame_copy_test.dart`, and the referenced WebP
  asset (`assets/fish/mobile_webp/010.webp`) exists in the current catalog.
- The full Flutter suite passed with `324` tests after the auth callback,
  permission-sequencing, smoke-runner, cache-policy, account-isolation, and
  reconnect changes;
  `flutter analyze --no-pub` also passed with no diagnostics.
- On 2026-07-22, fish artwork selection was centralized in
  `fishGameArtworkAssetPath`. The encyclopedia and catch-result surfaces now
  resolve legacy `*-badge` and `*-local-badge` paths to transparent mobile
  WebP artwork, so a successful virtual catch does not reintroduce a white
  square. Cancelling or backing out of the bite-first dialog returns `null`
  before `consumeConsumable`, so the lure is not spent on an unstarted catch.
  Focused coverage is in `test/fish_catalog_regression_test.dart` and
  `test/fishing_minigame_copy_test.dart`; the API 35 integration flow and full
  suite passed after the change.
- Guest account isolation now migrates the local profile, progress, fish
  collection, scoped catch queue, and legacy global catch queue once into the
  first account namespace. Focused coverage is in
  `test/local_account_service_test.dart`; the local queue now resolves through
  `LocalAccountService.catchQueueBoxName`. The anonymous Email-upgrade path
  now calls `restoreSession()` immediately after `updateUser`, with a source
  regression in `test/profile_auth_source_test.dart`; live provider upgrade
  remains an external gate. The provider-level identity check in
  `tool/verify_supabase_auth_upgrade.dart` now uses bounded REST calls for
  anonymous signup and `PUT /auth/v1/user`, so it does not depend on the Dart
  auth client path that previously hung on Windows. It requires a disposable
  `FISHERGO_SMOKE_UPGRADE_EMAIL/PASSWORD` pair and exits `2` when absent.
- Boat rental state and boat-route attempts are now account-scoped through
  `LocalAccountService`; the legacy device-wide `boat_vendor_box` is copied
  once into the first account namespace and then no longer read. Coverage is
  in `test/boat_vendor_service_test.dart`; guest-to-account migration now also
  carries the account-scoped boat box and unions existing route-result maps,
  covered by `test/local_account_service_test.dart`.
- Catch sync now has an in-flight guarded reconnect coordinator. A transition
  from `ConnectivityResult.none` to Wi-Fi/mobile retries the pending queue;
  `test/offline_sync_coordinator_test.dart` covers offline no-op and overlap
  prevention. The catch-log screen now ignores late reconnect callbacks after
  disposal and keeps the local queue when a remote retry throws, covered by
  `test/catch_log_sync_resilience_source_test.dart`. CatchLogScreen also
  surfaces the latest connectivity state and accepts an injected stream for
  deterministic tests; the production path still uses
  `Connectivity().onConnectivityChanged`.
  The API 35 `offline_reconnect_flow_test.dart` now drives the real CatchLogScreen
  with a seeded Hive queue, offline event, reconnect event, and fake remote;
  it passed on `emulator-5554` and verified the queue changed from `1` to `0`.
  The new `offline_network_toggle_flow_test.dart` additionally drives the
  production Connectivity stream while the runner toggles the API 35
  emulator's radios; it verified the queue stayed at `1` until the real Wi-Fi
  restore edge, then replayed to `0`. The runner deliberately leaves a
  15-second post-attach window so the test can subscribe before restoration.
  Startup, bite-first minigame, both offline reconnect flows, and daily reward
  flows are all wired into the CI API 35 emulator job. The emulator's
  transport label is not a reliable `none` signal during radio shutdown, so
  the UI's explicit offline-state copy remains covered by deterministic
  coordinator tests rather than this device-specific smoke.
- Real-catch photo sync now uploads evidence through the authenticated private
  `catch-photos` bucket using a `userId/catchId` object path, then stores that
  path in `photo_storage_path` rather than pretending it is a public URL.
  `SupabaseCatchPhotoUrlResolver` creates short-lived signed URLs on demand.
  `test/catch_photo_storage_test.dart` and
  `test/catch_photo_url_resolver_test.dart` cover path isolation and URL
  expiry; `0010_catch_photos_storage.sql` and
  `0011_catch_photo_storage_path.sql` cover the bucket, ownership policies,
  and schema. The smoke now supports a cleanup-safe anonymous authenticated
  session: run `dart run tool/verify_supabase_catch_photo_storage.dart` with
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
  `FISHERGO_SMOKE_ANONYMOUS=true`. It uploads a tiny PNG, reads it through a
  short-lived signed URL, deletes the object in `finally`, and signs out.
  Each remote operation has a bounded timeout and cleanup failures are surfaced
  as warnings rather than hanging the workflow. On 2026-07-30, the runner was
  moved from the Dart Supabase SDK auth/storage calls to the same bounded REST
  endpoints used by the service; this avoids the Windows SDK hang and accepts
  both object and list signed-URL responses. The production-linked anonymous
  smoke then passed with private upload, signed read-back, cleanup, and
  sign-out all completing successfully.
  Password mode remains available with `FISHERGO_SMOKE_EMAIL` and
  `FISHERGO_SMOKE_PASSWORD`; missing variables exit with code `2` and are not
  a pass.
- Authenticated catch history now reads the current user's recent catches,
  resolves private photo paths into short-lived signed URLs, and renders the
  records and thumbnails in the catch-log screen. A failed/expired photo URL
  leaves the catch record visible. Focused coverage is in
  `test/catch_history_service_test.dart`; the anonymous storage read-back smoke
  is now live-verified, while the account-upgrade runner is source/analyze
  verified and still needs disposable password credentials for live evidence.
- A manual GitHub Actions workflow now runs both provider-level checks together
  inside the protected `fishergo-live-smoke` environment:
  `.github/workflows/supabase-live-smoke.yml`. It passes only the required
  values as environment variables, never prints them, and fails closed when a
  secret is absent because both smoke scripts return exit code `2` for an
  unconfigured run. The workflow source contract is covered by
  `test/supabase_live_smoke_workflow_source_test.dart`; the photo step is
  live-verified in anonymous mode, while the bounded account-upgrade step
  remains protected until disposable Supabase credentials are configured.
- `MapCachePolicy` now configures the Android MapLibre ambient cache once per
  process with a bounded `4000`-tile / `64 MiB` policy and automatic database
  packing; Web and iOS remain on their platform defaults until separately
  benchmarked.
- API 35 warm cache repeats after the policy measured p95 `81 ms` and `73 ms`
  with no app-specific ANR; style-ready telemetry was `8.722 s` and `4.439 s`.
  This improves persistent cache readiness but does not close the `20 ms`
  motion gate. Evidence: `tmp/android-map-benchmark-maplibre-cache-policy-warm-api35.json`
  and `tmp/android-map-benchmark-maplibre-cache-policy-warm-repeat2-api35.json`.
- The opt-in Android native-player sprite path registered the selected Flutter
  avatar through `addImageFromWidget` and passed the API 35 startup smoke. Two
  valid candidate motion runs measured gfx p95 `73 ms` and `69 ms`; the same
  code with the flag disabled measured `61 ms` and `105 ms`, showing no stable
  improvement over emulator variance. The flag remains disabled by default.
- A combined opt-in native-player plus native-spot-layer run reduced Flutter
  telemetry p95 total from `435 ms` to `129 ms`, but the native gfx p95 moved
  from `69 ms` to `77 ms` and p99 reached `500 ms`. This is not a stable Gate 2
  improvement; both native layer flags remain disabled by default. Evidence:
  `tmp/android-map-benchmark-native-layers-no-flutter-markers-warm-repeat.json`.
- After the policy change, API 35 `startup_auth_flow_test` and
  `fishing_minigame_flow_test` both passed on `emulator-5554` after clean
  installs, confirming GameHome startup, tutorial skip, MapLibre initialization,
  bite-first fishing, and full-color catch rendering.
- On 2026-07-22, the same two API 35 integration tests passed again after the
  renderer benchmark guard change. The startup flow reached GameHome and opened
  the encyclopedia entry; the minigame flow completed the bite-first catch with
  the API 35 emulator only. The physical API 23 photo-frame device was not used.
- On 2026-07-22, the startup and bite-first API 35 tests were rerun after the
  live-smoke workflow addition. Both passed on `emulator-5554`; the only build
  diagnostic was MapLibre's existing Flutter built-in-Kotlin migration warning.
  No API 23 device was targeted.
- After the Android 3D map preset became the default, the API 35
  `daily_task_reward_flow_test` and `offline_reconnect_flow_test` passed again
  on `emulator-5554`; reward claim persistence and queued catch replay remain
  intact with the new map style.
- API 35 `daily_task_reward_flow_test` also passed after a clean install: a
  completed `今日釣到 2 條魚` task exposed `+20`, changed to `已領`, moved the
  local wallet from `500` to `520`, and persisted `catch_2_fish` in the account
  progress state. HUD account controls now expose Traditional Chinese labels
  and explicit button semantics for automation and accessibility.
- `flutter build web --release --no-pub
  --dart-define=FISHERGO_MAPLIBRE=true` passed after the gesture teardown fix;
  `build/web` contains both `version.json` and the full-color `010.webp`
  catalog asset.
- On 2026-07-19, the current stable source built an arm64 release AAB with
  `flutter build appbundle --release --no-pub
  --dart-define=FISHERGO_MAPLIBRE=true --target-platform android-arm64`;
  `build/app/outputs/bundle/release/app-release.aab` is `78.0 MiB`.
- The same release outputs passed `dart run
  tool/check_client_artifacts_for_secrets.dart build/web build/app/outputs`
  and `dart run tool/check_asset_budget.dart --web-root=build/web
  --android-output-root=build/app/outputs --packaged-asset-root=build/web/assets`;
  measured Web package `89.5 MiB` and AAB `78.0 MiB`.
- On 2026-07-18, `https://fisher-go.app/assets/.env` returned the expected
  canonical `308` to `www`, and the final `www` request returned `404 Not Found`.
- On 2026-07-22, `dart run tool/verify_deployed_web.dart
  --url=https://fisher-go.app --alias=https://www.fisher-go.app` passed: both
  public roots returned `200`, both `/assets/.env` paths returned `404`, and
  both aliases exposed the same `mainJsPath` from `flutter_bootstrap.js`.
- The 2026-07-22 response headers show that `fisher-go.app` intentionally
  canonical-redirects with HTTP `308` to `www.fisher-go.app`. The `www` alias
  now serves `main.dart.js?v=20260722095923`; both public roots and both
  `/assets/.env` checks pass the deployed verifier.

The production deploy script now extracts the Vercel deployment URL, promotes
both public domains to that deployment, and runs the same verifier before
reporting success. It will fail closed if the alias promotion, Flutter
bootstrap, release-manifest consistency, or secret-asset check fails.

The current production check returns a canonical `308` from
`fisher-go.app/assets/.env` to `www.fisher-go.app/assets/.env`, followed by
`404` on the `www` host; the sensitive asset is not publicly served.

The 2026-07-22 Vercel API audit found a `READY` production deployment,
verified `fisher-go.app` and `www.fisher-go.app` aliases, and both production
`SUPABASE_URL` and `SUPABASE_ANON_KEY` variables. The deployed `main.dart.js`
contains both configured public values. A local raw REST smoke then verified
anonymous auth, private `catch-photos` upload, signed read-back, and object
cleanup with HTTP `200` responses. The current bounded REST smoke wrapper also
passed on this Windows host; the live email/Google upgrade still needs
disposable credentials and provider-console verification.

The Supabase Auth Management API then confirmed Google, email, and anonymous
providers are enabled, Google client credentials are present, the site URL is
`https://fisher-go.app`, and both public aliases are in `uri_allow_list`.
Production browser QA showed the Google button enabled and redirected to the
Google account page with the Supabase callback and `https://fisher-go.app` as
the post-auth redirect. Credentialed guest-to-account progress preservation is
the only remaining auth proof.

On 2026-07-22, Android OAuth/linking was corrected to use Supabase Flutter's
native `linkIdentity` launch path and the `fishergo://auth/callback` deep link;
Web continues to use `https://fisher-go.app`. The Android manifest now accepts
the callback, the Supabase Auth redirect allowlist contains both HTTPS aliases
plus the native URI, and an API 35 cold-start intent resolved to
`com.fishergo.app/.MainActivity` without runtime or MapLibre errors. Source
coverage is in `test/auth_redirect_config_test.dart` and
`test/profile_auth_source_test.dart`.

Open owner actions:

- Rotate any provider credentials that were exposed by earlier deployments.
- Re-run the deployed verifier after every production promotion so the alias
  and secret-asset boundary stay enforced.
- Configure `VECTOR_ENGINE_API_KEY` and related provider values only as Edge
  Function secrets.

## Gate 1: Database Isolation

Status: **PARTIAL - linked player-table behavior passes; legacy auth fixture remains local/CI-only**

The local Supabase stack applied the current migration bundle from a clean
database. The pgTAP suite now runs 66 assertions across the three `player_*`
tables, legacy `public.profiles` and `public.catches`, the remote-safe behavior
fixture, and the remote policy-shape fixture used by the current app:

- authenticated users can write their own rows;
- User A cannot insert, update, or delete User B rows;
- legacy profiles are private to their owner;
- the legacy catches table has RLS, authenticated CRUD grants, and an own-row
  delete policy;
- anonymous catalog inserts are removed.

Evidence from this run:

- `npx supabase test db --local`: 66 tests passed across the local full fixture,
  the linked-safe player behavior fixture, and the remote policy-shape fixture;
- `npx supabase db lint --local --schema public --fail-on error`: exit 0 with
  `No schema errors found`. The CI command is scoped to FisherGO's public
  schema and fails closed on public errors; the installed `extensions`/pgTAP
  introspection diagnostics are intentionally outside that application scope.
- A clean local `npx supabase start` now applies all migrations successfully on
  a stack without the linked-only `cli_login_postgres` role. Migration `002`
  conditionally grants the linked runner only when that role exists.
- Linked `npx supabase db lint --linked`: no public migration schema errors;
  the installed pgTAP extension reports the same PostgreSQL 17 introspection
  diagnostics as local lint. These diagnostics are isolated to
  `extensions.*`, not the FisherGO public tables or policies.
- Linked policy inspection found a stale universal profile-read policy;
  additive migration `0007_repair_legacy_profile_policies.sql` was pushed with
  `--include-all`. The remote now exposes only owner-scoped player policies and
  `users read their own profile` with `auth.uid() = id`.
- Versioned migrations `0008`, `0009`, and `002` install pgTAP in the private
  `extensions` schema and grant only the linked test runner access to its
  functions.
- Linked `npx supabase test db --linked supabase/tests/remote_player_rls_shape_test.sql`:
  15 assertions passed. This is a read-only remote policy-shape check.
- Linked `npx supabase test db --linked
  supabase/tests/remote_player_rls_shape_test.sql
  supabase/tests/remote_player_rls_behavior_test.sql`: 39 assertions passed.
  The behavior fixture creates random text ownership IDs inside a transaction,
  sets User A/B JWT claims, exercises own writes and cross-user reads/mutations,
  and rolls back without touching `auth.users` or persistent production rows.
  This remote suite was rerun on 2026-07-22 after starting the local Docker
  engine: both fixtures completed successfully with 39 tests, and the linked
  public-schema lint again returned `No schema errors found`.
- The legacy `public.profiles` and `public.catches` portions of the full fixture
  remain intentionally local/CI-only because their foreign keys require real
  managed `auth.users` rows. The linked player-table behavior plus shape suite
  is now the authoritative non-destructive production check for the active app
  sync tables.

The legacy auth-backed fixture must still run in a release CI environment with
real test users before Gate 1 is treated as fully released.

## Gate 2: MapLibre Engine Decision

Status: **OPEN - MapLibre 3D is enabled; Android motion p95 gate remains open**

The MapLibre proof now renders OpenMapTiles geometry with a FisherGO-owned
style. The old renderer remains available through `FISHERGO_MAPLIBRE=false`.

### Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Sha Tin topology | Pass | Shing Mun River, roads, buildings, avatar, and the Sha Tin test spot rendered in the Web proof. |
| Marker startup and reload | Pass | Player and spot markers appeared without an initial camera gesture and survived browser reload. |
| Spot selection | Pass | The Sha Tin test spot remained tappable before and after reload. The API 35 fixed proof also selected the spot after a physical tap when the camera was zoomed to 15.0. |
| GameHome nearby-spot visibility | Pass locally | GameHome now uses `gameMapInitialZoom = 16.0` to keep the first view focused on the roughly 500 m gameplay radius while retaining nearby context. Spot filtering remains GPS/radius based; the API 35 startup flow still reaches GameHome after the zoom change. |
| Remote fishing-spot trust boundary | Pass locally | When Supabase is configured, GameHome starts with no bundled points until the remote active/verified registry returns. An empty 500 m result now shows `500 米內暫無已核實釣點` and a `全景` entry instead of implying a synthetic nearby spot. Remote HTTP/query failure also fails closed to zero spots rather than resurrecting stale bundled coordinates; offline bundled registry remains limited to builds without Supabase configuration. Remote `species_weights` now flows from each verified spot into the fishing minigame, with stable fish IDs preferred over translated names. Additive migration `0017_fishing_spot_habitat_weights.sql` and the bundled registry now carry auditable game-design weights for Tung Chung/North Water, Sam Mun Tsai/Tai Po, Tsing Ma, and East Water profiles. Source coverage is in `test/game_home_map_config_test.dart`, `test/fishing_spot_repository_test.dart`, `test/fishing_spot_registry_test.dart`, `test/fishing_spot_habitat_migration_source_test.dart`, and `test/fishing_spawn_rules_test.dart`; API 35 visual evidence is `tmp/android-remote-empty-state-smoke.png`. Linked production application of `0017` remains owner-controlled. |
| Platform style preset | Pass locally | Android now defaults to the lean `fisherGoGame3dMapStyle` through `FISHERGO_MAP_ANDROID_3D_STYLE=true`; Web now defaults to the measured no-extrusion/main-road motion style. Both retain OpenMapTiles water, waterway, road, building footprint, and pier geometry. Rich, compact, and low-power styles remain explicit opt-ins/diagnostics. |
| Android game 3D style | Pass visually; performance gate open | API 35 host-GPU screenshot rendered real building extrusion, roads, waterways, coastline, avatar, HUD, and water. The lean style is capped at 14 layers and removes duplicate land/casing passes. Evidence: `tmp/android-host-gpu-game-3d-style-diagnostic.png` and `tmp/android-map-benchmark-host-gpu-game-3d-no-gradient-repeat.json`. |
| Native fishing-spot layer proof | Pass locally | Opt-in Android and Web proofs rendered MapLibre-owned spot circles/labels; Android `featuresAtPoint` returned the verified `spot_id` and updated the Flutter status card after a real tap. |
| Native 3D fishing-spot beacon image | Partial - Web | The opt-in Web proof registered the existing transparent beacon asset, rendered it at the verified Sha Tin coordinate, and kept tap selection working. An API 35 profile proof also logged successful Android `addImageFromAssets`, but the centered screenshot remained circle-only (`tmp/native-spot-icon-centered-api35-r2.png`); MapLibre Android `0.3.5` therefore keeps the native circle fallback and tap contract. |
| Native player sprite candidate | Partial - opt-in Android | `FISHERGO_MAP_NATIVE_PLAYER_LAYER=true` registered the selected avatar with `addImageFromWidget` and kept startup functional. Warm API 35 motion p95 was `73/69 ms` versus a same-code disabled control of `61/105 ms`; the variance does not prove a stable win, and both remain above the 20 ms gate. Keep the flag disabled by default. Evidence: `tmp/android-map-benchmark-maplibre-native-player-warm-api35.json`, `tmp/android-map-benchmark-maplibre-native-player-warm-repeat2-api35.json`, `tmp/android-map-benchmark-maplibre-native-player-disabled-cold-api35.json`, and `tmp/android-map-benchmark-maplibre-native-player-disabled-warm-api35.json`. |
| Flutter vector fallback proof | Partial - faster candidate, gate still open | The same `assets/maps/hk_terrain_mvp.json` OSM/hydro dataset renders real roads, water geometry, buildings, GPS-centered 500m camera, rotation, and two fishing spots in a lightweight Flutter painter. The latest API 35 clean-install GameHome run measured Flutter p95 total 92 ms, p95 raster 30 ms, 94.17% janky, and no ANR; motion simplification reduced the long tail versus the earlier 244 ms result, but the 20 ms / jank gate remains open. |
| Rotation and compass | Pass locally | GameHome now exposes a dedicated 45-degree MapLibre bearing control below the compass; Web QA rotated four times with the player remaining centered, reset north, and recorded zero warning/error logs after reload. |
| Deterministic initial bearing | Pass locally | `GameMapLibre` exposes `initialBearing` and passes it to `MapOptions.initBearing`; the proof entrypoint accepts `FISHERGO_MAP_PROOF_BEARING`. API 35 runtime controls rendered the same Sha Tin roads, river, buildings, and player overlay at 0/90/180/270 degrees. The final 36 m extrusion-cap APK repeated the Sha Tin matrix and the Victoria Harbour matrix at all four bearings; at 270 degrees the Harbour marker remained tappable and the proof status changed to `已選擇 維港測試釣點`. Evidence: `tmp/map-proof-bearing-controls-api35.png`, `tmp/map-proof-bearing-90-controls-api35.png`, `tmp/map-proof-bearing-180-controls-api35.png`, `tmp/map-proof-bearing-270-controls-api35.png`, `tmp/shatin-height-cap-0.png`, `tmp/shatin-height-cap-90.png`, `tmp/shatin-height-cap-180.png`, `tmp/shatin-height-cap-270.png`, `tmp/victoria-height-cap-0.png`, `tmp/victoria-height-cap-90.png`, `tmp/victoria-height-cap-180.png`, `tmp/victoria-height-cap-270.png`, and `tmp/victoria-height-cap-270-selected.png`. |
| Mobile HUD layout | Pass | 390 x 844 Web QA and API 35 screenshots showed no clipping; the compass was moved below the map button to avoid the radar control. |
| API 35 smoke | Pass | On `emulator-5554`, fresh API 35 runs passed `startup_auth_flow_test.dart`, `fishing_minigame_flow_test.dart`, `daily_task_reward_flow_test.dart`, and `offline_reconnect_flow_test.dart`; API 23 remained excluded by preflight. |
| API 35 map rotation flow | Pass | `map_rotation_flow_test.dart` advanced the GameHome bearing semantics from 0° to 45° to 90° on `emulator-5554`; API 23 remained excluded by preflight. |
| API 35 GPS-centered spot selection | Pass | With `emu geo fix 114.109537072 22.354208013`, `map_spot_selection_flow_test.dart` rendered and tapped the verified 青衣公眾碼頭 marker after a 45° rotation, then asserted the live spot detail card; API 23 remained excluded. |
| Manual Android map benchmark | Contract pass; hosted run pending | `.github/workflows/android-map-benchmark.yml` fixes API 35, host-GPU rendering, map-readiness telemetry, one warm-up round, and uploads `tmp/android-map-benchmark-ci.json` plus `tmp/android-map-benchmark-ci.png`; `enforce_frame_budget` remains manual while the current p95 is above 20 ms. |
| Latest local host-GPU map benchmark | Valid trace; gate failed | On 2026-08-01, API 35 `emulator-5554` reported Intel UHD 630 host GPU, explicit location action and map readiness passed, `512` native frames, gfx p95/p99 `34/46 ms`, `40.82%` janky, Flutter total p95 `45 ms`, and no ANR. Evidence: `tmp/android-map-benchmark-grid-cache-api35-perf-20260801.json`. |
| MapLibre Native `13.4.1` dependency candidate | Reject - no stable motion gain | The official Android `13.4.1` release was build-compatible with the current `maplibre_android 0.3.5` plugin and passed map readiness on API 35 `emulator-5554`, but two matched one-round host-GPU runs both measured `p95 53 ms`, with p99 `69/89 ms`, jank `47.68%/48.60%`, and slow draw commands `78/84`. The two pinned `13.2.0` controls both measured `p95 48 ms`, p99 `65/65 ms`, jank `48.57%/48.75%`, and slow draw commands `95/94`. Keep the default at `13.2.0`; retain `13.4.1` only as historical evidence and do not add an OpenGL `13.4.1` production override. Reference: [MapLibre Android releases](https://github.com/maplibre/maplibre-native/releases). Evidence: `tmp/android-map-benchmark-maplibre-native-13.4.1-api35.json`, `tmp/android-map-benchmark-maplibre-native-13.4.1-repeat-20260801.json`, `tmp/android-map-benchmark-maplibre-native-13.2.0-control-20260801.json`, and `tmp/android-map-benchmark-maplibre-native-13.2.0-repeat-control-20260801.json`. |
| MapLibre Native Vulkan `13.4.1` candidate | Reject - slower readiness and no renderer win | A matched API 35 host-GPU pair completed MapLibre readiness with no ANR. Vulkan `13.4.1` measured `285` frames, p95/p99 `61/81 ms`, `48.42%` janky, `86` slow draw commands, `16` bitmap uploads, and readiness/style-idle `4217/4306 ms`; Vulkan `13.0.2` measured `285` frames, p95/p99 `65/89 ms`, `48.77%` janky, `78` slow draw commands, `18` bitmap uploads, and readiness/style-idle `1460/1654 ms`. The small p95 difference is not a stable product win, and both Vulkan runs remain worse than the retained OpenGL `13.2.0` baseline. Keep Vulkan default-off; `FISHERGO_MAP_VULKAN_VERSION` is diagnostic-only. Evidence: `tmp/android-map-benchmark-maplibre-vulkan-13.4.1-api35.json` and `tmp/android-map-benchmark-maplibre-vulkan-13.0.2-control-20260801.json`. |
| Native `WHEN_DIRTY` refresh diagnostic | Inconclusive; not a product proof | A fresh direct native MapLibre surface run with `RenderingRefreshMode.WHEN_DIRTY` measured p95 `21 ms`, p99 `250 ms`, `1.81%` janky, 496 valid frames, and no ANR on API 35 host GPU. Earlier matched repeats did not reproduce the p95 improvement, so this remains a diagnostic only. The Flutter MapLibre plugin also does not expose this MapView renderer setting. Evidence: `tmp/android-native-map-benchmark-when-dirty-restarted-api35.json` and the repeat analysis below. |
| Flutter `WHEN_DIRTY` integration candidate | Reject - platform composition invalid | A local MapLibre package fork safely avoided the TextureView exception by switching the opt-in candidate to SurfaceView, but both `tlhc_vd` and `hc` GameHome runs produced zero valid native gfx frames despite map readiness and Flutter telemetry; neither could meet the 60-frame evidence contract. The fork, dependency overrides, and flag plumbing were removed; the stable TextureView product path remains unchanged. Evidence: `tmp/android-map-benchmark-when-dirty-gamehome-api35.json` and `tmp/android-map-benchmark-when-dirty-hc-gamehome-api35.json`. |
| Water fill-outline removal diagnostic | Reject | Removing only the Android Game 3D water `fill-outline-color` reduced slow draw commands from `88` to `84` but worsened gfx p95 from `32` to `38 ms`, jank from `31.78%` to `38.88%`, and bitmap uploads from `10` to `16`; the style was restored. Evidence: `tmp/android-map-benchmark-water-outline-off.json`. |
| Startup auth integration | Pass | Fresh API 35 install test covers identity choice, local guest, skippable tutorial, and entry to GameHome; API 23 remains excluded. |
| Invalid API 23 exclusion | Pass | `tool/android_smoke_preflight.ps1` skipped `0123456789ABCDEF` and accepted only API 35. |
| Android p95 frame time | **Fail** | The final-restore GameHome profile APK with the retained 36 m 3D height cap, class-matched `road-main` layer, and pinned MapLibre Native `13.2.0` measured gfx p95 `42 ms` and a post-Vulkan-restore repeat measured `44 ms`; both were ANR-free API 35 host-GPU runs. A separate one-round warm candidate measured `31 ms`; none reaches the 20 ms gate, and the spread confirms the gate remains open. Evidence: `tmp/android-map-benchmark-maplibre-native-13.2.0-final-restore-api35.json`, `tmp/android-map-benchmark-maplibre-native-13.2.0-post-vulkan-restore-api35.json`, and `tmp/android-map-benchmark-maplibre-native-13.2.0-api35.json`. |
| Production-like benchmark boundary | Partial - measurement correction | A fresh API 35 host-GPU profile APK built with `FISHERGO_MAPLIBRE=true` and the Android 3D style, but without `FISHERGO_MAP_PERF`, measured gfx p95 `46 ms`, p99 `69 ms`, and no ANR after one warm-up round. This confirms the failing native metric is not caused only by the optional Flutter timings reporter; the 20 ms gate remains open. Evidence: `tmp/android-map-benchmark-production-like-no-perf-api35.json`. |
| Adaptive motion composition experiment | Reject - no stable gain | A temporary production experiment hid Flutter markers and GameHome HUD during MapLibre gesture events, then restored them at camera idle. Two identical API 35 host-GPU repeats measured gfx p95 `48/46 ms` and Flutter p95 total `50/57 ms`, versus the current `42/44 ms` baseline. The behavior was removed so map gestures do not cause visible HUD/marker disappearance; the JSON traces remain as rejected evidence. |
| HUD-only map-host isolation | Keep - structural optimization, gate unchanged | GameHome now keeps one stable `_GameHomeMapSurface` widget instance and sends only geographic state through a dedicated notifier; HUD-only `setState` calls no longer reconstruct the MapLibre host. Two API 35 host-GPU repeats measured gfx p95 `42/44 ms`, Flutter p95 total `64/55 ms`, and no ANR, so this is retained for rebuild isolation but does not close the native 20 ms motion gate. Evidence: `tmp/android-map-benchmark-map-state-isolation-api35.json` and `tmp/android-map-benchmark-map-state-isolation-api35-repeat.json`. |
| GPS-centered 500m cache warm-up | Partial - opt-in diagnostic | `FISHERGO_MAP_CACHE_WARMUP=true` downloads the current GPS-centered 500m region at zoom 14-16 after a 2-second debounce, reuses the same quantized grid on relaunch, and removes stale FisherGO warm-up regions. API 35 host-GPU GameHome runs measured p95 `42 ms` / `42 ms`, p99 `53 ms` / `65 ms`, janky `43.14%` / `45.19%`, and no app-specific ANR. The repeat emitted `warm-up hit` for grid `11191:57094`; the flag remains disabled by default because this does not close the 20 ms motion gate. Evidence: `tmp/android-map-benchmark-cache-warmup-api35.json` and `tmp/android-map-benchmark-cache-warmup-repeat-api35.json`. |
| Android major-road-only Game 3D style | Partial - accepted visual simplification | The Android Game 3D style now keeps OSM motorway/trunk/primary/secondary/tertiary roads and omits path/track/pedestrian/minor/service lines; water, waterways, piers, buildings, and fishing-spot overlays remain. Native SurfaceView p95 was `31/28 ms` with p99 `300/300 ms`; GameHome p95 was `42 ms`, p99 `61 ms`, and app-specific ANR false. This meets the product rule for readable major roads but does not close the 20 ms motion gate. Evidence: `tmp/android-native-map-benchmark-game-style-road-main-only-api35.json`, `tmp/android-native-map-benchmark-game-style-road-main-only-repeat-api35.json`, and `tmp/android-map-benchmark-gamehome-road-main-only-api35.json`. |
| Native `WHEN_DIRTY` refresh mode | Reject - no stable gain | The isolated MapLibre proof kept the same Game 3D style, camera, gestures, and host-GPU API 35 device while switching only `MapView.renderingRefreshMode` from the default continuous mode to `WHEN_DIRTY`. Control repeats measured p95/p99 `36/300 ms` and `36/300 ms`; candidate repeats measured `36/300 ms` and `36/300 ms`, with no ANR. The lower first-run jank (`5.54%` versus `9.00%`) did not repeat (`8.40%` versus `8.60%`), so the candidate remains profile-only and is not applied to the Flutter renderer. Evidence: `tmp/android-native-map-benchmark-refresh-control-api35.json`, `tmp/android-native-map-benchmark-refresh-control-repeat-api35.json`, `tmp/android-native-map-benchmark-refresh-when-dirty-api35.json`, and `tmp/android-native-map-benchmark-refresh-when-dirty-repeat-api35.json`. |
| Android line-motion geometry candidate | Reject - slower draw path | Preserving the same vector layers while changing `waterway`, `road-main`, and `pier` caps/joins from round to butt/miter increased the fresh API 35 host-GPU GameHome trace from the current `30 ms` p95 baseline to `31 ms`, jank from `23.29%` to `31.77%`, and slow draw commands from `58` to `95`; no ANR occurred. The opt-in style/configuration was removed. Evidence: `tmp/android-map-benchmark-android-line-motion-candidate-api35.json` and `tmp/android-map-benchmark-restarted-api35.json`. |
| Native Game 3D without building extrusion | Reject - diagnostic | Removing `building-3d` from the native proof style measured p95 `32 ms`, p99 `300 ms`, janky `3.87%`, average `41.07 FPS`, and no app-specific ANR. It did not improve the long tail, so the 3D building layer remains enabled for the gameplay map. Evidence: `tmp/android-native-map-benchmark-game-style-no-building-extrusion-api35.json`. |
| Readiness-to-motion correlation | Partial - diagnostic instrumentation | With `FISHERGO_MAP_PERF=true` and the benchmark's `-RequireMapReadiness` gate, style-ready/map-idle was `2.82/2.90 s` and `2.57/2.57 s` across two API 35 repeats. After readiness, Flutter p95 total/raster/vsync were `50/22/32 ms` and `55/23/35 ms`; native gfx p95/p99 were `42/113 ms` and `46/61 ms`, with no ANR. Readiness is now explicitly observed before motion capture, but the p99 spread remains emulator composition variance; keep performance instrumentation opt-in and the 20 ms gate open. Evidence: `tmp/android-map-benchmark-profile-perf-readiness-gated-api35.json` and `tmp/android-map-benchmark-profile-perf-readiness-gated-repeat-api35.json`. |
| HUD-less composition control | Partial - diagnostic evidence | `FISHERGO_MAP_HUD_COMPOSITION_DIAGNOSTIC=true` keeps the same MapLibre surface, GPS, and map gestures while hiding GameHome HUD widgets. Two readiness-gated API 35 host-GPU runs measured native gfx p95/p99 `36/53 ms` and `44/61 ms`; Flutter p95 total/raster/vsync `45/18/27 ms` and `45/20/27 ms`; no ANR. This proves the HUD contributes measurable composition cost, but the map surface still misses the 20 ms gate. The flag remains disabled by default. Evidence: `tmp/android-map-benchmark-profile-no-hud-composition-api35.json` and `tmp/android-map-benchmark-profile-no-hud-composition-repeat-api35.json`. |
| HUD `RepaintBoundary` experiment | Reject - no stable gain | Wrapping the full production HUD in one `RepaintBoundary` measured Flutter p95 total `58/54 ms`, vsync `38/33 ms`, and native gfx p95 `46/42 ms` across two repeats, with no ANR. It did not beat the HUD-less control or establish a stable improvement over the original HUD, so the wrapper was removed. Evidence: `tmp/android-map-benchmark-profile-hud-repaint-boundary-api35.json` and `tmp/android-map-benchmark-profile-hud-repaint-boundary-repeat-api35.json`. |
| HUD selective composition controls | Partial - diagnostic evidence | `FISHERGO_MAP_HUD_PROFILE` can hide navigation, utility, or bottom HUD groups while retaining the same MapLibre surface, GPS, and map gestures. Readiness-gated API 35 host-GPU runs measured navigation native gfx p95/p99 `40/46 ms` and Flutter p95 total/vsync `47/31 ms`; utility `40/61 ms` and `53/33 ms`; bottom `44/57 ms` and `56/33 ms`; no ANR in any run. No group produced a stable improvement over the no-HUD control, so no production widget change is accepted yet. The profiles remain disabled by default. Evidence: `tmp/android-map-benchmark-profile-hud-navigation-api35.json`, `tmp/android-map-benchmark-profile-hud-utility-api35.json`, and `tmp/android-map-benchmark-profile-hud-bottom-api35.json`. |
| HUD per-widget attribution controls | Reject - no stable micro-optimization | Child profiles for `bottom-bar`, `announcement`, and `side` were measured with the same readiness-gated API 35 host-GPU harness. Native gfx p95 was `44/44/44 ms`; Flutter p95 total/vsync was `52/32 ms`, `55/32 ms`, and `53/32 ms`; no ANR. The differences remain within the observed emulator variance and none beats the no-HUD control, so no repaint/build change is promoted. Child profiles remain opt-in and default to `none`. Evidence: `tmp/android-map-benchmark-profile-hud-bottom-bar-api35.json`, `tmp/android-map-benchmark-profile-hud-announcement-api35.json`, and `tmp/android-map-benchmark-profile-hud-side-api35.json`. |

The benchmark harness now treats a missing installed package as a clear
precondition failure and retries transient `uiautomator` `null root` output
without converting the diagnostic stderr into a terminating PowerShell error.
This keeps future Android performance comparisons reproducible; it does not
change the failing MapLibre performance result above. The attached API 35
photo-frame device remains excluded by preflight.

| Web 30 FPS | **Fail locally; manual CI gate added** | The corrected gameplay-shell runner enters guest mode, skips the tutorial, waits for the MapLibre canvas, verifies a populated final PNG map region, and then measures motion. The restored production-like release build without `FISHERGO_MAP_PERF` measured 37.03 FPS / p95 50 ms / 26.88% jank at 390x844 and 13.83 FPS / p95 116.7 ms / 69.57% jank at 1440x900; both screenshots passed `map_visual_proof`, but neither meets the motion budget. Evidence: `tmp/web-map-benchmark-proof-default-390.json`, `tmp/web-map-benchmark-proof-default-1440.json`, `output/playwright/web-map-proof-390x844.png`, and `output/playwright/web-map-proof-1440x900.png`. |
| Web benchmark startup fidelity | Pass as tooling behavior | Playwright now enables Flutter Web semantics, clicks `訪客遊玩`, clicks `略過` when the tutorial is present, grants a fixed Sha Tin geolocation in each isolated browser context, waits for `flutter-view` and `.maplibregl-canvas`, records OpenFreeMap tile responses, and verifies the final PNG map region is populated. The captured 390x844 and 1440x900 screenshots show the gameplay HUD and OSM map without the login modal or GPS-permission race. |
| Web MapLibre render tuning | Partial improvement; enabled by default | `web/maplibre_render_tuning.js` disables unused symbol collision/fade work, expired-tile refresh, world copies, and overscaled reparse work while preserving the same full OSM style. Populated-map matched traces improved 390x844 from 39.39 to 47.89 FPS and 1440x900 from 12.74 to 20.56 FPS; the repeat reached 21.00 FPS. p95/jank remain above budget, so this is accepted as a stable improvement but not gate closure. Evidence: `tmp/web-map-benchmark-render-tuning-baseline-390.json`, `tmp/web-map-benchmark-render-tuning-tuned-390.json`, `tmp/web-map-benchmark-render-tuning-baseline-1440.json`, `tmp/web-map-benchmark-render-tuning-tuned-1440.json`, and `tmp/web-map-benchmark-render-tuning-tuned-1440-repeat.json`. |
| Web desynchronized WebGL context candidate | Partial improvement; keep query-gated | `?fishergo_desynchronized=1` keeps the same populated OSM map while setting WebGL `desynchronized:true`. Full-style traces measured 54.31 FPS / p95 33.3 ms / 4.41% jank at 390x844 and 27.92 FPS / p95 150 ms / 20.86% jank at 1440x900; a 390 repeat measured 54.01 FPS / p95 33.4 ms / 5.19% jank. The desktop p95 regression and mobile repeat miss mean it is not a default promotion, but the query-gated fallback remains available for follow-up browser/device testing. Evidence: `tmp/web-map-benchmark-desynchronized-390.json`, `tmp/web-map-benchmark-desynchronized-390-repeat.json`, and `tmp/web-map-benchmark-desynchronized-1440.json`. |
| Web road-detail simplification candidate | Partial improvement; keep query-gated | `?fishergo_road_simplify=1` removes only path/minor-road casing/minor-road layers while retaining major/medium roads, water, buildings, piers, and the player overlay. Same-build control/candidate traces kept populated map proof; 1440x900 moved from `20.15 FPS` / p95 `116.7 ms` to `24.22 FPS` / p95 `100 ms`, with a repeat at `22.18 FPS` / p95 `100 ms`. Jank remained above budget (`42.00%` control, `38.52%` first candidate, `43.64%` repeat), so it is not default-promoted. Evidence: `tmp/web-map-benchmark-road-control-390-1440.json`, `tmp/web-map-benchmark-road-simplify-390-1440.json`, `tmp/web-map-benchmark-road-simplify-390-1440-repeat.json`, and `output/playwright/web-map-proof-road-simplify-1440x900.png`. |
| Web no-extrusion + road simplification candidate | Partial improvement; keep query-gated | `?fishergo_web_no_extrusion=1&fishergo_road_simplify=1` removes only `building-3d` plus path/minor-road layers, preserving building footprints, water, waterways, major/medium roads, piers, and populated map proof. Same-build desktop control measured `20.40 FPS` / p95 `116.7 ms` / `42.72%` jank; candidate repeats measured `31.15/31.58 FPS` / p95 `83.3 ms` / `32.90/29.30%` jank. Mobile repeats stayed populated at `53.74-54.64 FPS`; desktop p95/jank still fail, so this is not the default style. Evidence: `tmp/web-map-benchmark-extrusion-control-390-1440.json`, `tmp/web-map-benchmark-extrusion-road-combined-390-1440.json`, `tmp/web-map-benchmark-extrusion-road-repeat-390-1440.json`, and `output/playwright/web-map-proof-extrusion-road-repeat-1440x900.png`. |
| Web surface simplification candidate | Reject - visual proof failure | Removing `landuse`, `farmland`, `grass`, `wood`, and `park` layers reached `35.99 FPS` at 1440x900 but reduced the 390x844 map proof to six sampled colors and failed the populated-map invariant; desktop p95/jank also remained `66.7 ms` / `27.22%`. The diagnostic was removed. Evidence: `tmp/web-map-benchmark-extrusion-road-surface-390-1440.json`. |
| Web landcover fill compaction | Reject - no stable motion improvement | A temporary `landcover` fill merge preserved OpenFreeMap tile responses, real geometry, and both structural goldens, but the matched v2 run measured `34.83 FPS` / `66.7 ms` / `25.86%` jank at 1440x900 versus `36.15 FPS` / `66.7 ms` / `25.00%`; mobile also moved from `52.11 FPS` / `5.77%` jank to `55.70 FPS` / `3.60%` while p95 remained `33.3-33.4 ms`. The query hook was removed after the desktop regression. Evidence: `tmp/web-map-benchmark-landcover-merge-control-v2-390-1440.json` and `tmp/web-map-benchmark-landcover-merge-candidate-v2-390-1440.json`. |
| Web antialias-disabled context candidate | Reject - no desktop improvement | Query-gated `?fishergo_antialias=0` preserved populated map proof, but the matched 1440x900 trace moved only from `20.82` to `21.01 FPS`; p95 stayed `116.7/116.6 ms`, jank `40.38%/40.95%`, and bounded long tasks stayed `42/43`. The candidate was removed after the A/B run. Evidence: `tmp/web-map-benchmark-antialias-control-390-1440.json` and `tmp/web-map-benchmark-antialias-candidate-390-1440.json`. |
| Web low-power plus desynchronized candidate | Reject as a combined gate fix | Combining `FISHERGO_MAP_LOW_POWER=true` with the desynchronized context preserved populated proof and passed one 390x844 sample at 52.18 FPS / p95 33.3 ms / 5.00% jank, but 1440x900 measured 28.18 FPS / p95 99.9 ms / 34.29% jank. It does not close the desktop motion gate; keep the two controls independent and opt-in. Evidence: `tmp/web-map-benchmark-low-power-desync-390.json` and `tmp/web-map-benchmark-low-power-desync-1440.json`. |
| Web bounded long-task profiling | Pass as diagnostic tooling | The gameplay runner now records supported `PerformanceObserver('longtask')` entries bounded strictly to the 5-second frame window. The current full-style 1440x900 baseline recorded 42 main-thread long tasks, 4,120 ms total, and a 140 ms maximum while the map PNG proof remained populated. This is attribution evidence, not a motion-gate pass. Evidence: `tmp/web-map-benchmark-longtask-bounded-1440.json`. |
| Web benchmark dependency and current repeat | Pass as reproducible tooling; motion gate still fails | With the pinned Playwright `1.55.0` dependency and the latest full-style build, the local runner recorded populated map proof at 390x844 with `47.04 FPS`, p95 `49.9 ms`, and `13.19%` jank; 1440x900 recorded `20.74 FPS`, p95 `116.7 ms`, and `41.35%` jank. The desktop trace contained 43 bounded long tasks totaling `4,154 ms`, maximum `131 ms`. Evidence: `tmp/web-map-benchmark-current-20260730.json`, `output/playwright/web-map-proof-390x844.png`, and `output/playwright/web-map-proof-1440x900.png`. |
| Web deterministic GPS repeat | Pass as measurement tooling; desktop motion gate still fails | The current release was rerun with a fixed browser geolocation and both final PNG proofs populated. The 390x844 trace measured `56.68 FPS`, p95 `33.3 ms`, and `0.71%` jank; 1440x900 measured `42.88 FPS`, p95 `50.0 ms`, and `17.29%` jank. This replaces the earlier 390px permission-race failure as the current repeat, but does not close the desktop gate. Evidence: `tmp/web-map-benchmark-current-20260801-geolocation.json`, `output/playwright/web-map-proof-390x844.png`, and `output/playwright/web-map-proof-1440x900.png`. |
| Web structural visual golden | Pass; motion gate remains independent | The benchmark now loads `test/goldens/game_map/manifest.json` and validates both 390x844 and 1440x900 screenshots for fixed dimensions, minimum colour diversity/range, adjacent-sample change, dominant-colour ceiling, and a successful OpenFreeMap response. The current release passed with `adjacent_change_ratio 0.3721` / `0.5872`, dominant sample ratio `0.4896` / `0.25`, and populated proof at both viewports. This rejects blank, single-colour, or non-map canvases without freezing live OSM pixels. Evidence: `tmp/web-map-benchmark-visual-golden-20260801.json`, `test/goldens/game_map/manifest.json`, and `.github/workflows/web-map-benchmark.yml`. |
| Web marker projection point cache | Keep - no visual regression; desktop motion gate still fails | The current source with cached marker geographic points kept populated OSM proofs and measured `57.66 FPS`, p95 `16.8 ms`, and `1.74%` jank at 390x844; 1440x900 measured `43.28 FPS`, p95 `50.0 ms`, and `17.97%` jank. The wide-screen tail remains MapLibre-dominated, so the cache is retained for allocation stability but is not treated as a Web gate closure. Evidence: `tmp/web-map-benchmark-marker-point-cache-20260801.json`, `output/playwright/web-map-proof-390x844.png`, and `output/playwright/web-map-proof-1440x900.png`. |
| Web worker-count candidate | Reject - no motion improvement | A query-gated `workerCount=2` control preserved populated OSM map proof but measured 47.48 FPS / p95 33.4 ms / 12.24% jank at 390x844 versus the same-build default 47.40 FPS / p95 33.4 ms / 12.71%; at 1440x900 it measured 20.20 FPS / p95 116.7 ms / 42.57% versus default 20.58 FPS / p95 116.7 ms / 41.18%. The override was removed and MapLibre's default worker selection remains in production. Evidence: `tmp/web-map-benchmark-worker-default-390.json`, `tmp/web-map-benchmark-worker-2-390.json`, `tmp/web-map-benchmark-worker-default-1440.json`, and `tmp/web-map-benchmark-worker-2-1440.json`. |
| Web Wasm runtime candidate | Reject - gameplay startup failure | An isolated `flutter build web --wasm` completed into `build/web-wasm`, but Chromium emitted repeated `UnimplementedError` page errors and the formal 390x844 runner could not find the `訪客遊玩` entry within 15 seconds. Because the app did not reach a valid identity/tutorial/map flow, no Wasm motion result is admissible; keep the JavaScript build as the supported Web release path. |
| Web tile-cache depth candidate | Reject - no stable motion improvement | The query-gated `?fishergo_tile_cache_levels=3` kept the same OpenFreeMap source and passed the populated visual golden at both viewports. Same-build control/candidate measured `56.15/56.56 FPS` and `1.42/3.19%` jank at 390x844, while 1440x900 moved from `42.08 FPS` / `17.62%` jank to `41.67 FPS` / `18.75%`; the repeat remained worse at `41.40 FPS` / `18.93%` jank. Keep the gate available for diagnostics, but retain MapLibre's default dynamic cache policy in production. Evidence: `tmp/web-map-benchmark-tile-cache-control-390-1440-20260801.json`, `tmp/web-map-benchmark-tile-cache-3-390-1440-20260801.json`, and `tmp/web-map-benchmark-tile-cache-3-repeat-390-1440-20260801.json`. |
| Web fresh-guest startup overlay race | Fixed and production-verified; desktop motion gate remains open | Anonymous auth callbacks could race the explicit guest dialog `pop`, leaving the identity dialog and tutorial stack visible together. The startup gate now serializes the initial auth callback, identity dialog, and tutorial dialog; the semantics benchmark also retries cold-browser promotion. API 35 fresh-install startup smoke and the final production browser smoke passed guest entry, tutorial skip, populated OpenFreeMap visual golden, and map readiness. The final production trace measured `53.06 FPS` / p95 `33.3 ms` / `4.14%` jank at 390x844 and `38.33 FPS` / p95 `66.7 ms` / `20.94%` jank at 1440x900, so only the desktop motion budget remains open. Evidence: `tmp/web-map-benchmark-production-20260801-final.json`, `output/playwright/web-map-proof-390x844.png`, and `output/playwright/web-map-proof-1440x900.png`. |
| Web no-extrusion motion fallback | Historical partial improvement | The earlier `FISHERGO_MAP_WEB_MOTION=true` candidate removed only `building-3d` while retaining building footprints, land-use, roads, waterways, coastline, and piers. It improved motion but left desktop p95/jank above budget; the later default candidate also removes path/minor-road and duplicate casing layers. Evidence remains `tmp/web-map-benchmark-web-motion-390.json`, `tmp/web-map-benchmark-web-motion-1440.json`, and `tmp/web-map-benchmark-web-motion-1440-repeat.json`. |
| Web main-road motion default | Partial improvement; gate still open | Web now defaults to the no-extrusion style with path/minor-road and duplicate casing layers removed. It retains building footprints, water, waterways, medium/major roads, piers, and populated-map proof. The matched 2026-07-30 run measured `52.39 FPS` / p95 `33.4 ms` / `7.25%` jank at 390x844 and `30.23 FPS` / p95 `83.3 ms` / `32.89%` jank at 1440x900. This materially improves the prior motion candidate and keeps the map readable, but desktop p95/jank remain above the release budget. Set `FISHERGO_MAP_WEB_MOTION=false` to opt back into the rich full layer set. Evidence: `tmp/web-map-benchmark-main-roads-20260730.json` and `output/playwright/web-map-proof-1440x900.png`. |
| Web main-roads-only query candidate | Reject - slower and visually sparse | Removing only `road-medium` while retaining water, land, major roads, and the populated-map invariant reduced the matched 1440x900 trace to `39.77 FPS` / p95 `50.1 ms` / `22.61%` jank versus the marker-cache control's `43.28 FPS` / `50.0 ms` / `17.97%`; the 390x844 proof fell to 10 sampled colors. The query-gated experiment was removed, and medium roads remain in the accepted Web style. Evidence: `tmp/web-map-benchmark-main-roads-only-20260801.json`. |
| Web adaptive pixel ratio | Partial improvement; accepted wide-screen preset | The Web tuning wrapper now keeps mobile at native resolution and applies MapLibre's `pixelRatio: 0.75` only at `>=1024px` (or high-DPI widths `>=768px`), while preserving the same vector source, camera, roads, water, buildings, and populated-map proof. The matched explicit `0.75` repeat measured `57.80 FPS` / p95 `16.8 ms` / `1.04%` jank at 390x844 and `42.09 FPS` / p95 `66.6 ms` / `17.06%` jank at 1440x900; the adaptive default measured `39.67 FPS` / p95 `66.7 ms` / `18.69%` jank at 1440x900. `0.5` was rejected because the 390px visual proof became unpopulated. Desktop p95/jank remain above budget, but the wide-screen canvas cost is materially lower without weakening geography. Query `?fishergo_pixel_ratio=1` restores native resolution for A/B. Evidence: `tmp/web-map-benchmark-pixel-ratio-075-repeat-390-1440.json`, `tmp/web-map-benchmark-adaptive-pixel-ratio-default-390-1440.json`, and `tmp/web-map-benchmark-pixel-ratio-050-390-1440.json`. |
| Web fill-antialias candidate | Reject - no desktop gate improvement and weaker mobile detail | A matched `?fishergo_fill_antialias=0` style clone preserved populated OSM proof and raised one desktop sample from `42.56` to `43.71 FPS`, but p95 stayed `50.1 ms`, jank moved from `17.37%` to `17.81%`, and mobile p95 worsened from `16.8` to `33.3 ms`. The visual proof also fell from 23 to 9 sampled colors at 390x844. The query hook and source contract were removed; accepted fill antialiasing remains unchanged. Evidence: `tmp/web-map-benchmark-fill-antialias-control-20260801.json` and `tmp/web-map-benchmark-fill-antialias-candidate-20260801.json`. |
| Web wide-screen pixel ratio 0.5 / 0.625 candidates | Reject - no stable gate improvement; keep 0.75 default | Both candidates preserved OpenFreeMap roads, water, coastline, buildings, and populated visual proof at 1440x900. The 0.5 repeat measured `37.77 FPS` / p95 `50 ms` / `26.6%` jank and visibly softened fine road/detail edges; the 0.625 repeat measured `35.07 FPS` / p95 `66.6 ms` / `32.0%` jank. Neither closes the desktop motion gate, and lower ratios weaken visual sharpness, so no production change was made. Evidence: `tmp/web-map-benchmark-pixel-ratio-050-1440-repeat-20260730.json`, `tmp/web-map-benchmark-pixel-ratio-0625-1440-20260730.json`, and `output/playwright/web-map-proof-1440x900.png`. |
| Web gesture-time layer visibility swap | Reject - style mutation worsens motion | A query-gated `movestart`/`moveend` experiment hid `building-3d` during gestures and restored it at idle. Populated-map proof remained valid, but 390x844 fell to 42.44 FPS / p95 49.9 ms / 14.08% jank and 1440x900 fell to 17.29 FPS / p95 100 ms / 74.42% jank with p50 66.7 ms. The experiment was removed; do not mutate style visibility per gesture. Evidence: `tmp/web-map-benchmark-motion-layers-390.json` and `tmp/web-map-benchmark-motion-layers-1440.json`. |
| Web native fishing-spot layer motion | Reject as a performance fix; correctness retained | `FISHERGO_MAP_NATIVE_SPOT_LAYER=true` moved spot circles/labels into MapLibre-owned layers and preserved the populated OSM proof, but measured 46.94 FPS / p95 33.4 ms / 12.77% jank at 390x844 and 20.39 FPS / p95 116.7 ms / 42.57% jank at 1440x900. The existing native-layer correctness proof remains available, but it is not promoted as a Web motion optimization. Evidence: `tmp/web-map-benchmark-native-spots-390.json` and `tmp/web-map-benchmark-native-spots-1440.json`. |
| Web Flutter-marker isolation | Reject as a performance fix | `FISHERGO_MAP_MARKERS=false` removed both the player and Flutter fishing-spot overlay from the same full-style build. Map proof stayed populated, while motion measured 48.24 FPS / p95 33.4 ms / 9.96% jank at 390x844 and 20.30 FPS / p95 116.7 ms / 43.14% jank at 1440x900. The unchanged desktop tail confirms the primary bottleneck is MapLibre render/composition rather than marker widgets; markers remain enabled for gameplay correctness. Evidence: `tmp/web-map-benchmark-markers-off-390.json` and `tmp/web-map-benchmark-markers-off-1440.json`. |
| Web HUD-less composition diagnostic | Partial attribution; no production change | `FISHERGO_MAP_HUD_COMPOSITION_DIAGNOSTIC=true` improved the corrected 1440x900 gameplay trace only from 12.68 to 13.90 FPS; p95 stayed 133.4 ms and jank remained 60.87%. The map renderer/tile/style path remains the dominant tail, so the HUD diagnostic stays opt-in. Evidence: `tmp/web-map-benchmark-gameplay-hudless-1440.json`. |
| Web telemetry-off control | Reject as measurement explanation | The same production-like build has no `FISHERGO_MAP_PERF` callback, so the Web gate failure is not caused by optional Flutter timing instrumentation. An earlier telemetry-enabled trace was also collected for diagnostic attribution in `tmp/web-map-benchmark-local-41973.json`; its pre-fix report flag is not used as pass/fail evidence. |
| Web frame-budget enforcement | Pass as tooling behavior | A single 390x844 run with `--enforce-frame-budget` returned exit code 1 and retained `frame_budget_passed: false` in the JSON artifact, proving the manual gate can block a failing trace. Evidence: `tmp/web-map-benchmark-enforced.json`. |
| Web compact-style diagnostic | Partial; keep opt-in | `FISHERGO_MAP_COMPACT=true` keeps OSM water, roads, piers and building fills. With populated-map proof, it measured 46.39 FPS / p95 33.4 ms / 12.93% jank at 390x844 and 20.75 FPS / p95 83.4 ms / 64.08% jank at 1440x900. It remains an opt-in fallback rather than the Web default because p95/jank still fail. Evidence: `tmp/web-map-benchmark-compact-proof-390.json` and `tmp/web-map-benchmark-compact-proof-1440.json`. |
| Web maxzoom/adaptive style candidate | Reject - blank map proof | Capping the OpenFreeMap source at `maxzoom: 15` and selecting compact style for wide Web viewports produced HTTP 200 tile responses but the final map-only PNG contained only 3 sampled colors, proving the map was visually unpopulated. The corrected runner now records `map_visual_proof` and fails this case instead of accepting the FPS numbers. Evidence: `tmp/web-map-benchmark-adaptive-screenshot-proof.json` and `output/playwright/web-map-proof-1440x900.png`. |
| Web local OSM GeoJSON candidate | Reject - insufficient coverage and slower motion | A temporary local-source build loaded the bundled 3.33 MiB / 6,873-feature OSM GeoJSON asset successfully, but the default GPS center showed broad land with missing roads and coastline. Corrected gameplay traces measured 29.20 FPS / p95 116.7 ms / 19.18% jank at 390x844 and 17.43 FPS / p95 199.9 ms / 51.14% jank at 1440x900. The source, generator, and asset were removed; OpenFreeMap remains the production source. Evidence: `tmp/web-map-benchmark-local-geometry-390.json` and `tmp/web-map-benchmark-local-geometry.json`. |
| Web low-power-style diagnostic | Partial improvement; keep opt-in fallback | `FISHERGO_MAP_LOW_POWER=true` with the accepted default Web render tuning measured 51.12 FPS / p95 33.4 ms / 7.06% jank at 390x844 and 30.41 FPS / p95 83.3 ms / 36.60% jank at 1440x900. The populated-map PNG proof retained OSM roads, waterways, coastline, and terrain, but desktop p95/jank still miss the 33.3 ms / 5% motion gate. Keep low-power geometry opt-in while the measured main-road motion style remains the Web default. Evidence: `tmp/web-map-benchmark-low-power-tuned-390.json`, `tmp/web-map-benchmark-low-power-tuned-1440.json`, and `output/playwright/web-map-proof-1440x900.png`. |
| Web pitch 30 diagnostic | Reject; default remains 45 degrees | `FISHERGO_MAP_WEB_PITCH=30` preserved the real MapLibre map and gestures but measured 11.15 FPS / p95 150.1 ms / 80% jank at 1440x900, with no FPS gain over the production-like 45-degree control. The diagnostic setting was removed after the A/B run. Evidence: `tmp/web-map-benchmark-web-pitch30.json`. |
| Victoria Harbour topology | Pass locally | MapLibre proof at `22.2934,114.1719` rendered open water, coastline, piers, roads, buildings, and the Harbour test spot on Android and Web. API 35 runtime evidence covered 0/90/180/270 degrees with the player and spot overlay anchored, then selected the Harbour spot at 270 degrees. The final height-cap repetition is stored in `tmp/victoria-height-cap-0.png`, `tmp/victoria-height-cap-90.png`, `tmp/victoria-height-cap-180.png`, `tmp/victoria-height-cap-270.png`, and `tmp/victoria-height-cap-270-selected.png`; Web evidence remains `.playwright-cli/page-2026-07-18T08-35-58-250Z.png`. |
| MapLibre Web console | Pass locally | After pinning PMTiles `4.3.0` in `web/index.html`, the Victoria Harbour proof reported `Errors: 0, Warnings: 0`; readiness was 605 ms / 606 ms. |
| Tile load time | Partial - local | Readiness telemetry now records style-ready and map-idle latency. API 35 measured 1.742 s / 1.831 s on clean install and 0.656 s / 0.673 s with cache; Web measured 0.829 s / 0.960 s at 390x844, 0.396 s / 0.452 s at 1440x900, and 0.605 s / 0.606 s at the Victoria Harbour proof viewport. |
| Licensing and operations | Open | Attribution is displayed. A production SLA and operating-risk decision are still required. |

The harness now accepts `-MaxP95Ms 20 -EnforceFrameBudget` for an explicit
release-candidate gate while leaving exploratory diagnostics non-failing. A
fresh host-GPU API 35 run on 2026-07-22 produced a valid 598-frame trace with
gfx p95 `31 ms`, `26.92%` janky frames, and no ANR; the enforced gate rejected
the run with exit `1` and wrote
`tmp/android-map-benchmark-host-gpu-budget-gate-current.json` with
`frame_budget_passed: false`. Enforced runs also reject a missing p95 metric,
so an incomplete trace cannot be mistaken for a pass. This proves the guard is
active, not that the MapLibre motion target has been reached.

### Android Profile Benchmark

Environment:

- FisherGO API 35 x86_64 emulator
- Host GPU
- Profile APK
- GameHome zoom 16.0 and pitch 45 degrees; Android uses the compact style by default and Web/full-style proof uses the richer style
- Twelve scripted 350 ms map swipes
- `dumpsys gfxinfo com.fishergo.app`

The official repeatable command now adds `-RequireHostGpu`. On 2026-07-22 the
AVD's persisted config reported `hw.gpu.enabled=no` and SurfaceFlinger used
SwiftShader; that run is retained as a software-rendering diagnostic, not as
the Android renderer gate. A fresh API 35 `FisherGO_API35` launch with
`-gpu host` reported an Intel UHD Graphics 630 GLES renderer and is the valid
host-GPU environment for the current evidence below.

| Variant | p50 | p95 | Decision |
| --- | ---: | ---: | --- |
| OpenFreeMap Liberty style | 22 ms | 73 ms | Reject |
| FisherGO slim 18-layer style, texture layer hybrid composition | 8 ms | 32 ms | Current best |
| FisherGO slim 18-layer style, hybrid composition | 21 ms | 53 ms | Reject |
| FisherGO merged 12-layer expression style | 11 ms | 46 ms | Reject |

The 32 ms result was a one-off best result, not a repeatable release result.
Three subsequent final-style runs measured:

| Run | p50 | p95 | Janky frames |
| --- | ---: | ---: | ---: |
| 1 | 24 ms | 77 ms | 50.00% |
| 2 | 28 ms | 125 ms | 49.37% |
| 3 | 34 ms | 105 ms | 48.08% |

The profile repeat-run median p95 is 105 ms. A production-equivalent x86_64
release APK improved the result but still failed the gate:

| Release run | p50 | p95 | Janky frames |
| --- | ---: | ---: | ---: |
| 1 | 19 ms | 69 ms | 47.03% |
| 2 | 19 ms | 57 ms | 47.81% |
| 3 | 19 ms | 57 ms | 49.53% |

The release median p95 is 57 ms after placing Flutter marker subtrees behind
`RepaintBoundary`, down slightly from 61 ms without marker caching. The
12-layer version was also slower in its one-off comparison because per-feature
expression evaluation outweighed the reduced layer count. The source therefore
retains the simpler 18-layer style, cached Flutter markers, and explicit texture
layer hybrid composition while the performance gate stays open.

The current repeatable API 35 baseline uses a clean install for every run on
`emulator-5554`, the profile proof APK, and the same fixed twelve-swipe
sequence:

| Run | Frames | p50 | p95 | Janky | Slow draw commands |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 182 | 24 ms | 93 ms | 50.00% | 66 |
| 2 | 212 | 20 ms | 77 ms | 49.53% | 88 |
| 3 | 194 | 20 ms | 73 ms | 50.00% | 74 |
| 4 | 173 | 23 ms | 97 ms | 49.71% | 68 |

The four-run median p95 is `85 ms`, so the performance gate remains failed. The
latest production-aligned zoom 16 cold and cached traces are recorded below;
the same fixed swipe sequence is now available through
`tool/android_map_benchmark.ps1`, which also runs the API preflight, cleanly
installs the APK, clears stale logcat entries, and writes JSON evidence when
`-OutputPath` is supplied.

Current source rerun on 2026-07-22 used the host-GPU API 35 emulator and the
guarded benchmark command:

```text
powershell -ExecutionPolicy Bypass -File tool/android_map_benchmark.ps1
  -DeviceSerial emulator-5554 -MinimumApi 35 -WarmupRounds 1
  -RequireHostGpu -OutputPath tmp/android-map-benchmark-host-gpu-*.json
```

| Run | Install state | Frames | p50 | p95 | Janky | Slow draw commands | ANR |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Compact baseline | Clean install | 757 | 7 ms | 30 ms | 15.98% | 66 | False |
| Compact baseline | Existing install | 702 | 8 ms | 31 ms | 18.23% | 69 | False |
| Compact baseline after guard | Clean install | 748 | 8 ms | 30 ms | 19.52% | 93 | False |
| Default after diagnostics | Clean install | 716 | 7 ms | 30 ms | 19.97% | 75 | False |
| `tlhc_hc` diagnostic | Clean install | 1035 | 6 ms | 29 ms | 13.82% | 79 | False |
| `tlhc_hc` diagnostic | Existing install | 730 | 7 ms | 30 ms | 16.44% | 67 | False |
| Native pixel ratio `0.75` diagnostic | Clean install | 786 | 7 ms | 28 ms | 30.79% | 56 | False |
| Native pixel ratio `0.75` diagnostic | Existing install | 801 | 5 ms | 24 ms | 31.21% | 35 | False |
| Native tile LOD scale `0.75` diagnostic | Clean install | 682 | 8 ms | 31 ms | 20.67% | 93 | False |
| Texture off diagnostic | Clean install | 0 | n/a | n/a | n/a | n/a | False |
| Previous SwiftShader baseline | Clean install | 186 | 31 ms | 105 ms | 49.46% | 82 | False |

The host-GPU run is a materially better measurement, but p95 remains above the
20 ms gate. The minimal water/road-only style candidate measured p95 29 ms
with slower style readiness and higher jank, so it was removed rather than
making the gameplay map visually poorer. Evidence:
`tmp/android-map-benchmark-host-gpu-compact-baseline-warm1.json`,
`tmp/android-map-benchmark-host-gpu-guarded-baseline.json`, and
`tmp/android-map-benchmark-host-gpu-motion-candidate-warm1.json`.

After the fail-closed harness change, a normal texture-on control still
produced a valid trace: gfx p95 `30 ms`, Flutter p95 total `30 ms`, janky
`19.52%`, and no ANR. Evidence:
`tmp/android-map-benchmark-host-gpu-texture-on-post-guard.json` and
`tmp/android-host-gpu-texture-on-post-current.png`.

After removing the temporary native experiments and rebuilding the default
profile APK, the clean-install control again produced a valid trace: gfx p95
`30 ms`, Flutter p95 total `31 ms`, janky `19.97%`, and no ANR. Evidence:
`tmp/android-map-benchmark-host-gpu-default-after-diagnostics.json`.

The `tlhc_hc` diagnostic kept the complete map composition correct: the host-GPU
proof screenshot showed roads, waterways, buildings, the selected avatar, HUD,
and compass controls. Its clean-install run recorded Flutter p95 total `27 ms`
and MapLibre gfx p95 `29 ms`; the existing-install repeat recorded Flutter p95
total `29 ms` and gfx p95 `30 ms`. This is a small, non-stable improvement over
the `tlhc_vd` baseline, not a release decision, so `tlhc_vd` remains the
default. Evidence: `tmp/android-map-benchmark-host-gpu-hc-baseline-warm1.json`,
`tmp/android-map-benchmark-host-gpu-hc-baseline-warm-repeat2.json`, and
`tmp/android-host-gpu-hc-current.png`.

The host-GPU texture-off diagnostic is invalid for gameplay: Flutter telemetry
looked faster, but the screenshot contained only the MapLibre base map; the
avatar, HUD, compass, and interaction overlay were absent. Android
`gfxinfo` reported zero frames, so the benchmark now emits
`gfx_trace_valid=false`, clears the native frame metrics, writes the evidence,
and exits non-zero instead of treating the sentinel `4950 ms` percentile as a
real result. Evidence: `tmp/android-map-benchmark-host-gpu-texture-off-warm1.json`,
`tmp/android-map-benchmark-host-gpu-texture-off-invalid.json`, and
`tmp/android-host-gpu-texture-off-current.png`.

Two MapLibre-native quality knobs were tested through a temporary plugin
diagnostic: `MapLibreMapOptions.pixelRatio(0.75)` and
`MapLibreMap.tileLodScale=0.75`. Pixel ratio reduced native p95 to `24 ms` on
the warm repeat, but raised jank to `31.21%` and Flutter total p95 remained
`26 ms`; tile LOD was worse at native p95 `31 ms` and Flutter total p95 `30 ms`.
Both experiments kept the map and HUD visible, but neither meets the motion
gate, so the plugin cache was restored and no production flag was added.
Evidence: `tmp/android-map-benchmark-host-gpu-pixel-ratio-075-warm1.json`,
`tmp/android-map-benchmark-host-gpu-pixel-ratio-075-repeat2.json`, and
`tmp/android-map-benchmark-host-gpu-tile-lod-075-warm1.json`.

Telemetry-isolation follow-up (same API 35 emulator and twelve-swipe sequence)
omitted `FISHERGO_MAP_PERF` from the APK. The three no-telemetry repeats measured
gfx p95 `48 / 42 / 42 ms`, with approximately `49%` janky frames and no
FisherGO app-specific ANR. This is not an optimization pass: it shows that the
Flutter timing callback is not the main source of the native raster cost, so
future work should target MapLibre composition/style workload rather than
removing the monitor.

The no-telemetry JSON evidence is stored at
`tmp/android-map-benchmark-maplibre-gamehome-zoom15-warm1-noperf-api35.json`,
`tmp/android-map-benchmark-maplibre-gamehome-zoom15-warm1-noperf-run2-api35.json`,
and
`tmp/android-map-benchmark-maplibre-gamehome-zoom15-warm1-noperf-run3-api35.json`.

The latest instrumented source run rebuilt the profile APK with
`FISHERGO_MAP_PERF=true` and separated the work by Flutter stage: across the
final 240-frame telemetry window, build p95 was `2 ms`, raster p95 `26 ms`,
total p95 `45 ms`, vsync-overhead p95 `27 ms`, and frame-gap p95 `9 ms`;
the matching native gfx trace measured p95 `32 ms`, `30.62%` janky frames,
and 90 slow draw commands. This confirms that widget build is not the main
motion bottleneck. Evidence:
`tmp/android-map-benchmark-flutter-telemetry-current.json`.

An opt-in HUD `RepaintBoundary` candidate was also measured against the same
profile flow. It reduced raster p95 to `25 ms` and slow draw commands to 80,
but worsened Flutter total p95 to `48 ms` and janky rate to `31.76%`; the
candidate was removed and is not enabled in production. Evidence:
`tmp/android-map-benchmark-hud-repaint-optin-current.json`.

The current source was also rebuilt with the existing `FISHERGO_MAP_HC=true`
composition diagnostic. Clean and warm API 35 host-GPU repeats measured native
gfx p95 `31/32 ms`, Flutter total p95 `45/46 ms`, and janky `32.02%/33.77%`.
This is not a stable improvement over the `tlhc_vd` control, so
`FISHERGO_MAP_HC` remains disabled by default. Evidence:
`tmp/android-map-benchmark-hc-current-clean.json` and
`tmp/android-map-benchmark-hc-current-warm.json`.

The same candidate was rebuilt and rerun on 2026-07-30 with the current
readiness-gated host-GPU harness. It produced a valid 468-frame trace with
native gfx p95 `34 ms`, p99 `53 ms`, `35.68%` janky frames, Flutter total p95
`45 ms`, and no ANR; style-ready/map-idle were `883/995 ms`. This remains
above the 20 ms gate and is worse than the same-day default p95 `32 ms`, so
the candidate remains rejected as a default. Evidence:
`tmp/android-map-benchmark-hc-current-20260730.json`.

The current-source rebaseline on 2026-07-22 used a clean API 35 install,
host-GPU rendering, one warm-up round, and readiness gating. `tlhc_vd`
measured native gfx p95/p99 `46/61 ms`, Flutter total p95 `58 ms`, and
`47.17%` janky frames with no ANR. The same source rebuilt with
`FISHERGO_MAP_HC=true` measured `44/57 ms`, Flutter total p95 `53 ms`, and
`46.79%` janky frames. The 2 ms native difference is below the observed run
variance and both miss the 20 ms gate, so the default remains `tlhc_vd`.
Evidence: `tmp/android-map-benchmark-current-baseline-20260722.json` and
`tmp/android-map-benchmark-current-hc-20260722.json`.

The retained Android 3D height-cap candidate limits MapLibre building
extrusions to 36 metres while preserving the OSM building footprints, water,
roads, piers, rotation, and 3D camera. On the latest clean API 35 host-GPU
run it measured gfx p95 `32 ms`, `35.41%` janky frames, and `90` slow draw
commands, while an earlier clean repeat measured `31 ms`, `32.71%`, and `107`.
The visual result is less dominated by oversized high-rise faces, but the
20 ms motion gate remains open. Evidence:
`tmp/android-map-benchmark-height-cap-36-final.json`,
`tmp/android-map-benchmark-height-cap-36.json`, and
`tmp/android-height-cap-36.png`.

On 2026-07-22, the Android app explicitly pinned MapLibre Native
`android-sdk-opengl:13.2.0` over the Flutter plugin's `13.0.+` request. The
dependency resolved successfully and the Victoria Harbour proof kept style
readiness, 270-degree bearing control, and real fishing-spot selection. The
motion result improved slightly from the prior 13.0 candidate (`31 ms` versus
`32 ms` p95), but the final-restore repeat measured `42 ms`; both remain above
the 20 ms gate, so the pin is retained as the current Android renderer
baseline rather than treated as a performance pass. Evidence:
`tmp/android-map-benchmark-maplibre-native-13.2.0-api35.json`,
`tmp/android-map-benchmark-maplibre-native-13.2.0-final-restore-api35.json`,
`tmp/android-map-benchmark-maplibre-native-13.2.0-post-vulkan-restore-api35.json`,
`tmp/fishergo-native132-proof.xml`, `tmp/fishergo-native132-270.xml`, and
`tmp/fishergo-native132-selected.xml`.

The native version is now an explicit build-time override through
`FISHERGO_MAP_NATIVE_VERSION`, defaulting to `13.2.0`. A controlled API 35
candidate with MapLibre Native `13.3.0` kept Victoria Harbour readiness and
270-degree spot selection, but measured p95 `42 ms`, `44.41%` janky frames,
and `21` slow bitmap uploads. It does not improve the retained baseline and
remains an experiment-only override. Evidence:
`tmp/android-map-benchmark-maplibre-native-13.3.0-api35.json`,
`tmp/fishergo-native133-proof.xml`, and
`tmp/fishergo-native133-selected.xml`.

MapLibre Native `13.4.1` was then checked as the next official Android
dependency candidate. It built and reached the same readiness contract, but two
matched API 35 host-GPU runs both measured `53 ms` p95; the pinned `13.2.0`
controls both measured `48 ms`. The candidate also produced p99 `69/89 ms`
versus `65/65 ms` for the controls. This is not a stable performance
improvement, so the product remains pinned to `13.2.0` and the newer version is
not promoted. Evidence:
`tmp/android-map-benchmark-maplibre-native-13.4.1-api35.json`,
`tmp/android-map-benchmark-maplibre-native-13.4.1-repeat-20260801.json`,
`tmp/android-map-benchmark-maplibre-native-13.2.0-control-20260801.json`, and
`tmp/android-map-benchmark-maplibre-native-13.2.0-repeat-control-20260801.json`.

The opt-in `FISHERGO_MAP_VULKAN=true` build substituted
`android-sdk-vulkan:13.0.2` for the plugin's OpenGL request. A matched
`13.4.1` Vulkan candidate was also build-compatible and reached readiness, but
its p95 was `61 ms` versus `65 ms` for the `13.0.2` control while readiness
slowed from `1460/1654 ms` to `4217/4306 ms` and slow draw commands increased
from `78` to `86`. Both remain worse than the retained OpenGL baseline, so
Vulkan stays default-off. `FISHERGO_MAP_VULKAN_VERSION` is retained only for
future device-specific experiments. Evidence:
`tmp/android-map-benchmark-maplibre-vulkan-13.4.1-api35.json` and
`tmp/android-map-benchmark-maplibre-vulkan-13.0.2-control-20260801.json`.

Flutter HCPP was also tested through `FISHERGO_MAP_HCPP=true`. The API 35
emulator met the documented API/Vulkan requirements and the build carried
`io.flutter.embedding.android.EnableHcpp=true`, but the measured p95 was
`40 ms`; the manifest placeholder remains default-off. Evidence:
`tmp/android-map-benchmark-maplibre-hcpp-open-gl-13.2.0-api35.json` and
`tmp/fishergo-hcpp-ui.xml`.

A second HCPP composition proof combined `FISHERGO_MAP_HCPP=true` with
`FISHERGO_MAP_TEXTURE=false`. The fixed Victoria Harbour proof still reached
`Map: ready`, rotated to 270 degrees, and selected `維港測試釣點`, but the
GameHome benchmark produced `gfx_trace_valid=false` and `total_frames=0`.
Because the path cannot provide a valid motion trace for the release gate, it
is retained as a correctness-only experiment and remains disabled in the
production build. Evidence:
`tmp/android-map-benchmark-maplibre-hcpp-texture-off-13.2.0-api35.json`,
`tmp/fishergo-proof-hcpp-texture-off-selected.xml`, and
`tmp/fishergo-hcpp-texture-off.xml`.

| Run | Install state | Frames | p50 | p95 | Janky | Slow draw commands |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Latest WebP | Clean install | 164 | 29 ms | 113 ms | 49.39% | 67 |
| Earlier latest | Clean install | 158 | 30 ms | 121 ms | 49.37% | 67 |
| Earlier cold | Clean install | 170 | 25 ms | 117 ms | 50.00% | 70 |
| Cached | Existing install | 152 | 27 ms | 109 ms | 49.34% | 58 |

The latest historical zoom-16 run is stored at
`tmp/android-map-benchmark-webp-map-proof.json`; the zoom-15 GameHome repeats
are stored at `tmp/android-map-benchmark-maplibre-gamehome-zoom15-warm1-run1-api35.json`,
`tmp/android-map-benchmark-maplibre-gamehome-zoom15-warm1-run2-api35.json`, and
`tmp/android-map-benchmark-maplibre-gamehome-zoom15-warm1-run3-api35.json`.

The benchmark now accepts `-WarmupRounds` so tile/cache preparation can be
separated from the measured sweep. The current production-aligned one-round
warm sweep still failed the gate (`p95 105 ms`, `p50 23 ms`, `50.34%` janky,
`60` slow draw commands), and
Flutter telemetry attributes the dominant cost to raster rather than widget
build (`p95_build_ms 5`, `p95_raster_ms 493` in the corresponding window).

Composition experiments on the same emulator were rejected as follows:

| Variant | Result | Decision |
| --- | --- | --- |
| Texture on + `tlhc_vd` | p50 20 ms, p95 73 ms, 50.00% janky | Current overlay-compatible baseline; still fails Gate 2. |
| Texture on + `tlhc_hc` | p50 21 ms, p95 69 ms, 49.73% janky; style-ready 1.6 s | Reject; no meaningful improvement. |
| Texture off + `tlhc_vd` | Map visible, but Flutter HUD/avatar/spot overlays were obscured and black regions appeared | Reject for correctness. |
| Texture off + `tlhc_hc` | Same overlay loss; no valid frame trace | Reject for correctness. |
| Flutter HCPP + texture off + OpenGL MapLibre Native `13.2.0` | Victoria proof kept Map ready, 270° rotation, and fishing-spot selection, but GameHome produced 0 gfxinfo frames and no valid trace | Reject as a release renderer. Keep only as a future platform-view investigation; it cannot be compared against the 20 ms gate. Evidence: `tmp/android-map-benchmark-maplibre-hcpp-texture-off-13.2.0-api35.json`, `tmp/fishergo-proof-hcpp-texture-off-selected.xml`, and `tmp/fishergo-hcpp-texture-off.xml`. |
| Texture off + `tlhc_hc` + native player/spot layers + Flutter markers disabled | GameHome accessibility tree retained the external HUD, but API 35 `gfxinfo` recorded `0` rendered frames and no valid MapLibre motion trace | Reject. Moving map markers into native layers does not make the textureless composition measurable or releasable on this plugin/emulator combination. Evidence: `tmp/android-map-benchmark-textureless-native-layers.json`. |
| Compact 12-layer style + texture on + `tlhc_vd` | Historical one-off p95 85 ms; controlled zoom 16 repeats measured p95 113, 133, and 400 ms (median 133 ms), with 61-87 slow draw commands | Reject as the default fallback; removing layers did not produce a stable native raster improvement. |
| Low-power 9-layer candidate + texture on + `tlhc_vd` | p50 29 ms, p95 105 ms, 49.54% janky, 97 slow draw commands | Reject; fewer style layers did not reduce native raster cost. |
| Victoria Harbour pitch 0 + texture on + `tlhc_vd` warm-up | p50 32 ms, p95 400 ms, 49.62% janky, 52 slow draw commands | Reject as a pitch workaround; flatter camera did not improve the raster gate. |
| Compact markers during camera movement + texture on + `tlhc_vd` | p50 32 ms, p95 400 ms, 50.45% janky, 48 slow draw commands | Reject; simplifying Flutter marker visuals did not improve the native raster gate and would add visual state changes during drag. |
| Texture off + `tlhc_hc` clean install | No usable gfxinfo frame trace; HUD/marker composition was not valid | Reject for correctness and measurement quality. |
| Flutter markers disabled + texture on + `tlhc_vd` warm-up | p50 21 ms, p95 73 ms, 50.00% janky, 56 slow draw commands | Diagnostic only; marker removal did not materially change native draw cost, so keep interactive markers enabled. |
| Texture off + classic `hc` warm-up | 33 frames, p50 81 ms, p95 350 ms, 100.00% janky | Reject; the expensive hybrid mode is substantially slower. |
| Texture on + direct `hc` + current host-GPU 3D style | 381 frames, p50 17 ms, p95 36 ms, 35.70% janky, 95 slow draw commands; app-specific ANR false | Reject. Direct Hybrid Composition preserved MapLibre readiness, bearing controls, and fishing-spot selection in proof smoke, but its p95 was worse than the retained `tlhc_vd` road-main candidate (`32 ms`). Evidence: `tmp/android-map-benchmark-direct-hc-api35.json`, `tmp/fishergo-direct-hc-proof.xml`, and `tmp/fishergo-direct-hc-selected.xml`. |
| Current-source `tlhc_hc` repeat + lean Android 3D style + texture on + API 35 host GPU | 502 frames, p50 8 ms, p95 31 ms, p99 44 ms, 29.88% janky, 81 slow draw commands, 9 slow bitmap uploads; map readiness/style-idle `2276/2278 ms`; ANR false | Reject. The current source remained visually and interactively valid, but it was slower and had a worse tail than the retained `tlhc_vd` repeat (`p95/p99 30/32 ms`, `21.04%` janky). Evidence: `tmp/android-map-benchmark-current-tlhc-hc-api35-20260801.json`. |
| Texture on + Virtual Display `vd` + OpenGL MapLibre Native `13.2.0` | p50 13 ms, p95 44 ms, 42.70% janky, 86 slow draw commands, 13 slow bitmap uploads; app-specific ANR false | Reject as the default. The virtual-display path produced a valid trace, but was slower than the retained `tlhc_vd` composition and leaves the 20 ms gate open. Evidence: `tmp/android-map-benchmark-maplibre-vd-13.2.0-api35.json`. |
| Native MapLibre `SurfaceView` + actual FisherGO Game 3D style + SurfaceFlinger `timestats` | Warm repeats: 459/466 frames, average 44.03/45.06 FPS, present-to-present p50 17/16 ms, p95 32/30 ms, p99 300/300 ms, 3.70/3.00% janky, dropped frames 0, ANR false | Native MapLibre itself is already above the 20 ms tail gate even without Flutter HUD/platform-view composition, and the 300 ms tail repeats. Keep the native host as a diagnostic proof, but move the next optimization focus to tile/style geometry and frame-tail reduction. `gfxinfo` reports 0 UI frames for this direct SurfaceView, so these runs are measured with the API 35 SurfaceFlinger BLAST layer histogram. Evidence: `tmp/android-native-map-benchmark-game-style-api35.json` and `tmp/android-native-map-benchmark-game-style-repeat-api35.json`. |
| Native Game 3D style + vector source `maxzoom:15` | 460 frames, p50 16 ms, p95 32 ms, p99 250 ms, 4.13% janky, average 44.13 FPS, dropped frames 0, ANR false | Reject. The tail moved slightly, but p95 did not improve and zoom-16 map detail would be reduced; retain the current source detail. Evidence: `tmp/android-native-map-benchmark-game-style-maxzoom15-api35.json`. |
| Native Game 3D style + `prefetchesTiles=false` + `prefetchZoomDelta=0` | 456 frames, p50 16 ms, p95 36 ms, p99 300 ms, 5.70% janky, average 43.82 FPS, dropped frames 0, ANR false | Reject. Disabling native tile prefetch worsened the motion gate and did not reduce the long tail. The flag remains profile-only diagnostic code. Evidence: `tmp/android-native-map-benchmark-game-style-no-prefetch-api35.json`. |
| Flutter HCPP + direct `hc` + texture on + OpenGL MapLibre Native `13.2.0` | p50 19 ms, p95 53 ms, 61.62% janky, p99 350 ms, 134 slow draw commands; app-specific ANR false | Reject. Combining HCPP with direct Hybrid Composition worsened the tail and is not a release candidate. Evidence: `tmp/android-map-benchmark-maplibre-hcpp-direct-hc-13.2.0-api35.json`. |
| Vulkan `android-sdk-vulkan:13.0.2` + texture on + `tlhc_vd` | p50 11 ms, p95 38 ms, 44.59% janky, 109 slow draw commands, 17 slow bitmap uploads; app-specific ANR false | Reject as the Android default. The Vulkan artifact loaded and completed the GameHome benchmark, but was slower and uploaded more bitmaps than the retained OpenGL `13.2.0` baseline. Evidence: `tmp/android-map-benchmark-maplibre-vulkan-13.0.2-api35.json`. |
| OpenGL MapLibre Native `13.3.0` + texture on + `tlhc_vd` | p50 12 ms, p95 42 ms, 44.41% janky, 93 slow draw commands, 21 slow bitmap uploads; app-specific ANR false | Reject as the default. It matched the 13.2.0 p95 but increased bitmap uploads; keep only as the explicit `FISHERGO_MAP_NATIVE_VERSION` experiment. Evidence: `tmp/android-map-benchmark-maplibre-native-13.3.0-api35.json`. |
| Flutter HCPP + OpenGL MapLibre Native `13.2.0` | p50 12 ms, p95 40 ms, 43.76% janky, 118 slow draw commands, 17 slow bitmap uploads; app-specific ANR false | Reject as the Android default. HCPP loaded GameHome with the HUD and MapLibre accessibility surfaces intact, but was slower than the retained platform-view path. Evidence: `tmp/android-map-benchmark-maplibre-hcpp-open-gl-13.2.0-api35.json` and `tmp/fishergo-hcpp-ui.xml`. |
| Latest Flutter HCPP Victoria Harbour proof at 270° | Correctness pass, performance gate open | Rebuilt from the current source with HCPP enabled and the fixed Victoria Harbour proof entrypoint. Readiness was `2.407/2.415 s`; native gfx p95/p99 was `44/69 ms`, Flutter p95 total/raster/vsync was `57/26/31 ms`, and ANR was false. After restart, the UI tree confirmed the MapLibre surface, `Map: ready`, 270° bearing control, and `Spot: 維港測試釣點` after a real tap. Keep HCPP diagnostic-only because the motion gate remains open. Evidence: `tmp/android-map-benchmark-profile-composition-hcpp-victoria-270-api35.json`, `tmp/fishergo-composition-proof-hcpp-initial.xml`, `tmp/fishergo-composition-proof-hcpp-selected.xml`, and `tmp/composition-proof-hcpp-victoria-270-selected.png`. |
| Android marker shadows off + texture on + `tlhc_vd` x86_64 proof, post-reboot | 141 frames, p50 34 ms, p95 150 ms, 50.35% janky; app-specific ANR false; Flutter telemetry p95 raster 464 ms / total 580 ms | Valid diagnostic run, but still far above the 20 ms gate. Keep shadow-off as a supporting optimization only; native MapLibre raster remains the bottleneck. |
| Android marker shadows on control + texture on + `tlhc_vd` x86_64 proof, post-reboot | 117 frames, p50 40 ms, p95 450 ms, 50.43% janky; app-specific ANR false; Flutter telemetry p95 raster 476 ms / total 633 ms | Shadow-off is directionally better in this controlled run, but it does not make MapLibre releasable. |
| Android marker shadows off clean-install control + texture on + `tlhc_vd` x86_64 proof | 131 frames, p50 32 ms, p95 450 ms, 50.38% janky; app-specific ANR false; Flutter telemetry p95 raster 435 ms / total 576 ms | Cache/install state changes the tail; the native raster gate still fails. Do not treat this as a renderer decision. |
| Android native render-scale 0.75 diagnostic + texture on + `tlhc_vd` x86_64 proof | 139 frames, p50 40 ms, p95 450 ms, 50.36% janky; app-specific ANR false; Flutter telemetry p95 raster 472 ms / total 638 ms | Reject. Upscaling a smaller MapLibre surface did not reduce the native raster tail and is not worth the visual/projection risk. |
| Android native fishing-spot circle/label layer + texture on + `tlhc_vd` x86_64 proof | 126 frames, p50 31 ms, p95 400 ms, 50.00% janky; app-specific ANR false; 59 slow draw commands | Correctness proof passed: native circle followed camera movement and `featuresAtPoint` selected the verified spot. The modest motion improvement is not enough to pass Gate 2. |
| Android native fishing-spot circles without native labels + texture on + `tlhc_vd` API 35 warm-1 | 229 frames, p50 14 ms, p95 53 ms, 48.47% janky; app-specific ANR false; 53 slow draw commands; Flutter telemetry p95 total 96 ms | Better than the label variant, but still fails the 20 ms gate and keeps the same native raster tail. Keep as an opt-in diagnostic only; do not enable by default. Evidence: `tmp/android-map-benchmark-maplibre-native-spot-layer-no-labels-api35-warm1.json`. |
| Android native player sprite + texture on + `tlhc_vd` API 35 warm repeats | 186/165 frames, p50 21 ms, p95 73/69 ms, 50.00/49.70% janky; app-specific ANR false; 66/51 slow draw commands | Registration and avatar correctness pass, but the paired disabled control was `61/105 ms`; no stable performance win is proven. Keep `FISHERGO_MAP_NATIVE_PLAYER_LAYER` disabled by default. |
| Android native player + native spot layers, Flutter markers disabled + texture on + `tlhc_vd` API 35 warm repeat | 164 frames, p50 25 ms, p95 77 ms, p99 500 ms, 50.00% janky; app-specific ANR false; 59 slow draw commands; Flutter telemetry p95 total 129 ms | Flutter-side work is lower, but native gfx p95 is worse than the 69 ms control and the p99 tail is unacceptable. Reject as a default; retain both flags as opt-in diagnostics only. |
| Single OSM raster tile source + texture on + `tlhc_vd` API 35 x64 profile | 202 frames, p50 22 ms, p95 77 ms, 49.01% janky; 64 slow draw commands; Flutter p95 total 527 ms; style-ready 7.696 s; app-specific ANR false | Reject. One raster layer did not remove the Android texture/composition tail and made cold map readiness substantially worse. The diagnostic endpoint was removed; evidence: `tmp/android-map-benchmark-maplibre-raster-diagnostic-api35.json`. |
| Vector source `maxzoom:14` diagnostic + texture on + `tlhc_vd` API 35 x64 profile | 149 frames, p50 20 ms, p95 57 ms, 48.99% janky; 48 slow draw commands; Flutter p95 total 347 ms; style-ready 7.961 s; app-specific ANR false | Reject. Reusing lower-zoom vector tiles still increased cold readiness and did not meet the motion gate. The diagnostic flag was removed; evidence: `tmp/android-map-benchmark-maplibre-low-tile-zoom-diagnostic-api35.json`. |
| Stable GameHome profile rebuilt after Android native bitmap rollback + texture on + `tlhc_vd` API 35 x64 warm-1 | 236 frames, p50 15 ms, p95 53 ms, 49.58% janky; 64 slow draw commands; Flutter p95 total 114 ms; style-ready 7.321 s; app-specific ANR false | Fresh stable-source confirmation. The bitmap experiment is absent from the APK and the map remains usable, but the 20 ms motion gate still fails. Evidence: `tmp/android-map-benchmark-maplibre-stable-gamehome-post-icon-revert-api35.json`. |
| Stable GameHome profile after diagnostic cleanup + texture on + `tlhc_vd` API 35 x64 warm-1 | 110 frames, p50 28 ms, p95 105 ms, 50.00% janky, 50 slow draw commands; Flutter p95 total 555 ms; style-ready 10.532 s; app-specific ANR false | Fresh stable-source repeat confirms high emulator/cache variance and leaves Gate 2 failed; do not infer an optimization from the earlier 53 ms run. Evidence: `tmp/android-map-benchmark-maplibre-stable-post-diagnostic-cleanup-api35.json`. |
| Local bundled OSM GeoJSON source proof + texture on + `tlhc_vd` API 35 x64 warm-1 | 222 frames, p50 18 ms, p95 53 ms, 50.00% janky, 70 slow draw commands; Flutter p95 total 95 ms; style-ready 8.360 s; app-specific ANR false | Reject. Replacing the remote planet vector source with nearby bundled GeoJSON kept the native raster tail unchanged, increased bitmap uploads from 6 to 18, and slowed style readiness. The opt-in proof was removed; evidence: `tmp/android-map-benchmark-maplibre-local-geometry-api35.json`. |
| Full style without `building-3d` extrusion + texture on + `tlhc_vd` API 35 x64 warm-1 | 141 frames, p50 18 ms, p95 69 ms, 49.65% janky, 46 slow draw commands; Flutter p95 total 310 ms; style-ready 3.923 s; app-specific ANR false | Reject. Removing the 3D building layer reduced slow draw commands from 64 to 46 but worsened native p95 from the stable 53 ms baseline to 69 ms and left the motion gate failed. The diagnostic flag was removed; evidence: `tmp/android-map-benchmark-maplibre-no-extrusion-api35.json`. |
| Per-gesture low-power `setStyle` swap + full-style restore, texture on + `tlhc_vd` API 35 warm-1 | 98 frames, gfx p95 48 ms, 50.00% janky; Flutter raster p95 166 ms, total p95 399 ms; app-specific ANR false | Reject. Style reloads introduce a large frame tail and do not meet the motion gate; no motion-style flag is retained in production code. Evidence: `tmp/android-map-benchmark-maplibre-motion-style-api35-warm1.json`. |
| Flutter markers disabled + current host-GPU 3D style diagnostic | gfx p95 30 ms, 26.89% janky; Flutter total p95 33 ms; no ANR | Reject as an optimization. Removing the avatar/spot overlay did not improve native p95 and increased Flutter jank; interactive markers remain enabled. Evidence: `tmp/android-map-benchmark-host-gpu-markers-off-diagnostic.json`. |
| Low-power 9-layer style + current host-GPU diagnostic | gfx p95 31 ms, 23.78% janky; Flutter total p95 40 ms; no ANR | Reject as the default. It also removed 3D buildings and weakened the game map while failing the motion gate. Evidence: `tmp/android-map-benchmark-host-gpu-low-power-diagnostic.json` and `tmp/android-host-gpu-low-power-diagnostic.png`. |
| Lean Android game 3D style + vertical gradient disabled | gfx p95 `31/30 ms` across clean/warm repeat, janky `26.38/25.00%`, Flutter total p95 `29/30 ms`, no ANR | Keep as the Android visual default. The shader change is a low-risk supporting optimization, but it does not close the 20 ms motion gate. Evidence: `tmp/android-map-benchmark-host-gpu-game-3d-no-gradient-diagnostic.json` and `tmp/android-map-benchmark-host-gpu-game-3d-no-gradient-repeat.json`. |
| Lean Android game 3D style + 36 m extrusion cap | Final clean run gfx p95 `32 ms`, `35.41%` janky, `90` slow draw commands; no ANR | Keep as the current visual/performance candidate. An earlier clean repeat measured `31 ms` / `32.71%` / `107`; the variance confirms the gate remains open. The cap reduces oversized building fill during motion without removing real geography. Evidence: `tmp/android-map-benchmark-height-cap-36-final.json`, `tmp/android-map-benchmark-height-cap-36.json`, and `tmp/android-height-cap-36.png`. |
| Android Game 3D `road-main` consolidation + single zoom interpolation | Clean p95 `32 ms`, `33.79%` janky, `97` slow draw commands, `2` slow bitmap uploads; no ANR | Keep as the current style candidate. It replaces three vehicle-road passes with one OSM-class-matched pass, preserves road hierarchy, and removes the MapLibre nested zoom-expression warning. The motion gate is still open and needs a renderer/composition-level improvement. Evidence: `tmp/android-map-benchmark-road-main-single-interpolate.json`, `tmp/road-main-shatin-0.png`, `tmp/road-main-shatin-90.png`, `tmp/road-main-shatin-180.png`, `tmp/road-main-shatin-270.png`, `tmp/road-main-victoria-0.png`, `tmp/road-main-victoria-90.png`, `tmp/road-main-victoria-180.png`, and `tmp/road-main-victoria-270.png`. |
| Lean Android game 3D style + 24 m extrusion cap diagnostic | gfx p95 `32 ms`, `34.59%` janky, `96` slow draw commands, `9` slow bitmap uploads; no ANR | Reject. The p95 did not improve over the retained 36 m cap, while draw and bitmap metrics worsened; restore 36 m to preserve building readability. Evidence: `tmp/android-map-benchmark-height-cap-24-maplibre.json`. |
| Fixed building-height diagnostic on the current Android game 3D style | Control gfx p95 `69 ms`, `49.13%` janky versus candidate `69 ms`, `48.89%` janky; candidate p99 `85 ms`, 76 slow draw commands, 13 slow bitmap uploads; no ANR | Reject as a release optimization. The bounded fixed-height expression removes per-building height lookup but does not improve p95 or close the 20 ms motion gate; keep `FISHERGO_MAP_FIXED_BUILDING_HEIGHT` disabled by default. Evidence: `tmp/android-map-benchmark-fixed-height-control-api35-20260801.json` and `tmp/android-map-benchmark-fixed-height-candidate-api35-20260801.json`. |

The diagnostic flags `FISHERGO_MAP_TEXTURE`, `FISHERGO_MAP_HC`,
`FISHERGO_MAP_HC_DIRECT`,
`FISHERGO_MAP_COMPACT`, `FISHERGO_MAP_LOW_POWER`, and
`FISHERGO_MAP_NATIVE_PLAYER_LAYER` keep their current defaults (`true`,
`false`, `false`, `false`, `false`, and `false`). `FISHERGO_MAP_MARKERS` remains `true`,
and Android's `FISHERGO_MAP_ANDROID_3D_STYLE` is now `true` by default; the
explicit `FISHERGO_MAP_3D_STYLE` flag remains available for proof builds.

The isolated proof accepts `FISHERGO_MAP_PROOF_LAT`,
`FISHERGO_MAP_PROOF_LON`, `FISHERGO_MAP_PROOF_ZOOM`, and
`FISHERGO_MAP_PROOF_PITCH`, and `FISHERGO_MAP_PROOF_BEARING` through
`--dart-define`, so Sha Tin, Victoria
Harbour, and different 3D camera presets can be compared without changing the
production map defaults.

The Web trace is repeatable with `tool/web_map_benchmark.js` against a release
MapLibre proof build. It waits for the style, performs the same twelve map
drags, and records `requestAnimationFrame` intervals. The local Chrome run
reported:

| Viewport | Frames | FPS | p95 frame interval | Janky rate |
| --- | ---: | ---: | ---: | ---: |
| 390 x 844 | 226 | 45.12 | 18.2 ms | 1.78% |
| 1440 x 900 | 273 | 54.43 | 18.1 ms | 0.37% |

The opt-in native fishing-spot layer proof also passed a local Web smoke at
`988 x 605`: 273 frames, 54.52 FPS, p95 frame interval 18.2 ms, and 0.37%
janky frames. The proof screenshot
`output/playwright/web-native-spot-after-tap.png` shows the selected spot and
status update; this does not change the default Flutter marker path.

The same proof with the transparent 3D beacon image registered in the native
symbol layer rendered at `1280 x 720`: 284 frames, 56.74 FPS, p95 frame
interval 18.2 ms, and 0.35% janky frames. The screenshot
`output/playwright/web-native-icon-after-tap.png` shows the beacon and the
selected-spot status update. Android remains on the native circle fallback
until the platform image path is independently fixed.

This closes only the local Web measurement item; it does not offset the
failing Android p95 gate.

An opt-in timing monitor is now available for repeatable follow-up traces. Run
the MapLibre proof with `--dart-define=FISHERGO_MAPLIBRE=true
--dart-define=FISHERGO_MAP_PERF=true` to record a bounded frame window,
build/raster/total p50 and p95 timings, jank rate, and style-ready latency. The
monitor is disabled by default; these local traces provide evidence for the
readiness sub-gate, but do not turn the failing Android motion gate into a pass.
### Flutter Vector Fallback Comparison

The fallback proof uses Flutter `FrameTiming` because Android `dumpsys gfxinfo`
reported zero frames for this pure Flutter surface and returned placeholder
percentiles. The benchmark JSON still records those raw `gfxinfo` values, but
the `flutter_*` fields are authoritative for this comparison.

| Variant | Frames | p50 total | p95 total | p95 raster | Janky | ANR | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Original full `GameMapRenderer` proof | 120 | 172 ms | 540 ms | 354 ms | 99.17% | False | Reject; too much procedural/texture work per rotation frame. |
| Lightweight vector painter | 120 | 12 ms | 54 ms | 17 ms | 33.33% | False | Keep optimizing; real geometry is correct but tail is too high. |
| Grouped road paths | 240 | 11 ms | 22 ms | 15 ms | 15.83% | False | Best current fallback candidate; still narrowly misses the 20 ms gate. |
| Static background `RepaintBoundary` | 180 | 11 ms | 23 ms | 15 ms | 26.67% | False | No stable improvement over grouped roads; do not switch production yet. |
| Full GameHome vector fallback shell (API 35, no idle tickers) | 240 | 29 ms | 46 ms | 28 ms | 89.58% | False | Correctness and tap flow pass, but the complete HUD shell remains above the motion gate; keep opt-in. |
| Full GameHome shell with screen-space geometry simplification | 240 | 28 ms | 47 ms | 26 ms | 94.58% | False | Raster p95 improves slightly, but total motion/jank gate remains open; keep opt-in. |
| Textured vector fallback surfaces (API 35 visual smoke) | n/a | n/a | n/a | n/a | n/a | False | Water/grass tiles load and rotate with GPS geometry; telemetry was unavailable in this run, so this is not a performance pass. |
| Textured surfaces with per-frame shader reuse (API 35 clean-install GameHome benchmark) | 240 | 40 ms | 219 ms | 34 ms | 94.58% | False | Reuses one water/land/shore shader per paint pass; the real GameHome run remains above the motion gate. |
| Motion mode with textures disabled during rotation (API 35 clean-install GameHome benchmark) | 240 | 33 ms | 244 ms | 30 ms | 96.67% | False | Reduces raster and median cost during drag while restoring textures at idle; total tail still fails the motion gate. |
| Motion mode with textures disabled and geometry simplification (API 35 clean-install GameHome benchmark) | 240 | 32 ms | 92 ms | 30 ms | 94.17% | False | Reduces the previous motion tail; latest telemetry also recorded p95 vsync overhead 13 ms and p95 frame gap 20 ms. Total motion gate remains open. |
| Motion mode with cached background and batched surface paths (API 35 clean-install GameHome benchmark) | 240 | 33 ms | 57 ms* | 27 ms* | 95.42% | False | Best single run: avoids fixed-background repaint during bearing changes and batches motion water/land/shore paths. Repeats are noisy; total gate remains open. |
| Motion mode with local bearing notifier (API 35 clean-install GameHome benchmark) | 240 | 35/37 ms | 188/364 ms | 29/32 ms | 96.25%/96.25% | False | p50/p95 build is reproducibly 2/6 ms because drag updates no longer rebuild the full GameHome HUD; total tail remains scheduler/emulator-limited and fails the motion gate. |
| Full GameHome shell after removing legacy home tickers (API 35 clean-install benchmark) | 240 | 40 ms | 361 ms | 228 ms | 96.25% | False | Removes three unused/duplicate home controllers without changing the map surface; no measurable improvement to the raster tail. |
| Motion map layer transform (API 35 clean-install benchmark) | 240 | 40 ms | 363 ms | 195 ms | 99.58% | False | Freezes geometry at gesture-start bearing and rotates the complete map layer, including grass/water/roads/spots; raster p95 improves, but total/jank gate remains open. |
| Motion layer transform with one cached vector surface boundary (API 35 clean-install benchmark) | 240 | 41/41 ms | 103/249 ms | 40/34 ms | 94.17%/93.75% | False | Stable raster improvement from compositing the whole surface as one reusable layer; total p95 is still scheduler/frame-gap noisy and above the release gate. |
| Motion layer transform with dataset/store visible-feature cache (API 35 warm cached-install repeats) | 240/240 | 59/58 ms | 468/227 ms | 73/64 ms | 95.42%/97.50% | False | Avoids rebuilding the OSM feature store and equivalent-camera feature list; no stable improvement over the cached-surface baseline, so keep as a low-risk allocation optimization only. |
| Classic painter motion cache with opt-in `FrameTiming` probe (API 35 warm cached-install repeat) | 121 | 236 ms | 666 ms | 298 ms | 100.00% | False | The classic renderer now freezes the gesture-start camera and caches the full surface behind `RepaintBoundary`; telemetry is valid, but raster and frame-gap cost remain far above the 20 ms gate. Keep Gate 2 open. |
| Classic painter motion-detail reduction (API 35 warm clean-install repeat) | 122 | 238 ms | 506 ms | 382 ms | 100.00% | False | Skips decorative, building, label, and atmosphere layers while dragging while preserving vector surface, roads, and piers. This improves p95 total by about 24% versus the cached-only repeat, but still fails the 20 ms gate. |

The latest evidence is stored at
`tmp/android-map-benchmark-vector-fallback-optimized-static-background-x64.json`;
the grouped-road comparison is at
`tmp/android-map-benchmark-vector-fallback-optimized-grouped-roads-x64.json`.
The complete-shell evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-no-idle-tickers-x64-rerun.json`.
The latest screen-space simplification evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-screen-simplified-x64.json`.
The textured visual smoke evidence is stored at
`tmp/map-vector-textured-harbour-soft-grass.png` and
`tmp/map-vector-textured-after-rotate.png`.
The valid clean-install GameHome benchmark evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-textured-shader-reuse-gamehome-x64.json`.
The latest motion-simplification evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-simplified-structured-x64.json`.
The latest cached-background and batched-surface evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-batched-surfaces-x64.json`.
The same candidate was rerun after clean install three more times: p95 total
`268 ms`, `420 ms`, and `405 ms` respectively. The four-run median p95 is
`336.5 ms`, so the `57 ms` result is explicitly a best-case diagnostic rather
than a release-performance pass. Evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-batched-surfaces-repeat-2-x64.json`,
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-batched-surfaces-repeat-3-x64.json`,
and `tmp/android-map-benchmark-vector-fallback-production-shell-motion-final-x64.json`.
The local-bearing notifier runs are stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-map-local-bearing-x64.json`
and
`tmp/android-map-benchmark-vector-fallback-production-shell-map-local-bearing-repeat-x64.json`.
Their p95 build values are both `6 ms`, while p95 total remains `188 ms` and
`364 ms`; this isolates the remaining tail from full-screen widget rebuild cost.
The legacy home ticker cleanup evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-no-legacy-home-tickers-x64.json`.
The motion layer-transform evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-layer-transform-x64.json`.
The cached vector-surface boundary evidence is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-layer-transform-boundary-x64.json`
and its clean-install repeat at
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-layer-transform-boundary-repeat-x64.json`.
The dataset/store visible-feature cache comparison is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-feature-store-cache-repeat-x64.json`
and
`tmp/android-map-benchmark-vector-fallback-production-shell-feature-store-cache-repeat-2-x64.json`.
The Android benchmark now promotes Flutter `vsync overhead` and `frame gap`
telemetry to structured JSON fields so future renderer comparisons do not need
to parse raw log lines.
The classic painter now emits the same opt-in telemetry as the other map
proofs. The warm repeat is stored at
`tmp/android-map-benchmark-classic-motion-cache-perf-warm1-api35.json`; its
`p95_total_ms` is `666`, `p95_raster_ms` is `298`, and `anr_detected` is false.
The motion-detail reduction repeat is stored at
`tmp/android-map-benchmark-classic-motion-optimized-warm1-api35.json`; its
`p95_total_ms` is `506`, `p95_raster_ms` is `382`, and `anr_detected` is false.
The motion-mode comparison is stored at
`tmp/android-map-benchmark-vector-fallback-production-shell-motion-textures-off-x64.json`.
The fallback remains a proof/candidate entrypoint, not the production default.
The production map no longer carries a debug or compile-time fake fishing
spot. Locations without an active verified registry row now render zero nearby
spots; the full map remains available for browsing verified distant spots.

The latest readiness values are:

| Path | Style ready | Map idle | Evidence |
| --- | ---: | ---: | --- |
| API 35 clean install | 1.742 s | 1.831 s | `tmp/android-map-benchmark-default-zoom-16-idle-cold.json` |
| API 35 installed/cache state | 0.656 s | 0.673 s | `tmp/android-map-benchmark-default-zoom-16-idle-cached.json` |
| Web 390 x 844 | 0.829 s | 0.960 s | `output/playwright/web-map-proof-benchmark.png` and Playwright page title |
| Web 1440 x 900 | 0.396 s | 0.452 s | Playwright page title |

The Android measurements are below the cached `<=3 s` and uncached `<=5 s`
readiness targets. The remaining uncertainty is topology coverage and native
raster cost during sustained motion, not initial style/tile readiness.

The Android benchmark now checks only
`dumpsys activity processes com.fishergo.app` for
`mNotResponding=true`, and exits non-zero when FisherGO itself reports that
state. A previous global process scan matched unrelated YouTube/Wellbeing
blocks and produced an invalid ANR diagnosis; post-reboot FisherGO-specific
runs report `anr_detected: false`. An arm64 proof APK was also rejected by the
x86_64 API 35 emulator before any motion measurement; the valid proof build
must use `--target-platform android-x64` for this emulator.

The installed `maplibre_android 0.3.5` plugin exposes platform-view mode,
texture mode, and surface translucency, but no application-level native render
buffer or map-view resolution control. Its own `MapOptions` documentation
warns that texture mode carries a significant performance penalty. Because
texture-off runs lose the Flutter HUD/marker composition, the current proof
keeps texture mode on while Gate 2 remains open; a future renderer change must
move interactive markers into a native map layer or adopt a different engine
before it can remove that constraint.

## Gate 7: Asset and Runtime Budget

Status: **PARTIAL - Android signing guard passes; protected key provisioning remains open**

Latest artifact evidence:

- The GitHub `Flutter quality` job now runs
  `dart format --output=none --set-exit-if-changed lib test tool` before
  analysis and tests. `test/asset_budget_source_test.dart` locks this guard
  into the workflow contract.
- `dart run tool/check_asset_budget.dart` now enforces the Web package and
  Android AAB limits in CI. The 2026-07-30 local run measured Web `89.5 MiB`
  and the arm64 release AAB `75.4 MiB`, below the `<100 MiB` Android store
  target. A multi-ABI diagnostic AAB measured `112.3 MiB` and is not the
  release artifact; CI is pinned to `--target-platform android-arm64`.
- Flutter 3.44's shared Android plugin registrant still lists the dev-only
  `integration_test` plugin. Release compilation now uses the tracked
  production-only overlay at
  `android/app/src/release/java/io/flutter/plugins/GeneratedPluginRegistrant.java`;
  `test/android_release_plugin_registry_test.dart` guards the overlay and its
  CI checkout visibility.
- `android/app/build.gradle.kts` no longer falls back to the Android debug key.
  With no signing environment configured, the local AAB is explicitly unsigned
  (`jarsigner` reports `jar is unsigned`); with
  `FISHERGO_REQUIRE_RELEASE_SIGNING=true`, the build fails before packaging
  until all four `FISHERGO_ANDROID_*` values are present.
- The signing guard was exercised on 2026-07-22 with
  `FISHERGO_REQUIRE_RELEASE_SIGNING=true` and no keystore values; Gradle
  rejected `bundleRelease` at the signing check with exit `1`. This proves the
  fail-closed path, but protected keystore provisioning and Play App Signing
  remain owner actions.
- A manual protected release workflow now exists at
  `.github/workflows/android-release.yml`. It decodes
  `FISHERGO_ANDROID_KEYSTORE_BASE64` only under the runner temp directory,
  validates the decoded keystore, store password, key password, and alias
  before `keytool` and Gradle start,
  forces the Gradle signing guard, builds both the arm64 AAB and a matching
  installable arm64 APK, verifies `jarsigner` output for both, and reruns the
  client-artifact and asset-budget checks. Its source contract is covered by
  `test/android_release_workflow_source_test.dart`; it cannot produce a signed
  artifact until the four signing secrets and the base64 keystore are supplied
  in the `fishergo-android-release` environment. After those checks, the signed
  arm64 AAB, APK, and `release-manifest.json` are uploaded as
  `fishergo-android-release` for 14 days. The manifest shares app version,
  build id, build time, and Git SHA fields with the Web manifest, providing a
  traceable release record instead of leaving artifacts only on the ephemeral
  runner.
- The latest current-source local release rebuild produced an arm64 AAB of
  `74.4 MiB` and an arm64 APK of `92.4 MiB`; both builds emitted one Dart
  symbol file, and the client-secret scan plus asset-budget check passed. These
  artifacts remain unsigned by design. Flutter still reports the upstream
  `maplibre_android` Kotlin Gradle Plugin compatibility warning, so the
  MapLibre plugin upgrade remains a dependency follow-up rather than a release
  failure.
- The full Web build is `89.5 MiB` across 571 files. This package inventory is
  separate from runtime transfer size and still needs a dedicated bootstrap
  budget decision.
- The production-aligned `scripts/vercel-build.sh` run on 2026-07-19 emitted
  `build/web/version.json` with build id `20260719044210` and passed the client
  artifact scan. `AppShell` now checks this manifest after the first frame;
  Web compares it against Hive and shows the update prompt only when the build
  id increases, while Android uses a no-op platform stub.
- Encyclopedia grid cards now cap WebP decode dimensions to the card density
  (`180-480px` wide) while detail pages retain the uncapped asset. The asset
  selection and density rule are covered by
  `test/fish_encyclopedia_asset_selection_test.dart`; this keeps catalog media
  lazy at runtime without changing the locked-gray, game-color, or real-photo
  progression.
- The cache-disabled bootstrap capture was upgraded on 2026-07-18 to use CDP
  `Network.dataReceived` and `Network.loadingFinished`. It snapshots exactly
  two seconds after navigation starts, records bytes already received by
  responses that are still in flight, and also preserves the old
  completion-only value for comparison. The same script now accepts the
  current page origin, so local and deployed builds use identical accounting.

  | Target | Viewport | First 2 s | In-flight at 2 s | First 10 s | Deferred | Fish media |
  | --- | --- | ---: | ---: | ---: | ---: | ---: |
  | Local release | 390 x 844 | 4.13 MB | 0.00 MB / 7 req | 4.34 MB | 0.21 MB | 0.00 MB |
  | Local release | 1440 x 900 | 4.21 MB | 0.00 MB / 8 req | 4.34 MB | 0.14 MB | 0.00 MB |
   | Deployed `www.fisher-go.app` current MapLibre/WebP | 390 x 844 | 1.39 MB | 0.00 MB / 0 req | 1.39 MB | 0.00 MB | 0.00 MB |
   | Deployed `www.fisher-go.app` current MapLibre/WebP | 1440 x 900 | 1.39 MB | 0.00 MB / 0 req | 1.39 MB | 0.00 MB | 0.00 MB |

  The current local readings are evidence toward the `<=15 MiB`
  initial-transfer target. Lazy AppShell mounting and MapLibre-only terrain
  loading remove the hidden CatchLog overlay and fallback terrain dataset from
   the map-first startup path. The current production deployment now serves
   the MapLibre/WebP release and is within the `<=15 MiB` initial-transfer
   target. The 390 px capture has one deferred manifest request at two seconds;
   fish media stays at zero because the encyclopedia is lazy-loaded.
- Fish catalog media now uses 340 Flutter-decoded WebP assets at `11.2 MB`,
  down from `73.4 MB` of PNGs. The original PNG directory remains as a source
  and rollback input, but is no longer listed in `pubspec.yaml`; generated,
  backup, and renumbered icon sources are also excluded by `.vercelignore`.
- `tool/build_mobile_fish_webp.ps1` reproduces the compressed catalog bundle.
- Locked encyclopedia cards now decode only their silhouette asset; they no
  longer load a full-color fish WebP and grayscale it. This reduces runtime
  image decode pressure while preserving the current catalog manifest. Moving
  the optional fish media out of the startup bundle remains open below.
- Deployed `https://fisher-go.app` smoke check passed on 2026-07-22: canonical
  redirect reached `www`, the production startup rendered the login/map shell,
  Google login was enabled, desktop and 390 x 844 captures had no console
  errors or warnings, and the rotation drag completed without a browser error.
  Evidence: `output/playwright/fishergo-deployed-390x844.png`,
  `output/playwright/fishergo-deployed-desktop-rotated.png`.
- The latest production fallback check passed on 2026-07-22 after the 36 m
  extrusion-cap deployment: with browser GPS unavailable, the player still
  anchors at the Tsing Yi land coordinate `22.3520, 114.1016` instead of the
  former water coordinate. The live map rendered roads, buildings, streams,
  water, avatar, and HUD. The cache-disabled bootstrap capture served
  `1.388 MB` within the first two seconds at both `390x844` and `1440x900`,
  loaded `0` fish-media bytes, and left `0` requests in flight. The latest
  1440x900 drag benchmark measured `53.94 FPS`, `18.1 ms` p95 frame time, and
  `0.37%` janky frames; console errors and warnings remained at zero. Evidence:
  `output/playwright/web-bootstrap.png`,
  `output/playwright/web-map-proof-benchmark.png`, and production
  `main.dart.js?v=20260722113924`.

Open items:

- Repeat the Web bootstrap capture after any further major asset or map-style
  change; the current post-extrusion-cap MapLibre/WebP deployment capture is
  recorded above.
- Provision the protected Android upload keystore and Play App Signing before
  any release distribution; the local artifact is intentionally not a
  distributable signed build.
- The multi-ABI AAB was rebuilt as a diagnostic and measured `112.3 MiB`, so
  it remains outside the release budget; the supported release artifact is the
  arm64 AAB until a deliberate ABI strategy changes.
- A controlled API 35 marker-composition experiment on 2026-07-22 kept the
  selected avatar visible and removed only Android soft-effects nodes; the
  result remained gfx p95 `46 ms` with Flutter total p95 `63 ms`, so the
  experiment was withdrawn. A marker-off diagnostic reached gfx p95 `42 ms`,
  but it removes the required player avatar and is not a product candidate.
  Evidence: `tmp/android-map-benchmark-avatar-composition-reduced-20260722.json`
  and `tmp/android-map-benchmark-markers-off-rebaseline-20260722.json`.
- The catalog now prefers transparent mobile fish art over `*-badge.webp`
  assets, eliminating the visible white image square in the encyclopedia
  cards. Local-name badge assets fall back to the numbered mobile WebP when a
  descriptor-based transparent asset is unavailable. Focused path tests cover
  both rules in `test/fish_encyclopedia_asset_selection_test.dart`.
- The same transparent artwork resolver is used by virtual-catch success
  surfaces, and cancelling a minigame no longer consumes bait; this is covered
  by the focused minigame/source tests and the API 35 fishing flow.
- Apply and verify `supabase/migrations/0012_fishing_spot_moderation.sql` in the
  linked production project before using the new admin spot controls for live
  moderation. The migration is intentionally not auto-applied by Vercel.
- Apply and verify `supabase/migrations/0013_real_catch_leaderboard.sql` in the
  linked production project before treating the cloud leaderboard as live.
  Until then, the client deliberately falls back to its local competition
  snapshot.
- Apply and verify `supabase/migrations/0014_server_authoritative_rewards.sql`
  in the linked production project before relying on the protected wallet
  boundary. Until then, the Flutter client can use the explicitly marked
  migration fallback for backward compatibility.
- Apply and verify `supabase/migrations/0015_gameplay_reward_tickets.sql` in
  the linked production project before relying on ticket-enforced positive
  rewards. The linked release remains owner-controlled and has not run in
  this workspace.
- Apply and verify
  `supabase/migrations/0016_server_validated_fishing_sessions.sql` in the
  linked production project before treating server-validated bite timing and
  session-bound virtual rewards as active. The local migration and pgTAP
  behavior are green; the hosted migration remains owner-controlled.
- Hosted gameplay smoke was attempted on 2026-07-31 with the configured
  Supabase URL and anon key. Anonymous auth and public-spot discovery reached
  the project, then `/rest/v1/rpc/start_virtual_fishing_session` returned HTTP
  404. The smoke tool now includes the failing endpoint path in its error, so
  this gate remains open until the linked project receives migration 0016 (and
  0015) through the protected content-release workflow.
- A read-only `npx supabase migration list --linked` check on 2026-08-01
  confirmed the current release target still has remote migrations through
  `0011`, while local migrations `0012` through `0024` remain unapplied. No
  production schema was changed by this check; the protected workflow remains
  the only intended apply path.
- A read-only management-API schema probe on 2026-08-01 also returned null for
  `player_gameplay_reward_claims`, `player_fishing_sessions`,
  `start_virtual_fishing_session(text,text,text)`, and
  `resolve_virtual_fishing_session(uuid,integer)`. This independently confirms
  that the linked target has not received migrations `0015/0016`; no write was
  performed.
- The new read-only content-release dry-run was also executed against that
  target on 2026-08-01. It failed closed with
  `LegacyDbPushMissingLocalError`: remote legacy versions `001` and `002` are
  and the exact local counterparts are sorted after `0010` through `0019`, so
  the CLI's ordered comparison reports them as missing before it can plan
  `0012` through `0024`. A read-only management query and `migration fetch`
  confirmed that both remote names/statements match the local compatibility
  files; no production schema was changed.
- A disposable follow-up probe confirmed that renaming the local legacy files to
  bare `001.sql` and `002.sql` is not a fix: the CLI skips those files because
  migration filenames must match `<timestamp>_name.sql`, then fails with the
  same history-order error. The probe used a temporary copy and made no
  repository or production changes. The owner-controlled fix is now an explicit
  protected workflow input plus confirmation secret: repair only remote history
  rows `001/002`, exclude the markers in the CI checkout, and then apply the
  pending migrations as documented in `docs/release-runbook.md`.
- The hosted gameplay smoke now optionally requires
  `SUPABASE_PROJECT_REF` and fails closed when its value does not match the
  Supabase URL host. The live-smoke workflow passes that protected ref into the
  check; the local URL/ref alignment passed before the same hosted 0016 RPC
  404 was observed.
- The migration-compatibility fallback now requires the requested RPC name and
  PostgREST's explicit `Could not find the function` message together. An
  unrelated `PGRST202` or a same-name parameter/schema error therefore fails
  closed instead of enabling a local reward fallback. Focused RPC error tests
  and the full Flutter suite passed after this hardening.
- Configure the protected `fishergo-content-release` environment and run the
  manual content-release workflow once the owner is ready to apply migrations.
  The workflow now runs its hosted gameplay smoke as a dependent job after
  linked pgTAP and schema lint; configure the matching URL, anon key, project
  ref, and verified smoke-spot id in the protected `fishergo-live-smoke`
  environment as well. The migration job passes its linked project ref to the
  smoke job, and the smoke tool fails before network activity if the live
  environment points at a different project.
  The workflow now serializes runs with the `fishergo-content-release`
  concurrency group and queues a second manual dispatch instead of cancelling
  an active migration.
  The complete owner sequence and failure interpretation are recorded in
  `docs/release-runbook.md`.

### Remaining Work

1. Reduce slow UI-thread and MapLibre draw-command/composition frames without
   weakening geography; the Android game 3D style is visually accepted but
   still measures p95 near 30 ms rather than the 20 ms target.
2. Keep the Sha Tin and Victoria Harbour boundary/bearing matrices as release-candidate checks. The current final height-cap APK has passed both local 0/90/180/270 matrices and Harbour marker selection; repeat them only after the next map-style or renderer change.
3. Re-run deployed Web cold/cache readiness and Android topology readings only
   after the next map-style or renderer change; the current post-extrusion-cap
   evidence is recorded above.
4. Encyclopedia media lazy-load is now source-guarded: the catalog uses
   `SliverGrid.builder`, bounded card decode sizes, and silhouette-first locked
   artwork. Evidence: `test/fish_encyclopedia_lazy_media_source_test.dart` and
   `test/fish_encyclopedia_asset_selection_test.dart`. Keep the old map through
   two passing release candidates before removing the fallback renderer.
