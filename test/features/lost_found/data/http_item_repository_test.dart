import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lost_and_found/features/auth/domain/session_token_provider.dart';
import 'package:lost_and_found/features/lost_found/data/http_item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';

class _SessionTokens implements SessionTokenProvider {
  _SessionTokens([this.token]);

  String? token;
  final List<String> rejected = <String>[];

  @override
  Future<String?> getSessionToken() async => token;

  @override
  Future<bool> invalidateSession(String rejectedToken) async {
    rejected.add(rejectedToken);
    if (token != rejectedToken) {
      return false;
    }
    token = null;
    return true;
  }
}

const _token = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';

Map<String, Object?> _itemJson({
  String id = '00000000-0000-4000-8000-000000000001',
  String name = 'Garrafa azul',
  String description = 'Garrafa térmica com adesivo da universidade.',
  String location = 'Biblioteca central',
  String status = 'lost',
  String createdAt = '2026-11-07T12:00:00.000Z',
}) {
  return {
    'id': id,
    'name': name,
    'description': description,
    'location': location,
    'status': status,
    'createdAt': createdAt,
  };
}

http.Response _jsonResponse(Object? body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

HttpItemRepository _repository({
  required http.Client client,
  SessionTokenProvider? sessionTokens,
  Duration requestTimeout = const Duration(seconds: 75),
}) {
  return HttpItemRepository(
    baseUrl: Uri.parse('https://api.example.test'),
    client: client,
    sessionTokens: sessionTokens ?? _SessionTokens(_token),
    requestTimeout: requestTimeout,
  );
}

void main() {
  test('reads the public listing without sending a session token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url, Uri.parse('https://api.example.test/items'));
      expect(request.headers.containsKey('authorization'), isFalse);
      return _jsonResponse([
        _itemJson(status: 'found', createdAt: '2026-11-07T12:00:00.000Z'),
      ]);
    });
    addTearDown(client.close);

    final items = await _repository(client: client).fetchItems();

    expect(items, hasLength(1));
    expect(items.single.id, '00000000-0000-4000-8000-000000000001');
    expect(items.single.name, 'Garrafa azul');
    expect(
      items.single.description,
      'Garrafa térmica com adesivo da universidade.',
    );
    expect(items.single.location, 'Biblioteca central');
    expect(items.single.status, ItemStatus.found);
    expect(items.single.createdAt, DateTime.utc(2026, 11, 7, 12));
  });

  test('normalizes the received listing to newest first', () async {
    final client = MockClient(
      (_) async => _jsonResponse([
        _itemJson(id: 'older', createdAt: '2026-11-01T08:00:00.000Z'),
        _itemJson(id: 'newest', createdAt: '2026-11-08T21:30:00.000Z'),
        _itemJson(id: 'middle', createdAt: '2026-11-05T10:00:00.000Z'),
      ]),
    );
    addTearDown(client.close);

    final items = await _repository(client: client).fetchItems();

    expect(
      items.map((item) => item.id),
      ['newest', 'middle', 'older'],
    );
  });

  test('an empty listing is a successful read', () async {
    final client = MockClient((_) async => _jsonResponse(const []));
    addTearDown(client.close);

    expect(await _repository(client: client).fetchItems(), isEmpty);
  });

  final invalidPayloads = <(String, Object?)>[
    ('not a list', <String, Object?>{'items': <Object?>[]}),
    ('missing field', [{..._itemJson()}..remove('location')]),
    ('unknown status', [_itemJson(status: 'misplaced')]),
    ('local creation timestamp', [_itemJson(createdAt: '2026-11-07T12:00:00')]),
    ('unparseable creation timestamp', [_itemJson(createdAt: 'yesterday')]),
    ('blank identifier', [_itemJson(id: '   ')]),
    ('numeric name', [
      {..._itemJson(), 'name': 7},
    ]),
    ('entry that is not an object', ['garrafa azul']),
  ];

  for (final (label, body) in invalidPayloads) {
    test('rejects an invalid listing payload: $label', () async {
      final client = MockClient((_) async => _jsonResponse(body));
      addTearDown(client.close);

      await expectLater(
        _repository(client: client).fetchItems(),
        throwsA(
          isA<ItemRepositoryException>()
              .having(
                (error) => error.isUnauthorized,
                'isUnauthorized',
                isFalse,
              )
              .having(
                (error) => error.message,
                'message',
                contains('resposta inválida'),
              ),
        ),
      );
    });
  }

  test('rejects a listing body that is not valid JSON', () async {
    final client = MockClient(
      (_) async => http.Response('<html>502</html>', 200),
    );
    addTearDown(client.close);

    await expectLater(
      _repository(client: client).fetchItems(),
      throwsA(isA<ItemRepositoryException>()),
    );
  });

  test('tolerates additional fields sent by the API', () async {
    final client = MockClient(
      (_) async => _jsonResponse([
        {..._itemJson(), 'createdBy': 'ignored-by-the-client'},
      ]),
    );
    addTearDown(client.close);

    final items = await _repository(client: client).fetchItems();

    expect(items.single.status, ItemStatus.lost);
  });

  test('publishes with the bearer token and without authorship', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('https://api.example.test/items'));
      expect(request.headers['authorization'], 'Bearer $_token');
      expect(jsonDecode(request.body), {
        'name': 'Garrafa azul',
        'description': 'Garrafa térmica com adesivo da universidade.',
        'location': 'Biblioteca central',
        'status': 'found',
      });
      return _jsonResponse(_itemJson(status: 'found'), 201);
    });
    addTearDown(client.close);

    await _repository(client: client).createItem(
      name: 'Garrafa azul',
      description: 'Garrafa térmica com adesivo da universidade.',
      location: 'Biblioteca central',
      status: ItemStatus.found,
    );
  });

  test('publishing without a stored session does not reach the API', () async {
    final client = MockClient((_) async {
      fail('An unauthenticated publication must not be sent.');
    });
    addTearDown(client.close);

    await expectLater(
      _repository(client: client, sessionTokens: _SessionTokens()).createItem(
        name: 'Garrafa azul',
        description: 'Garrafa térmica.',
        location: 'Biblioteca central',
        status: ItemStatus.lost,
      ),
      throwsA(
        isA<ItemRepositoryException>().having(
          (error) => error.isUnauthorized,
          'isUnauthorized',
          isTrue,
        ),
      ),
    );
  });

  test('a rejected token is discarded and reported as unauthorized', () async {
    final tokens = _SessionTokens(_token);
    final client = MockClient(
      (_) async => _jsonResponse({
        'error': {
          'code': 'invalid_session',
          'message': 'Sessão inválida ou expirada. Entre novamente.',
        },
      }, 401),
    );
    addTearDown(client.close);

    await expectLater(
      _repository(client: client, sessionTokens: tokens).createItem(
        name: 'Garrafa azul',
        description: 'Garrafa térmica.',
        location: 'Biblioteca central',
        status: ItemStatus.lost,
      ),
      throwsA(
        isA<ItemRepositoryException>().having(
          (error) => error.isUnauthorized,
          'isUnauthorized',
          isTrue,
        ),
      ),
    );
    expect(tokens.rejected, [_token]);
    expect(await tokens.getSessionToken(), isNull);
  });

  test('server field errors are translated for the form', () async {
    final client = MockClient(
      (_) async => _jsonResponse({
        'error': {
          'code': 'invalid_request',
          'message': 'Confira os campos informados.',
          'fields': {
            'name': 'O nome deve ter no máximo 60 caracteres.',
            'status': 'Informe a situação do objeto.',
            'createdBy': 'Campo não suportado.',
          },
        },
      }, 400),
    );
    addTearDown(client.close);

    await expectLater(
      _repository(client: client).createItem(
        name: 'Garrafa azul',
        description: 'Garrafa térmica.',
        location: 'Biblioteca central',
        status: ItemStatus.lost,
      ),
      throwsA(
        isA<ItemRepositoryException>()
            .having(
              (error) => error.fieldErrors,
              'fieldErrors',
              {
                'name': 'O nome deve ter no máximo 60 caracteres.',
                'status': 'Informe a situação do objeto.',
              },
            )
            .having((error) => error.isUnauthorized, 'isUnauthorized', isFalse),
      ),
    );
  });

  for (final (status, expected) in [
    (429, 'Muitas tentativas'),
    (500, 'Serviço indisponível'),
    (503, 'Serviço indisponível'),
  ]) {
    test('translates a $status response into a retryable failure', () async {
      final client = MockClient((_) async => http.Response('', status));
      addTearDown(client.close);

      await expectLater(
        _repository(client: client).fetchItems(),
        throwsA(
          isA<ItemRepositoryException>().having(
            (error) => error.message,
            'message',
            contains(expected),
          ),
        ),
      );
    });
  }

  test('a connection failure is reported as a network error', () async {
    final client = MockClient((_) async {
      throw http.ClientException('connection refused');
    });
    addTearDown(client.close);

    await expectLater(
      _repository(client: client).fetchItems(),
      throwsA(
        isA<ItemRepositoryException>().having(
          (error) => error.message,
          'message',
          contains('conectar ao servidor'),
        ),
      ),
    );
  });

  test('a slow publication times out once and is not resent', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final client = MockClient((_) {
      requests++;
      return response.future;
    });
    addTearDown(client.close);

    await expectLater(
      _repository(
        client: client,
        requestTimeout: const Duration(milliseconds: 1),
      ).createItem(
        name: 'Garrafa azul',
        description: 'Garrafa térmica.',
        location: 'Biblioteca central',
        status: ItemStatus.lost,
      ),
      throwsA(
        isA<ItemRepositoryException>().having(
          (error) => error.message,
          'message',
          contains('demorou para responder'),
        ),
      ),
    );
    response.complete(_jsonResponse(_itemJson(), 201));
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
  });

  test('preserves an API base path and does not follow redirects', () async {
    final client = MockClient((request) async {
      expect(request.url, Uri.parse('https://api.example.test/v1/items'));
      expect(request.followRedirects, isFalse);
      return _jsonResponse(const []);
    });
    addTearDown(client.close);

    final repository = HttpItemRepository(
      baseUrl: Uri.parse('https://api.example.test/v1'),
      client: client,
      sessionTokens: _SessionTokens(_token),
    );

    expect(await repository.fetchItems(), isEmpty);
  });

  for (final (label, address) in [
    ('remote HTTP', 'http://api.example.test'),
    ('unsupported scheme', 'file:///tmp/api'),
    ('embedded credentials', 'https://user:password@api.example.test'),
    ('query parameters', 'https://api.example.test?token=private'),
    ('fragment', 'https://api.example.test#fragment'),
  ]) {
    test('rejects unsafe or ambiguous API configuration: $label', () {
      final client = MockClient((_) async => _jsonResponse(const []));
      addTearDown(client.close);

      expect(
        () => HttpItemRepository(
          baseUrl: Uri.parse(address),
          client: client,
          sessionTokens: _SessionTokens(_token),
        ),
        throwsArgumentError,
      );
    });
  }
}
