import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api_base_url.dart';
import '../../auth/domain/session_token_provider.dart';
import '../domain/item_repository.dart';
import '../domain/item_status.dart';
import '../domain/lost_found_item.dart';

class HttpItemRepository implements ItemRepository {
  HttpItemRepository({
    required Uri baseUrl,
    required this.client,
    required this.sessionTokens,
    Duration requestTimeout = const Duration(seconds: 75),
  }) : _baseUrl = ApiBaseUrl.normalize(baseUrl),
       _requestTimeout = requestTimeout {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError('requestTimeout must be positive.');
    }
  }

  factory HttpItemRepository.fromEnvironment({
    required http.Client client,
    required SessionTokenProvider sessionTokens,
    Duration requestTimeout = const Duration(seconds: 75),
  }) {
    return HttpItemRepository(
      baseUrl: ApiBaseUrl.fromEnvironment(),
      client: client,
      sessionTokens: sessionTokens,
      requestTimeout: requestTimeout,
    );
  }

  final Uri _baseUrl;
  final http.Client client;
  final SessionTokenProvider sessionTokens;
  final Duration _requestTimeout;

  static const _itemsPath = 'items';
  static const _fieldKeys = ['name', 'description', 'location', 'status'];
  static const _invalidResponse = ItemRepositoryException(
    'O servidor retornou uma resposta inválida. Tente novamente.',
  );

  @override
  Future<List<LostFoundItem>> fetchItems() async {
    final response = await _send('GET', _itemsPath);
    if (response.statusCode != 200) {
      throw _failure(response);
    }
    return _readItems(response);
  }

  @override
  Future<void> createItem({
    required String name,
    required String description,
    required String location,
    required ItemStatus status,
  }) async {
    final token = await sessionTokens.getSessionToken();
    if (token == null) {
      throw const ItemRepositoryException.unauthorized();
    }

    final response = await _send(
      'POST',
      _itemsPath,
      token: token,
      body: {
        'name': name,
        'description': description,
        'location': location,
        'status': status.name,
      },
    );

    if (response.statusCode == 201) {
      return;
    }
    if (response.statusCode == 401) {
      await sessionTokens.invalidateSession(token);
      throw const ItemRepositoryException.unauthorized();
    }
    throw _failure(response);
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
    if (token != null) {
      request.headers['authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    Future<http.Response> send() async =>
        http.Response.fromStream(await client.send(request));
    try {
      return await send().timeout(_requestTimeout);
    } on http.ClientException {
      throw const ItemRepositoryException.network();
    } on TimeoutException {
      throw const ItemRepositoryException.network(
        'O servidor demorou para responder. Tente novamente.',
      );
    }
  }

  List<LostFoundItem> _readItems(http.Response response) {
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw _invalidResponse;
    }
    if (body is! List) {
      throw _invalidResponse;
    }

    final items = body.map(_readItem).toList(growable: false)
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return List.unmodifiable(items);
  }

  LostFoundItem _readItem(Object? entry) {
    if (entry case {
      'id': final String id,
      'name': final String name,
      'description': final String description,
      'location': final String location,
      'status': final String status,
      'createdAt': final String createdAt,
    }) {
      final parsedStatus = ItemStatus.tryParse(status);
      final parsedCreatedAt = DateTime.tryParse(createdAt);
      if (id.trim().isNotEmpty &&
          parsedStatus != null &&
          parsedCreatedAt != null &&
          parsedCreatedAt.isUtc) {
        return LostFoundItem(
          id: id,
          name: name,
          description: description,
          location: location,
          status: parsedStatus,
          createdAt: parsedCreatedAt,
        );
      }
    }
    throw _invalidResponse;
  }

  ItemRepositoryException _failure(http.Response response) {
    switch (response.statusCode) {
      case 400:
      case 408:
      case 413:
      case 415:
        return ItemRepositoryException(
          'Confira os campos informados.',
          fieldErrors: _readFieldErrors(response),
        );
      case 401:
        return const ItemRepositoryException.unauthorized();
      case 429:
        return const ItemRepositoryException(
          'Muitas tentativas seguidas. Aguarde um momento e tente novamente.',
        );
      default:
        return const ItemRepositoryException(
          'Serviço indisponível no momento. Tente novamente.',
        );
    }
  }

  Map<String, String> _readFieldErrors(http.Response response) {
    final fields = <String, String>{};
    try {
      final Object? body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body case {'error': {'fields': final Map<String, Object?> errors}}) {
        for (final key in _fieldKeys) {
          if (errors[key] case final String message when message.isNotEmpty) {
            fields[key] = message;
          }
        }
      }
    } on FormatException {
      return const {};
    }
    return Map.unmodifiable(fields);
  }
}
