import 'dart:async';
import 'dart:convert';

import 'package:lost_and_found_api/src/auth/auth_attempt_limiter.dart';
import 'package:lost_and_found_api/src/auth/auth_service.dart';
import 'package:lost_and_found_api/src/auth/data/password_hasher.dart';
import 'package:lost_and_found_api/src/auth/session_service.dart';
import 'package:lost_and_found_api/src/config/app_config.dart';
import 'package:lost_and_found_api/src/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/memory_account_store.dart';
import '../support/memory_session_store.dart';

class _GateHasher extends PasswordHasher {
  final started = Completer<void>();
  final release = Completer<String>();

  @override
  Future<String> hash(String password) {
    if (!started.isCompleted) started.complete();
    return release.future;
  }
}

void main() {
  late MemorySessionStore sessionStore;
  late MemoryAccountStore accounts;
  late Handler handler;
  final validInput = {'email': 'person@example.test', 'password': ' password '};

  Future<Response> post(String path, Object? payload,
      {Map<String, String>? headers}) async {
    return handler(Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {'content-type': 'application/json', ...?headers},
      body: jsonEncode(payload),
    ));
  }

  Future<Map<String, Object?>> body(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, Object?>;

  setUp(() {
    sessionStore = MemorySessionStore();
    accounts = MemoryAccountStore(sessionStore);
    final sessions = SessionService(
        store: sessionStore, clock: () => DateTime.utc(2026, 11, 1, 12));
    handler = buildServerHandler(
      AppConfig.fromEnvironment({}),
      sessions: sessions,
      auth: AuthService(accounts: accounts, sessions: sessions),
      authAttempts: AuthAttemptLimiter(
          registerLimit: 100, loginAddressLimit: 100, loginEmailLimit: 100),
    );
  });

  test('registration and login return public identity, token and expiration',
      () async {
    final response = await post('/auth/register', validInput);
    expect(response.statusCode, 201);
    expect(response.headers['cache-control'], 'no-store');
    final registered = await body(response);
    expect(registered.keys, unorderedEquals(['user', 'token', 'expiresAt']));
    expect(registered['user'], {'id': 'test-user-1'});
    expect(registered['expiresAt'], '2026-11-02T12:00:00.000Z');
    final token = registered['token'] as String;
    final restored = await handler(Request(
        'GET', Uri.parse('http://localhost/auth/session'),
        headers: {'authorization': 'Bearer $token'}));
    expect(restored.statusCode, 200);

    final login = await post('/auth/login', {
      'email': ' PERSON@EXAMPLE.TEST ',
      'password': ' password ',
    });
    expect(login.statusCode, 200);
    expect(login.headers['cache-control'], 'no-store');
    final loggedIn = await body(login);
    expect(loggedIn['token'], isNot(token));
    expect(loggedIn['user'], registered['user']);
  });

  for (final invalid in <Map<String, Object?>>[
    {},
    {'email': 'invalid', 'password': 'password'},
    {'email': 'person@example.test', 'password': '1234567'},
    {'email': 'person@example.test', 'password': '        '},
    {'email': 123, 'password': true},
  ]) {
    test(
        'invalid registration fields return actionable errors without persistence',
        () async {
      final response = await post('/auth/register', invalid);
      expect(response.statusCode, 400);
      final error = (await body(response))['error'] as Map<String, Object?>;
      expect(error['code'], 'invalid_request');
      expect(error['fields'], isA<Map<String, Object?>>());
      expect(accounts.accounts, isEmpty);
      expect(sessionStore.sessions, isEmpty);
    });
  }

  test('rejects confirmation, supplied identity and other unexpected fields',
      () async {
    for (final field in ['confirmation', 'userId', 'created_by']) {
      expect(
          (await post('/auth/register', {...validInput, field: 'forged'}))
              .statusCode,
          400);
    }
    expect(accounts.accounts, isEmpty);
  });

  test('duplicate normalized email returns 409 without a second session',
      () async {
    await post('/auth/register', validInput);
    final response = await post(
        '/auth/register', {...validInput, 'email': ' PERSON@EXAMPLE.TEST '});
    expect(response.statusCode, 409);
    expect((await body(response))['error'], {
      'code': 'email_in_use',
      'message': 'Este e-mail já está cadastrado.',
    });
    expect(accounts.accounts, hasLength(1));
    expect(sessionStore.sessions, hasLength(1));
  });

  test('wrong password and unknown email return the same generic 401',
      () async {
    await post('/auth/register', validInput);
    final wrong =
        await post('/auth/login', {...validInput, 'password': 'wrong'});
    final unknown = await post(
        '/auth/login', {...validInput, 'email': 'unknown@example.test'});
    expect(wrong.statusCode, 401);
    expect(unknown.statusCode, 401);
    expect(await body(wrong), await body(unknown));
    expect(sessionStore.sessions, hasLength(1));
  });

  test(
      'failed storage is retryable and cannot return a token or partial account',
      () async {
    accounts.unavailable = true;
    final response = await post('/auth/register', validInput);
    expect(response.statusCode, 503);
    expect((await body(response)).keys, ['error']);
    expect(accounts.accounts, isEmpty);
    expect(sessionStore.sessions, isEmpty);
    accounts.unavailable = false;
    expect((await post('/auth/register', validInput)).statusCode, 201);
  });

  test(
      'attempt limits apply before expensive operations and cannot be reset by forwarded headers',
      () async {
    handler = buildServerHandler(
        AppConfig.fromEnvironment({'AUTH_REGISTER_LIMIT': '1'}));
    expect((await post('/auth/register', validInput)).statusCode, 503);
    final denied = await post('/auth/register', validInput,
        headers: {'x-forwarded-for': '203.0.113.99'});
    expect(denied.statusCode, 429);
    expect(int.parse(denied.headers['retry-after']!), greaterThan(0));
    expect(denied.headers['cache-control'], 'no-store');
    expect((await body(denied))['error'], {
      'code': 'too_many_attempts',
      'message': 'Muitas tentativas. Aguarde e tente novamente.',
    });
  });

  test(
      'limits normalized login email independently of the source address budget',
      () async {
    final sessions = SessionService(store: sessionStore);
    handler = buildServerHandler(
      AppConfig.fromEnvironment({}),
      sessions: sessions,
      auth: AuthService(accounts: accounts, sessions: sessions),
      authAttempts:
          AuthAttemptLimiter(loginEmailLimit: 1, loginAddressLimit: 100),
    );
    await post('/auth/register', validInput);
    expect(
        (await post('/auth/login', {...validInput, 'password': 'wrong'}))
            .statusCode,
        401);
    expect(
        (await post('/auth/login',
                {...validInput, 'email': ' PERSON@example.test '}))
            .statusCode,
        429);
    expect(sessionStore.sessions, hasLength(1));
  });

  test(
      'simultaneous duplicate registrations produce one account and one session',
      () async {
    final outcomes = await Future.wait([
      post('/auth/register', validInput),
      post('/auth/register', {...validInput, 'email': ' PERSON@EXAMPLE.TEST '}),
    ]);
    expect(outcomes.map((response) => response.statusCode),
        unorderedEquals([201, 409]));
    expect(accounts.accounts, hasLength(1));
    expect(sessionStore.sessions, hasLength(1));
  });

  test(
      'busy hashing returns a retryable 503 and releases capacity on completion',
      () async {
    final sessions = SessionService(store: sessionStore);
    final hasher = _GateHasher();
    handler = buildServerHandler(
      AppConfig.fromEnvironment({}),
      sessions: sessions,
      auth: AuthService(
          accounts: accounts,
          sessions: sessions,
          passwords: hasher,
          maxConcurrentOperations: 1),
    );
    final first = post('/auth/register', validInput);
    await hasher.started.future;
    final busy = await post(
        '/auth/register', {...validInput, 'email': 'second@example.test'});
    expect(busy.statusCode, 503);
    expect(busy.headers['retry-after'], '1');
    expect(accounts.accounts, isEmpty);
    hasher.release.complete('controlled-test-hash');
    expect((await first).statusCode, 201);
    expect(
        (await post('/auth/register',
                {...validInput, 'email': 'second@example.test'}))
            .statusCode,
        201);
  });

  test(
      'rejects malformed, oversized, non-object and unsupported request bodies',
      () async {
    for (final sample in [
      ('invalid-json', 'application/json', 400),
      ('[]', 'application/json', 400),
      ('null', 'application/json', 400),
      ('{}', 'text/plain', 415),
      (' ' * 8193, 'application/json', 413),
    ]) {
      final response = await handler(Request(
          'POST', Uri.parse('http://localhost/auth/register'),
          headers: {'content-type': sample.$2}, body: sample.$1));
      expect(response.statusCode, sample.$3);
    }
    final timedOut = await handler(Request(
        'POST', Uri.parse('http://localhost/auth/register'),
        headers: {'content-type': 'application/json'},
        body: Stream<List<int>>.error(TimeoutException('private details'))));
    expect(timedOut.statusCode, 408);
    expect(accounts.accounts, isEmpty);
  });
}
