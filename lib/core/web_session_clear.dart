// ignore_for_file: use_key_in_widget_constructors
// Conditional import: loads stub (mobile) or web_impl (web).
import 'web_session_stub.dart'
    if (dart.library.js_interop) 'web_session_web_impl.dart' as session;

void clearStaleSupabaseSession() => session.clear();
