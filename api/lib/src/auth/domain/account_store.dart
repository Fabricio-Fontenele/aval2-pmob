import 'auth_session.dart';

class AccountCredentials {
  final String id;
  final String passwordHash;

  const AccountCredentials({required this.id, required this.passwordHash});
}

abstract interface class AccountStore {
  Future<String> create(
      String email, String passwordHash, PendingSession session);
  Future<AccountCredentials?> findByEmail(String email);
}

class EmailInUseException implements Exception {
  const EmailInUseException();
}

class AccountStorageException implements Exception {
  const AccountStorageException();
}
