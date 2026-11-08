import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lost_and_found/features/auth/data/http_auth_repository.dart';
import 'package:lost_and_found/features/auth/data/session_token_store.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';
import 'package:lost_and_found/features/auth/domain/auth_user.dart';

class _TokenStore implements SessionTokenStore {
  String? token;
  Future<void> Function(String)? beforeWrite;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async {
    await beforeWrite?.call(token);
    this.token = token;
  }

  @override
  Future<void> deleteToken() async => token = null;
}

const _token = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';
const _user = AuthUser(id: '00000000-0000-4000-8000-000000000001');

http.Response _sessionResponse({
  int status = 200,
  bool includeToken = true,
  String token = _token,
}) {
  return http.Response(
    jsonEncode({
      'user': {'id': _user.id},
      if (includeToken) 'token': token,
      'expiresAt': '2026-11-10T12:00:00.000Z',
    }),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('a timed-out login is not retried and a late response cannot save its token', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final store = _TokenStore()..token = _token;
    final client = MockClient((_) {
      requests++;
      return response.future;
    });
    addTearDown(client.close);
    final repository = HttpAuthRepository(
      baseUrl: Uri.parse('https://api.example.test'),
      client: client,
      tokenStore: store,
      requestTimeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      repository.login(email: 'person@example.test', password: 'password'),
      throwsA(
        isA<AuthRepositoryException>().having(
          (error) => error.code,
          'code',
          AuthFailureCode.networkError,
        ),
      ),
    );
    response.complete(
      _sessionResponse(token: 'Zbcdefghijklmnopqrstuvwxyz0123456789ABCDEFG'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(await store.readToken(), _token);
    expect(requests, 1);
  });

  test('authentication can be retried after a secure write fails', () async {
    final store = _TokenStore()
      ..beforeWrite = (_) async =>
          throw const AuthRepositoryException.storage();
    final client = MockClient((_) async => _sessionResponse());
    addTearDown(client.close);
    final repository = HttpAuthRepository(
      baseUrl: Uri.parse('https://api.example.test'),
      client: client,
      tokenStore: store,
    );
    await expectLater(
      repository.login(email: 'person@example.test', password: 'password'),
      throwsA(
        isA<AuthRepositoryException>().having(
          (error) => error.code,
          'code',
          AuthFailureCode.storageError,
        ),
      ),
    );
    expect(await store.readToken(), isNull);
    store.beforeWrite = null;
    expect(
      await repository.login(
        email: 'person@example.test',
        password: 'password',
      ),
      _user,
    );
    expect(await store.readToken(), _token);
  });

  test(
    'the item adapter can obtain and conditionally invalidate its bearer token',
    () async {
      final store = _TokenStore()..token = _token;
      final client = MockClient((_) async {
        fail('Token access must not create network requests.');
      });
      addTearDown(client.close);
      final repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );
      expect(await repository.getSessionToken(), _token);
      expect(
        await repository.invalidateSession('older-rejected-token'),
        isFalse,
      );
      expect(await repository.getSessionToken(), _token);
      expect(await repository.invalidateSession(_token), isTrue);
      expect(await repository.getSessionToken(), isNull);
    },
  );

  test(
    'no saved session needs neither a restore nor a logout request',
    () async {
      final client = MockClient((_) async {
        fail('There is no session to send.');
      });
      addTearDown(client.close);
      final repository = HttpAuthRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8080'),
        client: client,
        tokenStore: _TokenStore(),
      );
      expect(await repository.restoreSession(), isNull);
      await repository.logout();
    },
  );

  test(
    'environment configuration is required and uses the public API address',
    () async {
      const address = String.fromEnvironment('API_BASE_URL');
      final client = MockClient((request) async {
        expect(request.url.origin, Uri.parse(address).origin);
        return _sessionResponse();
      });
      addTearDown(client.close);
      if (address.isEmpty) {
        expect(
          () => HttpAuthRepository.fromEnvironment(
            client: client,
            tokenStore: _TokenStore(),
          ),
          throwsStateError,
        );
      } else {
        final repository = HttpAuthRepository.fromEnvironment(
          client: client,
          tokenStore: _TokenStore(),
        );
        expect(
          await repository.login(
            email: 'person@example.test',
            password: 'password',
          ),
          _user,
        );
      }
    },
  );

  test(
    'a corrupted local token is removed without sending it to the API',
    () async {
      final store = _TokenStore()..token = 'not-a-session-token';
      final client = MockClient((_) async {
        fail('Corrupted token must not leave the device.');
      });
      addTearDown(client.close);
      final repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );
      expect(await repository.restoreSession(), isNull);
      expect(await store.readToken(), isNull);
    },
  );

  for (final (label, address) in [
    ('remote HTTP', 'http://api.example.test'),
    ('unsupported scheme', 'file:///tmp/api'),
    ('embedded credentials', 'https://user:password@api.example.test'),
    ('query parameters', 'https://api.example.test?token=private'),
    ('fragment', 'https://api.example.test#fragment'),
  ]) {
    test('rejects unsafe or ambiguous API configuration: $label', () {
      final client = MockClient((_) async => _sessionResponse());
      addTearDown(client.close);
      expect(
        () => HttpAuthRepository(
          baseUrl: Uri.parse(address),
          client: client,
          tokenStore: _TokenStore(),
        ),
        throwsArgumentError,
      );
    });
  }

  test('preserves an API base path without following redirects', () async {
    final client = MockClient((request) async {
      expect(request.url, Uri.parse('https://api.example.test/v1/auth/login'));
      expect(request.followRedirects, isFalse);
      return _sessionResponse();
    });
    addTearDown(client.close);
    final repository = HttpAuthRepository(
      baseUrl: Uri.parse('https://api.example.test/v1'),
      client: client,
      tokenStore: _TokenStore(),
    );
    expect(
      await repository.login(
        email: 'person@example.test',
        password: 'password',
      ),
      _user,
    );
  });

  test(
    'logout waits for a pending secure write and leaves no restorable token',
    () async {
      final writing = Completer<void>();
      final release = Completer<void>();
      final store = _TokenStore()
        ..beforeWrite = (_) {
          writing.complete();
          return release.future;
        };
      final client = MockClient(
        (request) async => request.url.path == '/auth/logout'
            ? http.Response('', 204)
            : _sessionResponse(),
      );
      addTearDown(client.close);
      final repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );
      final login = repository.login(
        email: 'person@example.test',
        password: 'password',
      );
      final rejected = expectLater(
        login,
        throwsA(
          isA<AuthRepositoryException>().having(
            (error) => error.isInvalidSession,
            'superseded session',
            isTrue,
          ),
        ),
      );
      await writing.future;
      final logout = repository.logout();
      release.complete();
      await Future.wait([logout, rejected]);
      expect(await store.readToken(), isNull);
    },
  );

  test(
    'a login response arriving after logout cannot recreate a local session',
    () async {
      final store = _TokenStore();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final client = MockClient((_) {
        started.complete();
        return response.future;
      });
      addTearDown(client.close);
      final repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );
      final login = repository.login(
        email: 'person@example.test',
        password: 'password',
      );
      final rejected = expectLater(
        login,
        throwsA(
          isA<AuthRepositoryException>().having(
            (error) => error.isInvalidSession,
            'superseded session',
            isTrue,
          ),
        ),
      );
      await started.future;
      await repository.logout();
      response.complete(_sessionResponse());
      await rejected;
      expect(await store.readToken(), isNull);
    },
  );

  for (final operation in ['restore', 'logout']) {
    test(
      'a late $operation response cannot delete a newer login token',
      () async {
        const nextToken = 'Zbcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';
        final store = _TokenStore()..token = _token;
        final response = Completer<http.Response>();
        final started = Completer<void>();
        final client = MockClient((request) {
          if (request.url.path == '/auth/login') {
            return Future.value(_sessionResponse(token: nextToken));
          }
          started.complete();
          return response.future;
        });
        addTearDown(client.close);
        final repository = HttpAuthRepository(
          baseUrl: Uri.parse('https://api.example.test'),
          client: client,
          tokenStore: store,
        );
        final pending = operation == 'restore'
            ? repository.restoreSession()
            : repository.logout();
        await started.future;
        await repository.login(
          email: 'person@example.test',
          password: 'password',
        );
        response.complete(
          http.Response('', operation == 'restore' ? 401 : 204),
        );
        await pending;
        expect(await store.readToken(), nextToken);
      },
    );
  }

  for (final invalid in [
    '<html>gateway</html>',
    '[]',
    jsonEncode({
      'user': {'id': _user.id},
      'token': _token,
    }),
    jsonEncode({
      'user': {'id': ''},
      'token': _token,
      'expiresAt': '2026-11-10T12:00:00Z',
    }),
    jsonEncode({
      'user': {'id': _user.id},
      'token': 'malformed',
      'expiresAt': '2026-11-10T12:00:00Z',
    }),
    jsonEncode({
      'user': {'id': _user.id},
      'token': _token,
      'expiresAt': 'invalid',
    }),
  ]) {
    test(
      'malformed success cannot authenticate or overwrite a saved token: $invalid',
      () async {
        final store = _TokenStore()..token = _token;
        final client = MockClient((_) async => http.Response(invalid, 200));
        addTearDown(client.close);
        final AuthRepository repository = HttpAuthRepository(
          baseUrl: Uri.parse('https://api.example.test'),
          client: client,
          tokenStore: store,
        );
        await expectLater(
          repository.login(email: 'person@example.test', password: 'password'),
          throwsA(
            isA<AuthRepositoryException>().having(
              (error) => error.code,
              'code',
              AuthFailureCode.serviceUnavailable,
            ),
          ),
        );
        expect(await store.readToken(), _token);
      },
    );
  }

  for (final operation in ['login', 'restore', 'logout']) {
    test(
      '$operation translates transport failures and keeps the saved token',
      () async {
        final store = _TokenStore()..token = _token;
        final client = MockClient(
          (_) async => throw http.ClientException('private network detail'),
        );
        addTearDown(client.close);
        final AuthRepository repository = HttpAuthRepository(
          baseUrl: Uri.parse('https://api.example.test'),
          client: client,
          tokenStore: store,
        );
        final Future<Object?> result = switch (operation) {
          'login' => repository.login(
            email: 'person@example.test',
            password: 'password',
          ),
          'restore' => repository.restoreSession(),
          _ => repository.logout(),
        };
        await expectLater(
          result,
          throwsA(
            isA<AuthRepositoryException>().having(
              (error) => error.code,
              'code',
              AuthFailureCode.networkError,
            ),
          ),
        );
        expect(await store.readToken(), _token);
      },
    );
  }

  for (final operation in ['restore', 'logout']) {
    for (final status in [401, 503]) {
      test(
        '$operation handles HTTP $status without confusing rejection and outage',
        () async {
          final store = _TokenStore()..token = _token;
          final client = MockClient(
            (_) async => http.Response('<html>gateway</html>', status),
          );
          addTearDown(client.close);
          final AuthRepository repository = HttpAuthRepository(
            baseUrl: Uri.parse('https://api.example.test'),
            client: client,
            tokenStore: store,
          );
          if (status == 401) {
            if (operation == 'restore') {
              expect(await repository.restoreSession(), isNull);
            } else {
              await repository.logout();
            }
            expect(await store.readToken(), isNull);
          } else {
            await expectLater(
              operation == 'restore'
                  ? repository.restoreSession()
                  : repository.logout(),
              throwsA(
                isA<AuthRepositoryException>().having(
                  (error) => error.code,
                  'code',
                  AuthFailureCode.serviceUnavailable,
                ),
              ),
            );
            expect(await store.readToken(), _token);
          }
        },
      );
    }
  }

  for (final (status, code) in [
    (400, AuthFailureCode.invalidRequest),
    (408, AuthFailureCode.invalidRequest),
    (413, AuthFailureCode.invalidRequest),
    (415, AuthFailureCode.invalidRequest),
    (401, AuthFailureCode.invalidCredentials),
    (409, AuthFailureCode.emailInUse),
    (429, AuthFailureCode.tooManyAttempts),
    (503, AuthFailureCode.serviceUnavailable),
    (502, AuthFailureCode.serviceUnavailable),
  ]) {
    test(
      'HTTP $status becomes $code without replacing an existing session',
      () async {
        final store = _TokenStore()..token = _token;
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'server_error',
                'message': 'Public error',
                'fields': {'email': 'Informe um e-mail válido.'},
              },
            }),
            status,
            headers: {
              'retry-after': '30',
              'content-type': 'application/json; charset=utf-8',
            },
          ),
        );
        addTearDown(client.close);
        final AuthRepository repository = HttpAuthRepository(
          baseUrl: Uri.parse('https://api.example.test'),
          client: client,
          tokenStore: store,
        );
        await expectLater(
          repository.login(email: 'person@example.test', password: 'password'),
          throwsA(
            isA<AuthRepositoryException>()
                .having((error) => error.code, 'code', code)
                .having(
                  (error) => error.retryAfterSeconds,
                  'retry delay',
                  status == 429 ? 30 : null,
                )
                .having(
                  (error) => error.fieldErrors,
                  'field errors',
                  [400, 408, 413, 415].contains(status)
                      ? {'email': 'Informe um e-mail válido.'}
                      : isEmpty,
                ),
          ),
        );
        expect(await store.readToken(), _token);
      },
    );
  }

  test(
    'logout revokes the server session before removing the saved token',
    () async {
      final store = _TokenStore()..token = _token;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/logout');
        expect(request.headers['authorization'], 'Bearer $_token');
        expect(await store.readToken(), _token);
        return http.Response('', 204);
      });
      addTearDown(client.close);
      final AuthRepository repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );

      await repository.logout();
      expect(await store.readToken(), isNull);
    },
  );

  test(
    'a new repository restores the saved token only after remote validation',
    () async {
      final store = _TokenStore()..token = _token;
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/auth/session');
        expect(request.headers['authorization'], 'Bearer $_token');
        expect(request.body, isEmpty);
        return _sessionResponse(includeToken: false);
      });
      addTearDown(client.close);
      final AuthRepository repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );

      expect(await repository.restoreSession(), _user);
      expect(await store.readToken(), _token);
    },
  );

  test(
    'login replaces the stored token after successful authentication',
    () async {
      final store = _TokenStore()..token = 'previous-session';
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/login');
        expect(jsonDecode(request.body), {
          'email': 'person@example.test',
          'password': ' original password ',
        });
        return _sessionResponse();
      });
      addTearDown(client.close);
      final AuthRepository repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );

      expect(
        await repository.login(
          email: ' Person@Example.Test ',
          password: ' original password ',
        ),
        _user,
      );
      expect(await store.readToken(), _token);
    },
  );

  test(
    'registration returns the user and saves only the issued token',
    () async {
      final store = _TokenStore();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url,
          Uri.parse('https://api.example.test/auth/register'),
        );
        expect(request.headers['content-type'], contains('application/json'));
        expect(request.headers, isNot(contains('authorization')));
        expect(jsonDecode(request.body), {
          'email': 'person@example.test',
          'password': ' original password ',
        });
        return _sessionResponse(status: 201);
      });
      addTearDown(client.close);
      final AuthRepository repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
        tokenStore: store,
      );

      expect(
        await repository.register(
          email: ' Person@Example.Test ',
          password: ' original password ',
        ),
        _user,
      );
      expect(await store.readToken(), _token);
    },
  );
}
