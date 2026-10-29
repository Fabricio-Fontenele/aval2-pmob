import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseClient & Endpoint Parser', () {
    test('correctly parses postgresql URL with credentials and port', () {
      const url =
          'postgresql://admin:supersecret@db.host.internal:5433/lostfound';
      final endpoint = PostgreSqlDatabaseClient.parseEndpoint(url);

      expect(endpoint.host, equals('db.host.internal'));
      expect(endpoint.port, equals(5433));
      expect(endpoint.database, equals('lostfound'));
      expect(endpoint.username, equals('admin'));
      expect(endpoint.password, equals('supersecret'));
    });

    test('uses default port 5432 when port is omitted in URL', () {
      const url = 'postgres://user:pass@db.example.com/production_db';
      final endpoint = PostgreSqlDatabaseClient.parseEndpoint(url);

      expect(endpoint.host, equals('db.example.com'));
      expect(endpoint.port, equals(5432));
      expect(endpoint.database, equals('production_db'));
      expect(endpoint.username, equals('user'));
      expect(endpoint.password, equals('pass'));
    });

    test('determines SslMode correctly from URL parameters', () {
      const sslUrl = 'postgresql://user:pass@host:5432/db?sslmode=require';
      expect(
        PostgreSqlDatabaseClient.resolveSslMode(sslUrl),
        equals(SslMode.require),
      );

      const disableUrl = 'postgresql://user:pass@host:5432/db?sslmode=disable';
      expect(
        PostgreSqlDatabaseClient.resolveSslMode(disableUrl),
        equals(SslMode.disable),
      );

      const defaultUrl = 'postgresql://user:pass@host:5432/db';
      expect(
        PostgreSqlDatabaseClient.resolveSslMode(defaultUrl),
        equals(SslMode.require),
      );
    });

    test('FakeDatabaseClient reports mocked connection status', () async {
      final connectedClient = FakeDatabaseClient(isConnected: true);
      expect(await connectedClient.checkConnection(), isTrue);

      final disconnectedClient = FakeDatabaseClient(isConnected: false);
      expect(await disconnectedClient.checkConnection(), isFalse);
    });
  });
}
