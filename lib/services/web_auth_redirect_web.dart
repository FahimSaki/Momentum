import 'package:web/web.dart' as web;

/// Returns the raw URL fragment (everything after '#', without the '#'
/// itself), or null if there is none. Used to read the parameters Google
/// appends after an OAuth redirect (e.g. '#id_token=...&scope=...').
String? getGoogleRedirectFragment() {
  final hash = web.window.location.hash;
  if (hash.length <= 1) return null;
  return hash.substring(1);
}

/// Strips the fragment from the visible URL without triggering a reload or
/// adding a new history entry, so a page refresh doesn't try to re-process
/// an already-used token.
void clearUrlFragment() {
  final pathname = web.window.location.pathname;
  web.window.history.replaceState(null, '', pathname);
}

/// Full-page navigation — used instead of window.open() so the sign-in
/// flow never opens a popup and never needs cross-window postMessage,
/// sidestepping Cross-Origin-Opener-Policy entirely.
void navigateTo(String url) {
  web.window.location.href = url;
}
