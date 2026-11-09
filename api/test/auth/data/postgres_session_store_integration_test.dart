import 'dart:io';

import 'package:hashlib/hashlib.dart';
import 'package:lost_and_found_api/src/auth/data/postgres_session_store.dart';
import 'package:lost_and_found_api/src/auth/domain/auth_session.dart';
import 'package:lost_and_found_api/src/auth/session_service.dart';
import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

class _ConnectionDatabaseClient implements DatabaseClient {
  final Connection connection;

  _ConnectionDatabaseClient(this.connection);

  @override
  Future<bool> checkConnection() async => connection.isOpen;

  @override
  Future<Result> execute(String query, {Map<String, dynamic>? parameters}) {
    return connection.execute(Sql.named(query), parameters: parameters);
  }

  @override
  Future<void> close() => connection.close();
}

void main() {
  final databaseUrl = Platform.environment['TEST_DATABASE_URL'];

  test('PostgreSQL persists sessions and atomic revocation across services',
      () async {
    final connection = await Connection.open(
      PostgreSqlDatabaseClient.parseEndpoint(databaseUrl!),
      settings: ConnectionSettings(
        sslMode: PostgreSqlDatabaseClient.resolveSslMode(databaseUrl),
      ),
    );
    addTearDown(connection.close);
    await connection.execute('''
CREATE TEMPORARY TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id UUID NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
)
''');
    final store = PostgresSessionStore(_ConnectionDatabaseClient(connection));
    final now = DateTime.utc(2026, 10, 31, 12);
    final first = SessionService(store: store, clock: () => now);
    final issued = await first.issue('00000000-0000-4000-8000-000000000001');

    final stored = await connection.execute('SELECT token_hash FROM sessions');
    expect(stored.single[0], sha256.string(issued.token).hex());
    expect(stored.single[0], isNot(issued.token));

    final restarted = SessionService(store: store, clock: () => now);
    final restored = await restarted.authenticate(issued.token);
    expect(restored.userId, issued.session.userId);
    expect(restored.expiresAt, issued.session.expiresAt);
    expect(await store.find('missing-token-hash'), isNull);

    final tokenHash = sha256.string(issued.token).hex();
    final revocations = await Future.wait([
      store.revoke(tokenHash, now),
      store.revoke(tokenHash, now),
    ]);
    expect(revocations.where((revoked) => revoked), hasLength(1));
    await expectLater(
      restarted.authenticate(issued.token),
      throwsA(isA<InvalidSessionException>()),
    );

    final expiring = await first.issue('00000000-0000-4000-8000-000000000001');
    expect(
      await store.revoke(
          sha256.string(expiring.token).hex(), expiring.session.expiresAt),
      isFalse,
    );
  },
      skip: databaseUrl == null || databaseUrl.isEmpty
          ? 'Set TEST_DATABASE_URL to an isolated PostgreSQL test database.'
          : false);
}
