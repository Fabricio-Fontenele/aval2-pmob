import 'dart:convert';
import 'package:lost_and_found_api/src/config/app_config.dart';
import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:lost_and_found_api/src/middleware/error_handler.dart';
import 'package:lost_and_found_api/src/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('HTTP Server & Health Endpoint', () {
    test('GET /health returns 200 with database disconnected when check fails',
        () async {
      final config = AppConfig.fromEnvironment({'ENVIRONMENT': 'test'});
      final fakeDb = FakeDatabaseClient(isConnected: false);
      final handler = buildServerHandler(config, dbClient: fakeDb);

      final request = Request('GET', Uri.parse('http://localhost:8080/health'));
      final response = await handler(request);

      expect(response.statusCode, equals(503));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['status'], equals('degraded'));
      expect(body['database'], equals('disconnected'));
    });

    test('GET /health returns 200 with database connected when check succeeds',
        () async {
      final config = AppConfig.fromEnvironment({'ENVIRONMENT': 'test'});
      final fakeDb = FakeDatabaseClient(isConnected: true);
      final handler = buildServerHandler(config, dbClient: fakeDb);

      final request = Request('GET', Uri.parse('http://localhost:8080/health'));
      final response = await handler(request);

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('application/json'));

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['status'], equals('ok'));
      expect(body['database'], equals('connected'));
      expect(body['environment'], equals('test'));
      expect(body['timestamp'], isNotNull);
    });

    test('GET /unknown-route returns 404 JSON response', () async {
      final config = AppConfig.fromEnvironment({'ENVIRONMENT': 'test'});
      final handler = buildServerHandler(config);

      final request =
          Request('GET', Uri.parse('http://localhost:8080/unknown-route'));
      final response = await handler(request);

      expect(response.statusCode, equals(404));
      expect(response.headers['content-type'], contains('application/json'));

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('Not Found'));
    });

    test('Unhandled exceptions return 500 JSON response', () async {
      final pipeline = const Pipeline()
          .addMiddleware(errorHandler())
          .addHandler((Request request) => throw Exception('Simulated crash'));

      final request = Request('GET', Uri.parse('http://localhost:8080/crash'));
      final response = await pipeline(request);

      expect(response.statusCode, equals(500));
      expect(response.headers['content-type'], contains('application/json'));

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('Internal Server Error'));
    });
  });
}
