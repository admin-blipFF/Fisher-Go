# Hosted Supabase Release Runbook

This runbook is for the owner-controlled production content release. It keeps
the read-only audit separate from the migration workflow and never stores
credentials in the repository.

## 1. Run The Read-Only Audit

Open GitHub Actions and run **Supabase hosted audit** from the target branch:

- Environment: `fishergo-live-smoke`
- Required secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SUPABASE_PROJECT_REF`
- Optional input: `expected_project_ref`

The audit checks canonical project identity, Google and anonymous Auth
providers, and all 13 habitat rows touched by the current content migration.
It does not use a database password or access token and cannot run a
migration. The current known hosted drift is `P017` missing
`tung-chung-runway`.

## 2. Approve The Content Release

After reviewing the audit, run **Supabase content release** from the same
commit. The protected environment must provide:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_DB_PASSWORD`
- disposable RLS user credentials required by the workflow

Keep `reconcile_legacy_history` set to `false` unless the owner has confirmed
that the remote legacy `001`/`002` history rows must be repaired. If repair is
approved, also set the protected confirmation secret to
`FISHERGO_REPAIR_001_002`.

Before any link, migration-history repair, or `db push`, the workflow now
fails closed if any migration, disposable-RLS-user, or approved-repair input is
missing. This prevents a partially applied release from reaching a later
verification step with an incomplete protected environment.

The workflow verifies project identity before linking, validates the dry-run
plan against the local migration IDs, applies migrations, captures before/plan/
after history artifacts, runs linked pgTAP and lint checks, and then starts the
hosted gameplay checks. Do not run a production `supabase db push` from a
developer workstation.

## 3. Close The Gate

Accept the release only when the workflow artifacts and hosted smoke show:

1. The habitat verifier passes all 13 rows, including `P017` and `P018`.
2. Two-user RLS behavior passes and public-schema lint has no errors.
3. Auth provider, server event, analytics, gameplay-session, and photo-storage
   checks pass.
4. The workflow's migration history before/plan/after artifacts are retained.

Until these checks pass, the hosted content gate remains open even though the
local migration and local pgTAP suite are green.
