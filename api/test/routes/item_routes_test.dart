import 'dart:convert';

import 'package:lost_and_found_api/src/auth/session_service.dart';
import 'package:lost_and_found_api/src/config/app_config.dart';
import 'package:lost_and_found_api/src/items/domain/item.dart';
import 'package:lost_and_found_api/src/items/domain/item_store.dart';
import 'package:lost_and_found_api/src/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/memory_item_store.dart';
import '../support/memory_session_store.dart';

void main() {
  late MemorySessionStore sessionStore;
  late MemoryItemStore itemStore;
  late SessionService sessions;
  late Handler handler;
  late String validToken;

  final config = const AppConfig(
    host: 'localhost',
    port: 8080,
    databaseUrl: '',
    environment: 'test',
    sessionTtlHours: 24,
  );

  setUp(() async {
    sessionStore = MemorySessionStore();
    itemStore = MemoryItemStore();
    sessions = SessionService(
      store: sessionStore,
      clock: () => DateTime.utc(2026, 11, 3, 12),
    );

    handler = buildServerHandler(
      config,
      sessions: sessions,
      itemStore: itemStore,
    );

    final issued = await sessions.issue('test-user-id-123');
    validToken = issued.token;
  });

  Future<Response> getItems({Map<String, String>? headers}) async {
    return await handler(Request(
      'GET',
      Uri.parse('http://localhost/items'),
      headers: headers,
    ));
  }

  Future<Response> postItem(Object? payload,
      {Map<String, String>? headers}) async {
    return await handler(Request(
      'POST',
      Uri.parse('http://localhost/items'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $validToken',
        ...?headers,
      },
      body: payload is String ? payload : jsonEncode(payload),
    ));
  }

  group('GET /items', () {
    test('is publicly accessible and returns an empty list initially',
        () async {
      final res = await getItems();
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], contains('application/json'));

      final list = jsonDecode(await res.readAsString()) as List;
      expect(list, isEmpty);
    });

    test('returns items ordered by newest first without leaking createdBy',
        () async {
      final older = LostFoundItem(
        id: '1',
        name: 'Caderno antigo',
        description: 'Capa dura preta',
        location: 'Sala 1',
        status: ItemStatus.lost,
        createdAt: DateTime.utc(2026, 11, 1, 10),
        createdBy: 'user-1',
      );
      final newer = LostFoundItem(
        id: '2',
        name: 'Mochila nova',
        description: 'Azul com detalhes cinza',
        location: 'Biblioteca',
        status: ItemStatus.found,
        createdAt: DateTime.utc(2026, 11, 2, 15),
        createdBy: 'user-2',
      );
      itemStore.items.addAll([older, newer]);

      final res = await getItems();
      expect(res.statusCode, 200);

      final list = (jsonDecode(await res.readAsString()) as List)
          .cast<Map<String, dynamic>>();
      expect(list.length, 2);
      expect(list[0]['id'], '2');
      expect(list[0]['name'], 'Mochila nova');
      expect(list[0]['status'], 'found');
      expect(list[0].containsKey('createdBy'), isFalse);
      expect(list[0].containsKey('created_by'), isFalse);

      expect(list[1]['id'], '1');
      expect(list[1]['name'], 'Caderno antigo');
    });

    test('returns 503 when the store fails', () async {
      itemStore.failure = const ItemStorageException('Database error');
      final res = await getItems();
      expect(res.statusCode, 503);

      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error']['code'], 'service_unavailable');
    });
  });

  group('POST /items', () {
    final validPayload = {
      'name': 'Calculadora Científica',
      'description': 'Casio preta esquecida após a prova de cálculo',
      'location': 'Bloco B, Sala 204',
      'status': 'found',
    };

    test('returns 401 when request is unauthenticated or token is invalid',
        () async {
      final noAuth =
          await postItem(validPayload, headers: {'authorization': ''});
      expect(noAuth.statusCode, 401);

      final badToken = await postItem(validPayload, headers: {
        'authorization': 'Bearer invalid-token-1234567890123456789012345678901'
      });
      expect(badToken.statusCode, 401);

      await sessions.revoke(validToken);
      final revoked = await postItem(validPayload);
      expect(revoked.statusCode, 401);
    });

    test('returns 415 when Content-Type is not application/json', () async {
      final res = await postItem(
        jsonEncode(validPayload),
        headers: {'content-type': 'text/plain'},
      );
      expect(res.statusCode, 415);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error']['code'], 'invalid_request');
    });

    test(
        'returns 400 when body contains unexpected fields (e.g. client attempts to forge author or id)',
        () async {
      final forgedPayload = {
        ...validPayload,
        'createdBy': 'another-user-id',
      };
      final res = await postItem(forgedPayload);
      expect(res.statusCode, 400);

      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error']['code'], 'invalid_request');
      expect(body['error']['message'], contains('não permitidos'));
    });

    test('returns 400 with field errors when inputs are invalid', () async {
      final invalidPayload = {
        'name': '   ',
        'description': 'B' * 201,
        'location': '',
        'status': 'unknown_status',
      };
      final res = await postItem(invalidPayload);
      expect(res.statusCode, 400);

      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error']['code'], 'invalid_request');
      final fields = body['error']['fields'] as Map<String, dynamic>;
      expect(fields.containsKey('name'), isTrue);
      expect(fields.containsKey('description'), isTrue);
      expect(fields.containsKey('location'), isTrue);
      expect(fields.containsKey('status'), isTrue);
    });

    test('returns 201 and persists item with authenticated author', () async {
      final res = await postItem(validPayload);
      expect(res.statusCode, 201);
      expect(res.headers['content-type'], contains('application/json'));

      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['name'], 'Calculadora Científica');
      expect(
          body['description'], 'Casio preta esquecida após a prova de cálculo');
      expect(body['location'], 'Bloco B, Sala 204');
      expect(body['status'], 'found');
      expect(body['createdAt'], isNotEmpty);
      expect(body.containsKey('createdBy'), isFalse);

      expect(itemStore.items.length, 1);
      final persisted = itemStore.items.single;
      expect(persisted.name, 'Calculadora Científica');
      expect(persisted.createdBy,
          'test-user-id-123'); // Bound from authenticated session!
    });

    test('returns 503 when store fails', () async {
      itemStore.failure = const ItemStorageException('Disk full');
      final res = await postItem(validPayload);
      expect(res.statusCode, 503);
    });
  });
}
