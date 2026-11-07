import 'dart:io';
import 'dart:math';

import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:lost_and_found_api/src/db/migrator.dart';
import 'package:lost_and_found_api/src/items/data/postgres_item_store.dart';
import 'package:lost_and_found_api/src/items/domain/item.dart';
import 'package:lost_and_found_api/src/items/domain/item_store.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../../support/connection_database_client.dart';

void main() {
  final databaseUrl = Platform.environment['TEST_DATABASE_URL'];

  test(
      'PostgreSQL persists items, orders newest first, and enforces foreign key integrity',
      () async {
    final connection = await Connection.open(
      PostgreSqlDatabaseClient.parseEndpoint(databaseUrl!),
      settings: ConnectionSettings(
        sslMode: PostgreSqlDatabaseClient.resolveSslMode(databaseUrl),
      ),
    );
    addTearDown(connection.close);

    final random = Random.secure();
    final suffix =
        List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
    final schema = 'p07_items_$suffix';
    await connection.execute('CREATE SCHEMA $schema');
    addTearDown(() => connection.execute('DROP SCHEMA $schema CASCADE'));

    await connection.execute('SET search_path TO $schema');
    final database = ConnectionDatabaseClient(connection);
    await DatabaseMigrator(database).runMigrations();

    // Create a real user to satisfy the foreign key constraint.
    final userResult = await connection.execute('''
INSERT INTO users (email, password_hash)
VALUES ('owner@example.test', 'hash123')
RETURNING id;
''');
    final userId = userResult.single[0].toString();

    final store = PostgresItemStore(database);

    final firstItem = NewItem.validate(
      name: 'Item Mais Antigo',
      description: 'Caderno de anotações esquecido na sala 101',
      location: 'Sala 101',
      status: 'lost',
    );
    final secondItem = NewItem.validate(
      name: 'Item Mais Recente',
      description: 'Mochila preta encontrada no restaurante universitário',
      location: 'Restaurante Universitário',
      status: 'found',
    );

    final createdFirst = await store.createItem(firstItem, userId: userId);
    expect(createdFirst.id, isNotEmpty);
    expect(createdFirst.name, 'Item Mais Antigo');
    expect(createdFirst.createdBy, userId);

    final createdSecond = await store.createItem(secondItem, userId: userId);
    expect(createdSecond.id, isNotEmpty);
    expect(createdSecond.name, 'Item Mais Recente');
    expect(createdSecond.createdBy, userId);

    final items = await store.listItems();
    expect(items, hasLength(2));
    // Newest first ordering:
    expect(items[0].id, createdSecond.id);
    expect(items[0].name, 'Item Mais Recente');
    expect(items[1].id, createdFirst.id);
    expect(items[1].name, 'Item Mais Antigo');

    // Foreign key integrity check: invalid user ID must throw ItemStorageException.
    const nonExistentUserId = '00000000-0000-0000-0000-000000000099';
    await expectLater(
      store.createItem(firstItem, userId: nonExistentUserId),
      throwsA(isA<ItemStorageException>()),
    );
  },
      skip: databaseUrl == null || databaseUrl.isEmpty
          ? 'Set TEST_DATABASE_URL to an isolated PostgreSQL database with schema privileges.'
          : false);
}
