import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'domain/auth_session.dart';
import 'domain/session_store.dart';
import 'session_service.dart';

const authenticatedSessionKey = 'auth.session';

const _privateHeaders = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};

String? readBearerToken(Request request) {
  final authorization = request.headers['authorization'];
  if (authorization == null) return null;
  final match = RegExp(r'^Bearer ([A-Za-z0-9_-]{43})$', caseSensitive: false)
      .firstMatch(authorization);
  return match?.group(1);
}

Response _sessionError(int statusCode, String code, String message) {
  return Response(
    statusCode,
    body: jsonEncode({
      'error': {'code': code, 'message': message},
    }),
    headers: {
      ..._privateHeaders,
      if (statusCode == 401) 'www-authenticate': 'Bearer',
    },
  );
}

Middleware requireSession(SessionService? sessions) {
  return (Handler innerHandler) {
    return (Request request) async {
      final token = readBearerToken(request);
      if (token == null) {
        return _sessionError(
          401,
          'invalid_session',
          'Sessão inválida ou expirada. Entre novamente.',
        );
      }
      if (sessions == null) {
        return _sessionError(
          503,
          'service_unavailable',
          'Serviço indisponível. Tente novamente.',
        );
      }

      try {
        final session = await sessions.authenticate(token);
        return await innerHandler(request.change(context: {
          authenticatedSessionKey: session,
        }));
      } on InvalidSessionException {
        return _sessionError(
          401,
          'invalid_session',
          'Sessão inválida ou expirada. Entre novamente.',
        );
      } on SessionStorageException {
        return _sessionError(
          503,
          'service_unavailable',
          'Serviço indisponível. Tente novamente.',
        );
      }
    };
  };
}

Handler buildSessionHandler(SessionService? sessions) {
  return requireSession(sessions)((Request request) async {
    final session = request.context[authenticatedSessionKey] as AuthSession;
    return Response.ok(
      jsonEncode({
        'user': {'id': session.userId},
        'expiresAt': session.expiresAt.toUtc().toIso8601String(),
      }),
      headers: _privateHeaders,
    );
  });
}

Handler buildLogoutHandler(SessionService? sessions) {
  return requireSession(sessions)((Request request) async {
    // The middleware guarantees both the service and a well-formed bearer token.
    await sessions!.revoke(readBearerToken(request)!);
    return Response(204, headers: {'cache-control': 'no-store'});
  });
}
