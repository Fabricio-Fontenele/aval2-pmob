import 'dart:io';
import 'dart:math';

import 'package:hashlib/hashlib.dart';
import 'package:lost_and_found_api/src/auth/data/password_hasher.dart';
import 'package:lost_and_found_api/src/auth/data/postgres_account_store.dart';
import 'package:lost_and_found_api/src/auth/data/postgres_session_store.dart';
import 'package:lost_and_found_api/src/auth/domain/account_store.dart';
import 'package:lost_and_found_api/src/auth/session_service.dart';
import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:lost_and_found_api/src/db/migrator.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../../support/connection_database_client.dart';

void main() {
  final databaseUrl = Platform.environment['TEST_DATABASE_URL'];
  test(
      'PostgreSQL commits account and session together and rejects concurrent duplicates',
      () async {
    Future<Connection> connect() => Connection.open(
          PostgreSqlDatabaseClient.parseEndpoint(databaseUrl!),
          settings: ConnectionSettings(
            sslMode: PostgreSqlDatabaseClient.resolveSslMode(databaseUrl),
          ),
        );

    final firstConnection = await connect();
    addTearDown(firstConnection.close);
    final random = Random.secure();
    final suffix =
        List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
    final schema = 'p02_auth_$suffix';
    await firstConnection.execute('CREATE SCHEMA $schema');
    addTearDown(() => firstConnection.execute('DROP SCHEMA $schema CASCADE'));
    final secondConnection = await connect();
    addTearDown(secondConnection.close);
    await firstConnection.execute('SET search_path TO $schema');
    await secondConnection.execute('SET search_path TO $schema');
    final firstDatabase = ConnectionDatabaseClient(firstConnection);
    await DatabaseMigrator(firstDatabase).runMigrations();
    final firstStore = PostgresAccountStore(firstDatabase);
    final secondStore =
        PostgresAccountStore(ConnectionDatabaseClient(secondConnection));
    final sessionStore = PostgresSessionStore(firstDatabase);
    final sessions = SessionService(store: sessionStore);
    final hash = await const PasswordHasher().hash('demonstration-password');
    final pending = sessions.prepareToken();
    final userId =
        await firstStore.create('person@example.test', hash, pending);
    final restored = await sessions.authenticate(pending.token);
    expect(restored.userId, userId);
    final row = (await firstConnection
            .execute('SELECT email, password_hash FROM users'))
        .single;
    expect(row[0], 'person@example.test');
    expect(row[1], startsWith(r'$argon2id$'));
    final storedToken =
        (await firstConnection.execute('SELECT token_hash FROM sessions'))
            .single[0];
    expect(storedToken, sha256.string(pending.token).hex());

    Future<Object> attempt(PostgresAccountStore store) async {
      try {
        return await store.create(
            'concurrent@example.test', hash, sessions.prepareToken());
      } on EmailInUseException catch (error) {
        return error;
      }
    }

    final outcomes =
        await Future.wait([attempt(firstStore), attempt(secondStore)]);
    expect(outcomes.whereType<String>(), hasLength(1));
    expect(outcomes.whereType<EmailInUseException>(), hasLength(1));

    await expectLater(firstStore.create('rollback@example.test', hash, pending),
        throwsA(isA<AccountStorageException>()));
    expect(await firstStore.findByEmail('rollback@example.test'), isNull);
    expect((await sessions.authenticate(pending.token)).userId, userId);
    expect((await firstStore.findByEmail('person@example.test'))?.id, userId);
  },
      skip: databaseUrl == null || databaseUrl.isEmpty
          ? 'Set TEST_DATABASE_URL to an isolated PostgreSQL database with schema privileges.'
          : false);
}
