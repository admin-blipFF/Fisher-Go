# FisherGO Release Runbook

This runbook is for the owner-controlled release gates. Do not paste secret
values into the repository, workflow logs, screenshots, or issue comments.

## 1. Supabase Content Release

Configure the protected GitHub environment `fishergo-content-release` with:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_DB_PASSWORD`
- `SUPABASE_LEGACY_HISTORY_REPAIR_CONFIRMATION` (only for the one-time legacy
  reconciliation; set it to `FISHERGO_REPAIR_001_002`)
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` for the protected Auth-backed RLS
  proof
- `FISHERGO_RLS_USER_A_EMAIL` / `FISHERGO_RLS_USER_A_PASSWORD`
- `FISHERGO_RLS_USER_B_EMAIL` / `FISHERGO_RLS_USER_B_PASSWORD`

The two RLS users must be dedicated disposable password accounts. The release
workflow signs them in only to resolve their Auth UUIDs, renders a temporary
pgTAP fixture, and runs it inside a transaction that rolls back profiles and
catches. The workflow never prints credentials, access tokens, or UUIDs.

Run **Actions -> Supabase content release -> Run workflow** on the intended
branch. The `apply-and-verify` job will link the project, apply all versioned
migrations, run linked pgTAP, and run public-schema lint.
Before any of those mutation steps, the workflow verifies every required
protected input, including both disposable RLS test users. If legacy history
repair is selected, it also requires the exact owner confirmation value;
missing inputs fail before `supabase link` or `supabase db push`.
Before linking or mutating the database, the job verifies that the canonical
`SUPABASE_URL` is reachable and matches `SUPABASE_PROJECT_REF`. The dependent
`hosted-gameplay-smoke` job repeats that check and compares its protected
project ref with the ref exported by `apply-and-verify` before any hosted
verifier runs.

The job first prints a read-only `supabase db push --linked --include-all
--dry-run` migration plan, captures it in the runner temporary directory, and
passes it through `tool/verify_supabase_migration_plan.dart` before applying
anything. The verifier allows only local four-digit migration IDs at or above
`0012` after legacy marker files are removed, rejects unexpected IDs, revert
actions, and unrecognizable output, and accepts an explicit no-op plan. Review
the verified plan in the workflow log when migration history contains legacy
entries or local/remote drift. The job also uploads the before/after migration
history and dry-run plan as `fishergo-supabase-migration-evidence-<run-id>`;
download that artifact from the workflow run when a migration fails or needs
audit review. The migration target ref is passed to the dependent
`hosted-gameplay-smoke` job. Configure the protected
`fishergo-live-smoke` environment with:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_PROJECT_REF`
- `FISHERGO_SMOKE_GAMEPLAY_SPOT_ID` (optional; otherwise an active verified
  public spot is selected)

After the migration push, linked database verification runs the remote RLS
behavior suite plus read-only or transaction-rollback schema shape suites for
analytics, retention, catch-photo storage, fishing-spot content and
moderation, reward tickets, gameplay sessions, real-catch moderation, wallet
operations, server event configuration, and notification-token privacy. This
catches a migration that
applies successfully but leaves a required table, policy, RPC, index, or
storage constraint missing before the live gameplay smoke begins.

The dependent smoke job first runs
`tool/verify_supabase_fishing_spot_habitat.dart`. It uses only the public anon
key to verify the target project ref and representative active, verified,
public fishing spots with the expected habitat tags and stable fish IDs. Treat
any non-zero result other than exit `2` for missing local credentials as a
release failure; exit `2` is the local fail-closed skip state.

The current linked project has legacy three-digit history rows `001` and `002`.
The corresponding local files are valid and content-matched, but their
underscore separator makes them sort after `0010` through `0026`; the CLI's
ordered history check therefore fails before it can plan the new migrations.
Do not try to fix this by renaming files to bare `001.sql` or `002.sql`: those
names are skipped because migrations must use `<timestamp>_name.sql`.

One-time owner-controlled reconciliation, after reviewing the remote rows and
the compatibility-only SQL, uses the workflow input
`reconcile_legacy_history=true`:

1. Confirm the protected environment points at the intended project and the
   confirmation secret is present.
2. Dispatch the workflow with `reconcile_legacy_history=true`. It runs
   `supabase migration repair 001 002 --linked --status reverted --yes`, which edits
   migration history only; it does not roll back schema or grants.
3. The CI checkout temporarily excludes the two compatibility markers, then
   the dry-run must plan only local `0012` through `0027` before apply and hosted
   smoke.

With the input left `false`, the workflow never runs repair and remains
fail-closed. Do not set the input or secret against an unverified project ref.

The live environment's project ref must match both the URL host and the ref
emitted by `apply-and-verify`. The smoke must report all of these checks:

- anonymous session creation;
- active verified public spot discovery;
- early pull resolves as a miss;
- bite-window pull resolves as success;
- repeated resolve is idempotent;
- session-bound virtual-catch reward ticket is claimed.
- authenticated analytics ingestion accepts the `app_bootstrap` and `map_idle`
  allowlisted events, including a bounded `durationMs` field, through the
  security-definer RPC.
- location-verified gameplay accepts a nearby GPS fix and rejects a distant
  fix, unusable accuracy, and repeated session starts.
- admin retention reporting returns only D2/D7 cohort aggregates and rejects
  non-admin callers.
- server event configuration returns only valid active parent-event boosts and
  rejects anonymous access.

Each authenticated gameplay, analytics, event-configuration, and catch-photo
smoke deletes the disposable Auth identity in its `finally` block after the
checks. The catch-photo smoke removes its uploaded object first. If the
authenticated delete fails, the tool falls back to sign-out and emits a
warning; do not treat that fallback as proof that the disposable account was
removed.

## 2. Other Live Gates

After the content release succeeds, run the manual **Supabase live smoke**
workflow. Its first step verifies that `SUPABASE_URL` is an HTTPS Supabase host
whose project ref matches `SUPABASE_PROJECT_REF`; only then does it fail closed
unless both Google and anonymous providers are enabled before checking
anonymous account upgrade, gameplay session behavior, and private catch-photo
storage. Use disposable test identities only.
The workflow now performs a complete protected-input preflight before any
analytics, gameplay, or account-upgrade request: the URL, anon key, project
ref, and disposable upgrade email/password must all be present.

Run **Supabase account deletion release** with its protected environment after
the deletion policy has been reviewed. Confirm the disposable account and all
private catch-photo objects are removed. The client keeps the deletion action
hidden by default; only release builds that explicitly pass
`FISHERGO_ACCOUNT_DELETION_ENABLED=true` after this smoke may expose it. The
workflow now performs the same canonical URL/project-ref identity check before
deploying the Edge Function. Web deployment scripts propagate this flag and
reject values other than `true`/`false`.
Before deploying the Edge Function, it also verifies the service-role key and
disposable deletion email/password, so missing smoke credentials cannot leave
an unverified function deployment behind.

The live Auth upgrade smoke also deletes its disposable account through the
authenticated `/auth/v1/user` endpoint after the identity-preservation check;
it falls back to sign-out only when deletion fails.

## 3. Android Release

Configure the protected `fishergo-android-release` environment with the
keystore and four `FISHERGO_ANDROID_*` signing values. Run the manual Android
release workflow. It must produce and verify a signed arm64 AAB, matching APK,
Dart symbols, asset budget, secret scan, and release manifest.

The workflow also creates a separately signed x86_64 release APK only for the
API 35 emulator smoke. That smoke launches the signed release configuration,
reaches GameHome, triggers the explicit GPS action, and records a minimum
60-frame map trace. The x86_64 APK is test evidence; the arm64 APK and AAB
remain the distributable artifacts.

Use only the API 35 emulator for local smoke checks. The API 23 photo-frame
device is intentionally excluded.

## 4. Web Release

Vercel deployment is separate from Supabase migration. After the intended
production deployment is `READY`, verify that `fisher-go.app` and
`www.fisher-go.app` resolve to the same deployment, the Flutter bootstrap
loads, the map has populated OSM geometry, and no `.env` asset is public.
The local `scripts/deploy.sh` guard requires the public Supabase values and
Vercel token, and refuses non-canonical production aliases before deployment.
On Windows, use `powershell -ExecutionPolicy Bypass -File scripts/deploy.ps1
-PromoteProduction`; the PowerShell path performs the same build, manifest,
secret-scan, alias, and public verification gates. Without
`-PromoteProduction` it stops before reading credentials or building, so an
accidental invocation cannot change production. Both production scripts also
require a clean Git worktree before reading credentials; use the direct Vercel
preview command for uncommitted diagnostic builds instead of promoting them.
For CI, configure the protected `fishergo-web-release` environment with
`VERCEL_TOKEN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PROJECT_REF`,
and the owner-configured privacy/support values, then run **Actions -> Web
release -> Run workflow**. The workflow passes the resolved release ID,
public build values, and protected project ref into the remote Vercel build,
so the post-deploy manifest check covers the deployment that Vercel actually
built rather than only the runner's local build. The remote build uses the
dedicated `FISHERGO_DEPLOY_RELEASE_ID` channel so a stale project-level
`FISHERGO_RELEASE_ID` cannot replace the selected release.
The Vercel build script also fails closed when `VERCEL_ENV=production` (or
`FISHERGO_REQUIRE_SUPABASE=true`) and either public Supabase build value or
project ref is missing; preview/local diagnostics may still run without
Supabase.

After a promotion, run **Actions -> Web production smoke -> Run workflow**.
It checks both canonical release manifests, then runs the Chromium guest,
tutorial-skip, MapLibre, OpenFreeMap, and visual-golden flow at mobile and
desktop viewports. Leave `enforce_frame_budget` disabled while the known
desktop motion gate is open; enable it only for a release candidate that is
intended to close that performance gate.

The canonical deployment verifier also checks the effective public
`Cache-Control` headers: release entrypoints must revalidate, while the
build-ID-query-busted `main.dart.js` must be immutable. This catches a Vercel
configuration or CDN regression that source-only tests cannot see.

The Vercel cache policy is intentionally split by asset class. The HTML,
Flutter bootstrap, manifests, service worker, MapLibre tuning script, and
unversioned Flutter assets use revalidation so a new deployment is visible
without a hard refresh. `main.dart.js` is the exception: the Vercel build
rewrites its bootstrap URL with the build ID, so that payload is immutable.
Branding icons use a short one-day cache with stale-while-revalidate.

Do not treat a successful Vercel build as evidence that Supabase migrations
were applied.

## Failure Interpretation

| Failure | Meaning | Action |
| --- | --- | --- |
| `start_virtual_fishing_session` HTTP 404 | Linked project lacks migration 0016 or its RPC is not refreshed | Re-run content release and inspect linked migration status |
| `LegacyDbPushMissingLocalError` | Legacy three-digit files sort after newer four-digit files, so the CLI's ordered comparison reports remote `001/002` as missing even when names and statements match | Use the protected workflow input and confirmation secret described above; it repairs only `001/002`, excludes the markers in the CI checkout, then reruns the dry-run |
| Project ref mismatch | Migration and live smoke point to different projects | Correct both protected environments before rerunning |
| No active verified public spot | Smoke data prerequisite is missing | Provide a verified public smoke spot or fix the registry |
| Auth upgrade/photo smoke missing credentials | Owner-controlled disposable credentials are absent | Add them only to the protected live-smoke environment |
| Android signing guard failure | Protected signing values are absent or invalid | Provision Play signing secrets; do not use a debug key |
