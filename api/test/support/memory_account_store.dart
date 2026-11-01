import 'package:hashlib/hashlib.dart';
import 'package:lost_and_found_api/src/auth/domain/account_store.dart';
import 'package:lost_and_found_api/src/auth/domain/auth_session.dart';

import 'memory_session_store.dart';

class MemoryAccountStore implements AccountStore {
  final MemorySessionStore sessions;
  final accounts = <String, AccountCredentials>{};
  bool unavailable = false;

  MemoryAccountStore(this.sessions);

  @override
  Future<String> create(
      String email, String passwordHash, PendingSession session) async {
    if (unavailable || sessions.failure != null) {
      throw const AccountStorageException();
    }
    if (accounts.containsKey(email)) throw const EmailInUseException();
    final id = 'test-user-${accounts.length + 1}';
    accounts[email] = AccountCredentials(id: id, passwordHash: passwordHash);
    sessions.sessions[sha256.string(session.token).hex()] =
        AuthSession(userId: id, expiresAt: session.expiresAt);
    return id;
  }

  @override
  Future<AccountCredentials?> findByEmail(String email) async {
    if (unavailable) throw const AccountStorageException();
    return accounts[email];
  }
}
