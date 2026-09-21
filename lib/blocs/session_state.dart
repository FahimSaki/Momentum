/// Immutable snapshot of the current auth session.
class SessionState {
  final String? jwtToken;
  final String? userId;

  const SessionState({this.jwtToken, this.userId});

  bool get isAuthenticated =>
      jwtToken != null && jwtToken!.isNotEmpty && userId != null;
}
