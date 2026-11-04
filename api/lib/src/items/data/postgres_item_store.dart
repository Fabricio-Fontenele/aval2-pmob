import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../../db/database_client.dart';
import '../domain/item.dart';
import '../domain/item_store.dart';

class PostgresItemStore implements ItemStore {
  final DatabaseClient _database;

  const PostgresItemStore(this._database);

  @override
  Future<List<LostFoundItem>> listItems() async {
    final result = await _execute(
      '''
SELECT id, name, description, location, status, created_at, created_by
FROM items
ORDER BY created_at DESC;
''',
      {},
    );

    return result.map((rowResult) {
      final row = rowResult.toColumnMap();
      return LostFoundItem(
        id: row['id'].toString(),
        name: row['name'] as String,
        description: row['description'] as String,
        location: row['location'] as String,
        status: ItemStatus.tryParse(row['status'] as String) ?? ItemStatus.lost,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        createdBy: row['created_by'].toString(),
      );
    }).toList();
  }

  @override
  Future<LostFoundItem> createItem(NewItem item,
      {required String userId}) async {
    final result = await _execute(
      '''
INSERT INTO items (name, description, location, status, created_by)
VALUES (@name, @description, @location, @status, @createdBy)
RETURNING id, name, description, location, status, created_at, created_by;
''',
      {
        'name': item.name,
        'description': item.description,
        'location': item.location,
        'status': item.status.name,
        'createdBy': userId,
      },
    );

    final row = result.single.toColumnMap();
    return LostFoundItem(
      id: row['id'].toString(),
      name: row['name'] as String,
      description: row['description'] as String,
      location: row['location'] as String,
      status: ItemStatus.tryParse(row['status'] as String) ?? ItemStatus.lost,
      createdAt: (row['created_at'] as DateTime).toUtc(),
      createdBy: row['created_by'].toString(),
    );
  }

  Future<Result> _execute(String sql, Map<String, Object?> parameters) async {
    try {
      return await _database.execute(sql, parameters: parameters);
    } on PgException catch (e) {
      throw ItemStorageException(e.message, e);
    } on IOException catch (e) {
      throw ItemStorageException('I/O error during database operation', e);
    } on TimeoutException catch (e) {
      throw ItemStorageException('Database operation timed out', e);
    }
  }
}
