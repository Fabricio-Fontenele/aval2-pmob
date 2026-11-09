import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api_base_url.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/session_token_provider.dart';
import 'session_token_store.dart';

class HttpAuthRepository implements AuthRepository, SessionTokenProvider {
  HttpAuthRepository({
    required Uri baseUrl,
    required this._client,
    required this._tokenStore,
    Duration requestTimeout = const Duration(seconds: 75),
  }) : _baseUrl = ApiBaseUrl.normalize(baseUrl),
       _requestTimeout = requestTimeout {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError('requestTimeout must be positive.');
    }
  }

  factory HttpAuthRepository.fromEnvironment({
    required http.Client client,
    required SessionTokenStore tokenStore,
    Duration requestTimeout = const Duration(seconds: 75),
  }) {
    return HttpAuthRepository(
      baseUrl: ApiBaseUrl.fromEnvironment(),
      client: client,
      tokenStore: tokenStore,
      requestTimeout: requestTimeout,
    );
  }

  final Uri _baseUrl;
  final http.Client _client;
  final SessionTokenStore _tokenStore;
  final Duration _requestTimeout;
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static const _invalidResponse = AuthRepositoryException.serviceUnavailable(
    'O servidor retornou uma resposta inválida. Tente novamente.',
  );
  int _sessionEpoch = 0;
  Future<void> _tokenOperations = Future<void>.value();

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) => _authenticate('auth/register', email, password, expectedStatus: 201);

  @override
  Future<AuthUser> login({required String email, required String password}) =>
      _authenticate('auth/login', email, password);

  Future<AuthUser> _authenticate(
    String path,
    String email,
    String password, {
    int expectedStatus = 200,
  }) async {
    final operationEpoch = ++_sessionEpoch;
    final response = await _send(
      'POST',
      path,
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );
    if (response.statusCode != expectedStatus) throw _failure(response);
    final (user, token) = _readSession(response);
    if (token == null || !_tokenPattern.hasMatch(token)) throw _invalidResponse;
    await _withTokens(() async {
      _requireCurrent(operationEpoch);
      await _tokenStore.writeToken(token);
    });
    _requireCurrent(operationEpoch);
    return user;
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final operationEpoch = _sessionEpoch;
    final token = await getSessionToken();
    if (token == null) return null;
    final response = await _send('GET', 'auth/session', token: token);
    if (response.statusCode == 401) {
      await invalidateSession(token);
      return null;
    }
    if (response.statusCode != 200) throw _failure(response);
    final (user, _) = _readSession(response);
    return _withTokens(() async {
      if (operationEpoch != _sessionEpoch ||
          await _tokenStore.readToken() != token) {
        return null;
      }
      return user;
    });
  }

  @override
  Future<void> logout() async {
    final operationEpoch = ++_sessionEpoch;
    final token = await getSessionToken();
    if (token == null) return;
    final response = await _send('POST', 'auth/logout', token: token);
    if (response.statusCode != 204 && response.statusCode != 401) {
      throw _failure(response);
    }
    if (operationEpoch == _sessionEpoch) await invalidateSession(token);
  }

  /// Clears a rejected bearer token without discarding a newer session.
  @override
  Future<bool> invalidateSession(String rejectedToken) => _withTokens(() async {
    if (await _tokenStore.readToken() != rejectedToken) return false;
    await _tokenStore.deleteToken();
    return true;
  });

  /// Supplies the bearer credential to data adapters; it does not validate it remotely.
  @override
  Future<String?> getSessionToken() => _withTokens(() async {
    final token = await _tokenStore.readToken();
    if (token == null) return null;
    if (_tokenPattern.hasMatch(token)) return token;
    await _tokenStore.deleteToken();
    return null;
  });

  Future<T> _withTokens<T>(Future<T> Function() operation) {
    // Serialize secure writes and compare/delete pairs so logout cannot race them.
    final result = _tokenOperations.then((_) => operation());
    _tokenOperations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        // The caller receives the original failure; subsequent operations may retry.
      },
    );
    return result;
  }

  void _requireCurrent(int operationEpoch) {
    if (operationEpoch != _sessionEpoch) {
      throw const AuthRepositoryException.invalidSession(
        'A sessão mudou. Tente entrar novamente.',
      );
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    String? token,
    Map<String, String>? body,
  }) async {
    final request = http.Request(method, _baseUrl.resolve(path))
      ..followRedirects = false
      ..headers['accept'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    Future<http.Response> send() async =>
        http.Response.fromStream(await _client.send(request));
    try {
      return await send().timeout(_requestTimeout);
    } on http.ClientException {
      throw const AuthRepositoryException.network();
    } on TimeoutException {
      throw const AuthRepositoryException.network(
        'O servidor demorou para responder. Tente novamente.',
      );
    }
  }

  (AuthUser, String?) _readSession(http.Response response) {
    try {
      final Object? body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body case {
        'user': {'id': final String id},
        'expiresAt': final String expiresAt,
      }) {
        final expiry = DateTime.tryParse(expiresAt);
        final rawToken = body['token'];
        final token = rawToken is String ? rawToken : null;
        if (id.trim().isNotEmpty && expiry != null && expiry.isUtc) {
          return (AuthUser(id: id), token);
        }
      }
    } on FormatException {
      // Invalid JSON and encoding are protocol failures, never successful login.
    }
    throw _invalidResponse;
  }

  AuthRepositoryException _failure(http.Response response) {
    switch (response.statusCode) {
      case 400:
      case 408:
      case 413:
      case 415:
        final fields = <String, String>{};
        try {
          final Object? body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body case {
            'error': {'fields': final Map<String, Object?> errors},
          }) {
            for (final key in ['email', 'password']) {
              if (errors[key] case final String message
                  when message.isNotEmpty) {
                fields[key] = message;
              }
            }
          }
        } on FormatException {
          // Gateways may return an HTML error page instead of the API envelope.
        }
        return AuthRepositoryException(
          'Confira os campos informados.',
          code: AuthFailureCode.invalidRequest,
          fieldErrors: Map.unmodifiable(fields),
        );
      case 401:
        return const AuthRepositoryException.invalidCredentials();
      case 409:
        return const AuthRepositoryException.emailInUse();
      case 429:
        final delay = int.tryParse(response.headers['retry-after'] ?? '');
        return AuthRepositoryException.tooManyAttempts(
          retryAfterSeconds: delay != null && delay > 0 ? delay : null,
        );
      default:
        return const AuthRepositoryException.serviceUnavailable();
    }
  }
}
