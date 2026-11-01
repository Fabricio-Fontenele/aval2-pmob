import 'dart:convert';

import 'package:lost_and_found_api/src/auth/domain/auth_session.dart';
import 'package:lost_and_found_api/src/auth/domain/session_store.dart';
import 'package:lost_and_found_api/src/auth/session_http.dart';
import 'package:lost_and_found_api/src/auth/session_service.dart';
import 'package:lost_and_found_api/src/config/app_config.dart';
import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:lost_and_found_api/src/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/memory_session_store.dart';

void main() {
  test('session endpoints reject requests without a bearer token', () async {
    final handler = buildServerHandler(
      AppConfig.fromEnvironment({'ENVIRONMENT': 'test'}),
      dbClient: FakeDatabaseClient(),
    );

    for (final endpoint in [
      ('GET', '/auth/session'),
      ('POST', '/auth/logout'),
    ]) {
      final response = await handler(Request(
        endpoint.$1,
        Uri.parse('http://localhost${endpoint.$2}'),
      ));

      expect(response.statusCode, 401);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, Object?>;
      expect(body['error'], isA<Map<String, Object?>>());
    }
  });

  group('session HTTP contract', () {
    late DateTime now;
    late MemorySessionStore store;
    late SessionService sessions;
    late Handler handler;
    late IssuedSession issued;

    setUp(() async {
      now = DateTime.utc(2026, 10, 31, 12);
      store = MemorySessionStore();
      sessions = SessionService(store: store, clock: () => now);
      handler = buildServerHandler(
        AppConfig.fromEnvironment({'ENVIRONMENT': 'test'}),
        sessions: sessions,
      );
      issued = await sessions.issue('public-user-id');
    });

    Future<Response> call(String method, String path,
        {String? authorization}) async {
      return handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'authorization': authorization ?? 'Bearer ${issued.token}'},
      ));
    }

    test('returns only public identity and UTC expiration without caching',
        () async {
      final response = await call('GET', '/auth/session');

      expect(response.statusCode, 200);
      expect(response.headers['cache-control'], 'no-store');
      expect(response.headers['content-type'], contains('application/json'));
      expect(jsonDecode(await response.readAsString()), {
        'user': {'id': 'public-user-id'},
        'expiresAt': '2026-11-01T12:00:00.000Z',
      });
    });

    test('rejects malformed, unknown and query-string tokens', () async {
      for (final authorization in [
        '',
        'Basic ${issued.token}',
        'Bearer invalid',
        'Bearer ${issued.token} extra',
        'Bearer ${'A' * 43}',
      ]) {
        final response = await call(
          'GET',
          '/auth/session?token=${issued.token}',
          authorization: authorization,
        );
        expect(response.statusCode, 401);
        expect(response.headers['www-authenticate'], 'Bearer');
        expect(response.headers['cache-control'], 'no-store');
        final body =
            jsonDecode(await response.readAsString()) as Map<String, Object?>;
        expect(
            (body['error'] as Map<String, Object?>)['code'], 'invalid_session');
      }
    });

    test('accepts a case-insensitive bearer scheme', () async {
      final response = await call(
        'GET',
        '/auth/session',
        authorization: 'bearer ${issued.token}',
      );
      expect(response.statusCode, 200);
    });

    test('logout confirms revocation and the old token can no longer be used',
        () async {
      final response = await call('POST', '/auth/logout');
      expect(response.statusCode, 204);
      expect(response.headers['cache-control'], 'no-store');
      expect(await response.readAsString(), isEmpty);
      expect((await call('GET', '/auth/session')).statusCode, 401);
      expect((await call('POST', '/auth/logout')).statusCode, 401);
      expect((await call('GET', '/health')).statusCode, 200);
    });

    test('expired sessions cannot query or logout', () async {
      now = issued.session.expiresAt;
      expect((await call('GET', '/auth/session')).statusCode, 401);
      expect((await call('POST', '/auth/logout')).statusCode, 401);
    });

    test('logout failures preserve the session and allow retry', () async {
      store.revocationFailure = const SessionStorageException();
      expect((await call('POST', '/auth/logout')).statusCode, 503);
      expect((await call('GET', '/auth/session')).statusCode, 200);

      store.revocationFailure = null;
      expect((await call('POST', '/auth/logout')).statusCode, 204);
      expect((await call('GET', '/auth/session')).statusCode, 401);
    });

    test('storage failures return retryable errors without exposing details',
        () async {
      store.failure = const SessionStorageException();
      final response = await call('GET', '/auth/session');
      expect(response.statusCode, 503);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, Object?>;
      expect(body, {
        'error': {
          'code': 'service_unavailable',
          'message': 'Serviço indisponível. Tente novamente.',
        },
      });

      store.failure = null;
      expect((await call('GET', '/auth/session')).statusCode, 200);
    });

    test('authorization middleware injects only a validated session', () async {
      var calls = 0;
      final protected = requireSession(sessions)((request) {
        calls++;
        final session = request.context[authenticatedSessionKey] as AuthSession;
        return Response.ok(session.userId);
      });

      final invalid = await protected(Request(
        'POST',
        Uri.parse('http://localhost/items'),
      ));
      expect(invalid.statusCode, 401);
      expect(calls, 0);

      final valid = await protected(Request(
        'POST',
        Uri.parse('http://localhost/items'),
        headers: {'authorization': 'Bearer ${issued.token}'},
      ));
      expect(valid.statusCode, 200);
      expect(await valid.readAsString(), 'public-user-id');
      expect(calls, 1);

      await sessions.revoke(issued.token);
      final revoked = await protected(Request(
        'POST',
        Uri.parse('http://localhost/items'),
        headers: {'authorization': 'Bearer ${issued.token}'},
      ));
      expect(revoked.statusCode, 401);
      expect(calls, 1);
    });
  });

  test('an unconfigured database cannot validate a well-formed token',
      () async {
    final handler = buildServerHandler(AppConfig.fromEnvironment({}));
    final response = await handler(Request(
      'GET',
      Uri.parse('http://localhost/auth/session'),
      headers: {'authorization': 'Bearer ${'A' * 43}'},
    ));
    expect(response.statusCode, 503);
  });
}
