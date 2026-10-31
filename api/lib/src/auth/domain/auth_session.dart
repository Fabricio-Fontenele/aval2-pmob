class AuthSession {
  final String userId;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  const AuthSession({
    required this.userId,
    required this.expiresAt,
    this.revokedAt,
  });
}

class IssuedSession {
  final String token;
  final AuthSession session;

  const IssuedSession({required this.token, required this.session});
}

class InvalidSessionException implements Exception {
  const InvalidSessionException();
}
