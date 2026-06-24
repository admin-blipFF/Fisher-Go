// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

// Previously this cleared all Supabase localStorage keys on every app boot.
// That forced Google/email users to sign in again after every reload/deploy.
// Keep this as a safe no-op; if anonymous-session cleanup is needed later,
// implement it after Supabase.initialize() and only clear sessions whose user
// is actually anonymous.
void clear() {}
