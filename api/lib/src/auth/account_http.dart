import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'auth_attempt_limiter.dart';
import 'auth_client_address.dart';
import 'auth_service.dart';
import 'domain/account_store.dart';
import 'domain/auth_credentials.dart';
import 'domain/session_store.dart';

class AccountEndpoints {
  static const maxBodyBytes = 8192;
  final AuthService? _auth;
  final AuthAttemptLimiter _attempts;
  final Set<String> _trustedProxies;

  AccountEndpoints({
    required AuthService? auth,
    required AuthAttemptLimiter attempts,
    Set<String> trustedProxies = const {},
  })  : _auth = auth,
        _attempts = attempts,
        _trustedProxies = Set.unmodifiable(trustedProxies);

  Future<Response> register(Request request) =>
      _handle(request, AuthAction.register);
  Future<Response> login(Request request) => _handle(request, AuthAction.login);

  Future<Response> _handle(Request request, AuthAction action) async {
    try {
      _attempts.recordAddressAttempt(
          action, authClientAddress(request, trustedProxies: _trustedProxies));
      final contentType = request.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType != 'application/json') {
        return _error(
            415, 'invalid_request', 'Envie os dados em formato JSON.');
      }
      final values = await _readBody(request);
      final credentials = AuthCredentials.validate(
        email: values['email'],
        password: values['password'],
        action: action,
      );
      if (action == AuthAction.login) {
        _attempts.recordLoginEmailAttempt(credentials.email);
      }
      final auth = _auth;
      if (auth == null) return _unavailable();
      final issued = action == AuthAction.register
          ? await auth.register(credentials)
          : await auth.login(credentials);
      return Response(
        action == AuthAction.register ? 201 : 200,
        headers: _headers,
        body: jsonEncode({
          'user': {'id': issued.session.userId},
          'token': issued.token,
          'expiresAt': issued.session.expiresAt.toUtc().toIso8601String(),
        }),
      );
    } on InvalidAuthInput catch (error) {
      return _error(400, 'invalid_request', 'Confira os campos informados.',
          fields: error.fields);
    } on FormatException {
      return _error(400, 'invalid_request',
          'Envie apenas e-mail e senha em um objeto JSON válido.');
    } on _BodyTooLarge {
      return _error(413, 'invalid_request',
          'Os dados enviados excedem o tamanho permitido.');
    } on TimeoutException {
      return _error(
          408, 'invalid_request', 'O envio demorou demais. Tente novamente.');
    } on IOException {
      return _error(
          400, 'invalid_request', 'Não foi possível ler os dados enviados.');
    } on EmailInUseException {
      return _error(409, 'email_in_use', 'Este e-mail já está cadastrado.');
    } on InvalidLoginException {
      return _error(401, 'invalid_credentials', 'E-mail ou senha inválidos.');
    } on AuthAttemptLimitException catch (error) {
      return _error(429, 'too_many_attempts',
          'Muitas tentativas. Aguarde e tente novamente.',
          retryAfter: error.retryAfterSeconds);
    } on AuthBusyException {
      return _error(
          503, 'service_unavailable', 'Serviço ocupado. Tente novamente.',
          retryAfter: 1);
    } on AccountStorageException {
      return _unavailable();
    } on SessionStorageException {
      return _unavailable();
    }
  }

  Future<Map<String, Object?>> _readBody(Request request) async {
    final iterator = StreamIterator(request.read());
    final stopwatch = Stopwatch()..start();
    final bytes = <int>[];
    try {
      while (true) {
        final remaining = const Duration(seconds: 10) - stopwatch.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('Request body timed out');
        }
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > maxBodyBytes) {
          throw const _BodyTooLarge();
        }
        bytes.addAll(iterator.current);
      }
    } finally {
      await iterator.cancel();
    }
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?> ||
        decoded.keys.any((key) => key != 'email' && key != 'password')) {
      throw const FormatException('Expected email and password fields');
    }
    return decoded;
  }

  static const _headers = {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  };

  Response _unavailable() => _error(
      503, 'service_unavailable', 'Serviço indisponível. Tente novamente.');

  Response _error(int status, String code, String message,
      {Map<String, String>? fields, int? retryAfter}) {
    return Response(status,
        headers: {
          ..._headers,
          if (retryAfter != null) 'retry-after': '$retryAfter',
          if (status == 401) 'www-authenticate': 'Bearer',
        },
        body: jsonEncode({
          'error': {
            'code': code,
            'message': message,
            if (fields != null) 'fields': fields,
          }
        }));
  }
}

class _BodyTooLarge implements Exception {
  const _BodyTooLarge();
}
