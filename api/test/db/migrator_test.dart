import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:lost_and_found_api/src/db/migrator.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

class RecordingDatabaseClient implements DatabaseClient {
  final List<String> executedQueries = [];

  @override
  Future<bool> checkConnection() async => true;

  @override
  Future<Result> execute(String query,
      {Map<String, dynamic>? parameters}) async {
    executedQueries.add(query);
    return FakeResult();
  }

  @override
  Future<void> close() async {}
}

class FakeResult implements Result {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isEmpty => false;

  @override
  bool get isNotEmpty => true;
}

void main() {
  group('Database Migrator & Schema', () {
    test('contains all required tables and constraints in schema', () {
      final schema = DatabaseMigrator.initialSchemaSql;

      expect(schema, contains('CREATE TABLE IF NOT EXISTS users'));
      expect(schema, contains('CREATE TABLE IF NOT EXISTS sessions'));
      expect(schema, contains('CREATE TABLE IF NOT EXISTS items'));

      expect(schema, contains('char_length(name) <= 60'));
      expect(schema, contains('char_length(description) <= 200'));
      expect(schema, contains("status IN ('lost', 'found')"));
      expect(schema, contains('REFERENCES users(id)'));
    });

    test('applies initial schema migration when run', () async {
      final db = RecordingDatabaseClient();
      final migrator = DatabaseMigrator(db);

      await migrator.runMigrations();

      expect(db.executedQueries, isNotEmpty);
      expect(db.executedQueries.first, contains('CREATE TABLE IF NOT EXISTS'));
    });
  });
}
