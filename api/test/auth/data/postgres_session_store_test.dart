import 'dart:async';
import 'dart:io';

import 'package:lost_and_found_api/src/auth/data/postgres_session_store.dart';
import 'package:lost_and_found_api/src/auth/domain/auth_session.dart';
import 'package:lost_and_found_api/src/auth/domain/session_store.dart';
import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

class FailingDatabaseClient extends FakeDatabaseClient {
  final Exception error;

  FailingDatabaseClient(this.error);

  @override
  Future<Result> execute(String query,
      {Map<String, dynamic>? parameters}) async {
    throw error;
  }
}

void main() {
  for (final failure in <Exception>[
    PgException('sensitive database details'),
    const SocketException('sensitive connection details'),
    TimeoutException('sensitive timeout details'),
  ]) {
    test('translates ${failure.runtimeType} for each session operation',
        () async {
      final store = PostgresSessionStore(FailingDatabaseClient(failure));
      final session = AuthSession(
        userId: 'user-id',
        expiresAt: DateTime.utc(2026, 11, 1),
      );

      await expectLater(
        store.create('token-hash', session),
        throwsA(isA<SessionStorageException>()),
      );
      await expectLater(
        store.find('token-hash'),
        throwsA(isA<SessionStorageException>()),
      );
      await expectLater(
        store.revoke('token-hash', DateTime.utc(2026, 10, 31)),
        throwsA(isA<SessionStorageException>()),
      );
    });
  }
}
