/// Returns whether [url] is the canonical HTTPS endpoint for [projectRef].
///
/// Release checks intentionally reject proxy paths, query strings, explicit
/// non-default ports, and lookalike hosts. Supabase project URLs are the only
/// supported public target for the app's client boundary.
bool isTrustedSupabaseUrl(Uri url, String projectRef) {
  final ref = projectRef.trim();
  if (ref.isEmpty || url.scheme != 'https' || url.host.isEmpty) {
    return false;
  }

  return url.host.toLowerCase() == '$ref.supabase.co'.toLowerCase() &&
      url.port == 443 &&
      (url.path.isEmpty || url.path == '/') &&
      url.query.isEmpty &&
      url.fragment.isEmpty &&
      url.userInfo.isEmpty;
}
