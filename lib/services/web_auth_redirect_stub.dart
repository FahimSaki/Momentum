// Non-web platforms never call into this — auth_service.dart only reaches
// these functions behind `if (kIsWeb)` checks. This stub exists purely so
// the conditional export in web_auth_redirect.dart always resolves to
// something on every platform.

String? getGoogleRedirectFragment() => null;

void clearUrlFragment() {}

void navigateTo(String url) {}
