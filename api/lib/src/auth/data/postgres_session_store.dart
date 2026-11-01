import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../../db/database_client.dart';
import '../domain/auth_session.dart';
import '../domain/session_store.dart';

class PostgresSessionStore implements SessionStore {
  final DatabaseClient _database;

  const PostgresSessionStore(this._database);

  @override
  Future<void> create(String tokenHash, AuthSession session) async {
    await _execute(
      '''
INSERT INTO sessions (token_hash, user_id, expires_at)
VALUES (@tokenHash, @userId, @expiresAt)
''',
      {
        'tokenHash': tokenHash,
        'userId': session.userId,
        'expiresAt': session.expiresAt.toUtc(),
      },
    );
  }

  @override
  Future<AuthSession?> find(String tokenHash) async {
    final result = await _execute(
      '''
SELECT user_id, expires_at, revoked_at
FROM sessions WHERE token_hash = @tokenHash
''',
      {'tokenHash': tokenHash},
    );
    if (result.isEmpty) return null;
    final row = result.single.toColumnMap();
    return AuthSession(
      userId: row['user_id'] as String,
      expiresAt: (row['expires_at'] as DateTime).toUtc(),
      revokedAt: (row['revoked_at'] as DateTime?)?.toUtc(),
    );
  }

  @override
  Future<bool> revoke(String tokenHash, DateTime now) async {
    final result = await _execute(
      '''
UPDATE sessions SET revoked_at = @now
WHERE token_hash = @tokenHash AND revoked_at IS NULL AND expires_at > @now
''',
      {'tokenHash': tokenHash, 'now': now.toUtc()},
    );
    return result.affectedRows == 1;
  }

  Future<Result> _execute(String sql, Map<String, Object?> parameters) async {
    try {
      return await _database.execute(sql, parameters: parameters);
    } on PgException {
      throw const SessionStorageException();
    } on IOException {
      throw const SessionStorageException();
    } on TimeoutException {
      throw const SessionStorageException();
    }
  }
}
