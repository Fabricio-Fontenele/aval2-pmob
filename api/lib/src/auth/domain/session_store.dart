import 'auth_session.dart';

abstract interface class SessionStore {
  Future<void> create(String tokenHash, AuthSession session);
  Future<AuthSession?> find(String tokenHash);

  /// Revokes an active session atomically and returns whether it was changed.
  Future<bool> revoke(String tokenHash, DateTime now);
}

class SessionStorageException implements Exception {
  const SessionStorageException();
}
