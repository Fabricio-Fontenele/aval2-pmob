import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../auth/domain/auth_session.dart';
import '../auth/session_http.dart';
import 'domain/item.dart';
import 'domain/item_store.dart';

class ItemEndpoints {
  static const maxBodyBytes = 8192;
  static const _allowedKeys = {'name', 'description', 'location', 'status'};

  final ItemStore? _itemStore;

  const ItemEndpoints({ItemStore? itemStore}) : _itemStore = itemStore;

  Future<Response> listItems(Request request) async {
    try {
      final store = _itemStore;
      if (store == null) return _unavailable();

      final items = await store.listItems();
      final body = jsonEncode(items.map((item) => item.toJson()).toList());

      return Response.ok(
        body,
        headers: _headers,
      );
    } on ItemStorageException {
      return _unavailable();
    }
  }

  Future<Response> createItem(Request request) async {
    try {
      final session = request.context[authenticatedSessionKey] as AuthSession?;
      if (session == null) {
        return _error(401, 'invalid_session',
            'Sessão inválida ou expirada. Entre novamente.');
      }

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
      final newItem = NewItem.validate(
        name: values['name'],
        description: values['description'],
        location: values['location'],
        status: values['status'],
      );

      final store = _itemStore;
      if (store == null) return _unavailable();

      final created = await store.createItem(newItem, userId: session.userId);

      return Response(
        201,
        headers: _headers,
        body: jsonEncode(created.toJson()),
      );
    } on InvalidItemInput catch (error) {
      return _error(400, 'invalid_request', 'Confira os campos informados.',
          fields: error.fields);
    } on _UnexpectedFieldsException {
      return _error(400, 'invalid_request',
          'Campos não permitidos foram enviados na requisição.');
    } on FormatException {
      return _error(400, 'invalid_request',
          'Envie os dados do objeto em um JSON válido.');
    } on _BodyTooLarge {
      return _error(413, 'invalid_request',
          'Os dados enviados excedem o tamanho permitido.');
    } on TimeoutException {
      return _error(
          408, 'invalid_request', 'O envio demorou demais. Tente novamente.');
    } on IOException {
      return _error(
          400, 'invalid_request', 'Não foi possível ler os dados enviados.');
    } on ItemStorageException {
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
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object');
    }

    if (decoded.keys.any((key) => !_allowedKeys.contains(key))) {
      throw const _UnexpectedFieldsException();
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
      {Map<String, String>? fields}) {
    return Response(
      status,
      headers: {
        ..._headers,
        if (status == 401) 'www-authenticate': 'Bearer',
      },
      body: jsonEncode({
        'error': {
          'code': code,
          'message': message,
          if (fields != null) 'fields': fields,
        }
      }),
    );
  }
}

class _BodyTooLarge implements Exception {
  const _BodyTooLarge();
}

class _UnexpectedFieldsException implements Exception {
  const _UnexpectedFieldsException();
}
