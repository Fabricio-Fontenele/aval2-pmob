import 'dart:async';
import 'dart:io';

import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:lost_and_found_api/src/items/data/postgres_item_store.dart';
import 'package:lost_and_found_api/src/items/domain/item.dart';
import 'package:lost_and_found_api/src/items/domain/item_store.dart';
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
    PgException('database error'),
    const SocketException('connection error'),
    TimeoutException('timeout'),
  ]) {
    test(
        'translates ${failure.runtimeType} to ItemStorageException for list and create operations',
        () async {
      final store = PostgresItemStore(FailingDatabaseClient(failure));
      final newItem = NewItem.validate(
        name: 'Objeto de teste',
        description: 'Descrição de teste',
        location: 'Local de teste',
        status: 'lost',
      );

      await expectLater(
        store.listItems(),
        throwsA(isA<ItemStorageException>()),
      );
      await expectLater(
        store.createItem(newItem, userId: 'user-id-123'),
        throwsA(isA<ItemStorageException>()),
      );
    });
  }
}
