/// Returns true only for a PostgREST error saying that the requested function
/// is absent from the schema cache.
bool isMissingSupabaseRpc(Object error, String functionName) {
  final text = error.toString();
  return text.contains(functionName) &&
      text.contains('Could not find the function');
}
