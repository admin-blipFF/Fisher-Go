# FisherGO Store Release Data Safety Draft

Status: **Draft for owner/legal review**

This document is an implementation inventory, not a legal privacy policy. It
must be reviewed against the live Supabase project, the final Play Console
form, the support contact, and the deployed Edge Functions before release.

## Data Inventory

| Data | Where it is used | Purpose | Current retention/deletion behavior |
| --- | --- | --- | --- |
| Supabase user ID, email, and OAuth identity | Supabase Auth and account-scoped local Hive boxes | Sign-in, account upgrade, cloud sync | Auth keeps the account until deletion; local account namespace is cleared by the source-ready deletion flow |
| Fishing location and catch coordinates | Device location APIs, local catch queue, `public.catches` | GPS-centered map, nearby spot filtering, catch history | Local queue remains on device; synced coordinates remain in the user-owned catch row until deletion |
| Catch photo | Local picker file, private `catch-photos` bucket, signed URLs | Real-catch proof and catch history | Bucket is private; source-ready deletion function removes the user's objects |
| Catch notes, species, time, size, weight, checkpoints | Local Hive queue and `public.catches` | Catch log, sync, rewards, history | User-owned rows remain until deletion or an owner-approved retention policy |
| Progress, collection, wallet, avatar, boat state | Account-scoped local Hive boxes and player cloud tables | Game progress and cross-device continuity | Local data is device-scoped; cloud rows are user-scoped by RLS |
| Fish photo sent for recognition | Authenticated `recognize-fish` Edge Function, then VectorEngine provider | AI fish recognition | Provider retention and processing terms must be confirmed before store release |

## Permissions

- Location is requested only after an explicit locate action. Disabled,
  denied, and permanently denied states keep the GPS-free map fallback usable.
- Android 14 selected-photo access is declared for limited gallery selection.
- CatchLog currently uses the system gallery picker only; camera capture is not
  part of the shipped flow, so the Android manifest does not request CAMERA.
- The app should not request location or photo access during login, tutorial,
  or initial map startup.

## Sharing and Processors

- Supabase Auth, database, and private Storage are required cloud processors.
- The fish-recognition Edge Function forwards the selected image and bounded
  fish-catalog hints to VectorEngine. The production provider retention,
  regional processing, and deletion terms are an owner approval gate.
- No crash-reporting SDK is currently enabled; do not answer that diagnostics
  are collected until an observability product is deliberately configured.

## Account Deletion

Source readiness now includes:

1. A confirmation dialog in the signed-in Profile screen.
2. `LocalAccountService.clearCurrentAccountData()` for the local namespace.
3. `supabase/functions/delete-account`, which authenticates the caller,
   removes current and legacy user-owned rows, removes private catch-photo
   objects, and calls `auth.admin.deleteUser`.

The Edge Function is **not yet deployed to the hosted Supabase project**. Do
not publish the deletion button as a completed production capability until it
is deployed and a disposable signed-in deletion smoke has passed.

## Support and Reporting

Profile now exposes privacy, support, and problem-report actions only when the
owner supplies the public build-time values `FISHERGO_PRIVACY_URL` and
`FISHERGO_SUPPORT_EMAIL`. The problem-report action opens a prefilled email
with the subject `FisherGO 問題報告`; it does not invent a fallback address.
These links are a source-ready flow, not evidence that the owner has approved
the final policy URL or support mailbox.

## Play Data Safety Review Checklist

- [ ] Owner confirms the live Supabase region, subprocessors, and retention.
- [ ] Owner confirms VectorEngine processing/retention and whether images are
      used for model training.
- [ ] Owner supplies a public privacy-policy URL.
- [ ] Owner supplies a support email and account-deletion support fallback.
- [ ] Run `.github/workflows/supabase-account-deletion-release.yml` with the
      protected Supabase deployment token, project ref, service-role cleanup
      key, and disposable smoke credentials.
- [ ] Run signed-in disposable-account deletion smoke and verify rows,
      storage objects, Auth user, and local namespace are gone.
- [ ] Reconcile this inventory with the final Play Data Safety answers.
- [ ] Capture final Android screenshots after the signed build and internal
      track install.

## Release Evidence

- Source and local deletion tests: `test/delete_account_source_test.dart`,
  `test/profile_auth_source_test.dart`, and
  `test/local_account_service_test.dart`.
- Owner-configured privacy, support, and report actions: wired through
  `lib/features/profile/presentation/profile_screen.dart`; final public values
  remain an owner action.
- Protected function deployment and live deletion smoke: **open**.
- Privacy policy URL, support contact, provider terms, screenshots, and final
  Play answers: **owner action**.
