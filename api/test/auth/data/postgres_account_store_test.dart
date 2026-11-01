import 'dart:async';
import 'dart:io';

import 'package:lost_and_found_api/src/auth/data/postgres_account_store.dart';
import 'package:lost_and_found_api/src/auth/domain/account_store.dart';
import 'package:lost_and_found_api/src/auth/domain/auth_session.dart';
import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

class _StubDatabase extends FakeDatabaseClient {
  Result result;
  Exception? failure;
  Map<String, Object?>? parameters;

  _StubDatabase(this.result);

  @override
  Future<Result> execute(String query,
      {Map<String, Object?>? parameters}) async {
    this.parameters = parameters;
    final error = failure;
    if (error != null) throw error;
    return result;
  }
}

Result _result(Map<String, String>? values) {
  final schema = ResultSchema([
    for (final name in values?.keys ?? <String>[])
      ResultSchemaColumn(typeOid: 25, type: Type.text, columnName: name),
  ]);
  return Result(
    rows: [
      if (values != null)
        ResultRow(values: values.values.toList(), schema: schema)
    ],
    affectedRows: values == null ? 0 : 1,
    schema: schema,
  );
}

void main() {
  final pending = PendingSession(
      token: 'opaque-token', expiresAt: DateTime.utc(2026, 11, 2));

  test('returns the committed identity and sends only a token hash to storage',
      () async {
    final database = _StubDatabase(_result({'user_id': 'user-id'}));
    final store = PostgresAccountStore(database);
    expect(await store.create('person@example.test', 'password-hash', pending),
        'user-id');
    expect(database.parameters?.values, isNot(contains(pending.token)));
    expect(database.parameters?['expiresAt'], pending.expiresAt);
  });

  test(
      'a conflicting account is rejected without reporting registration success',
      () async {
    final store = PostgresAccountStore(_StubDatabase(_result(null)));
    await expectLater(store.create('person@example.test', 'hash', pending),
        throwsA(isA<EmailInUseException>()));
  });

  test('deserializes stored credentials and returns null for an unknown email',
      () async {
    final database =
        _StubDatabase(_result({'id': 'user-id', 'password_hash': 'hash'}));
    final store = PostgresAccountStore(database);
    final account = await store.findByEmail('person@example.test');
    expect(account?.id, 'user-id');
    expect(account?.passwordHash, 'hash');
    database.result = _result(null);
    expect(await store.findByEmail('unknown@example.test'), isNull);
  });

  for (final failure in <Exception>[
    PgException('private database details'),
    const SocketException('private connection details'),
    TimeoutException('private timeout details'),
  ]) {
    test('translates ${failure.runtimeType} without leaking private details',
        () async {
      final database = _StubDatabase(_result(null))..failure = failure;
      final store = PostgresAccountStore(database);
      await expectLater(store.create('person@example.test', 'hash', pending),
          throwsA(isA<AccountStorageException>()));
      await expectLater(store.findByEmail('person@example.test'),
          throwsA(isA<AccountStorageException>()));
    });
  }
}
