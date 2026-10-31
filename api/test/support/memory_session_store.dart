import 'package:lost_and_found_api/src/auth/domain/auth_session.dart';
import 'package:lost_and_found_api/src/auth/domain/session_store.dart';

class MemorySessionStore implements SessionStore {
  final sessions = <String, AuthSession>{};
  SessionStorageException? failure;
  SessionStorageException? revocationFailure;

  void _checkFailure() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<void> create(String tokenHash, AuthSession session) async {
    _checkFailure();
    sessions[tokenHash] = session;
  }

  @override
  Future<AuthSession?> find(String tokenHash) async {
    _checkFailure();
    return sessions[tokenHash];
  }

  @override
  Future<bool> revoke(String tokenHash, DateTime now) async {
    _checkFailure();
    final error = revocationFailure;
    if (error != null) throw error;
    final session = sessions[tokenHash];
    if (session == null ||
        session.revokedAt != null ||
        !session.expiresAt.isAfter(now)) {
      return false;
    }
    sessions[tokenHash] = AuthSession(
      userId: session.userId,
      expiresAt: session.expiresAt,
      revokedAt: now,
    );
    return true;
  }
}
