import 'dart:async';
import 'dart:io';

import 'package:hashlib/hashlib.dart';
import 'package:postgres/postgres.dart';

import '../../db/database_client.dart';
import '../domain/account_store.dart';
import '../domain/auth_session.dart';

class PostgresAccountStore implements AccountStore {
  final DatabaseClient _database;

  const PostgresAccountStore(this._database);

  @override
  Future<String> create(
      String email, String passwordHash, PendingSession session) async {
    final result = await _execute('''
WITH new_user AS (
  INSERT INTO users (email, password_hash) VALUES (@email, @passwordHash)
  ON CONFLICT (email) DO NOTHING
  RETURNING id
)
INSERT INTO sessions (token_hash, user_id, expires_at)
SELECT @tokenHash, id, @expiresAt FROM new_user
RETURNING user_id
''', {
      'email': email,
      'passwordHash': passwordHash,
      'tokenHash': sha256.string(session.token).hex(),
      'expiresAt': session.expiresAt.toUtc(),
    });
    if (result.isEmpty) throw const EmailInUseException();
    return result.single[0] as String;
  }

  @override
  Future<AccountCredentials?> findByEmail(String email) async {
    final result = await _execute(
      'SELECT id, password_hash FROM users WHERE email = @email',
      {'email': email},
    );
    if (result.isEmpty) return null;
    final row = result.single.toColumnMap();
    return AccountCredentials(
      id: row['id'] as String,
      passwordHash: row['password_hash'] as String,
    );
  }

  Future<Result> _execute(String sql, Map<String, Object?> parameters) async {
    try {
      return await _database.execute(sql, parameters: parameters);
    } on PgException {
      throw const AccountStorageException();
    } on IOException {
      throw const AccountStorageException();
    } on TimeoutException {
      throw const AccountStorageException();
    }
  }
}
