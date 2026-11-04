import 'package:lost_and_found_api/src/items/domain/item.dart';
import 'package:test/test.dart';

void main() {
  group('NewItem.validate', () {
    test('accepts valid lost and found items and trims whitespace', () {
      final lost = NewItem.validate(
        name: '  Chaveiro com 3 chaves  ',
        description: '  Perdido perto da biblioteca  ',
        location: '  Bloco 5, Sala 12  ',
        status: 'LOST',
      );
      expect(lost.name, 'Chaveiro com 3 chaves');
      expect(lost.description, 'Perdido perto da biblioteca');
      expect(lost.location, 'Bloco 5, Sala 12');
      expect(lost.status, ItemStatus.lost);

      final found = NewItem.validate(
        name: 'Garrafa térmica azul',
        description: 'Encontrada no auditório',
        location: 'Auditório Central',
        status: 'found',
      );
      expect(found.status, ItemStatus.found);
    });

    test('rejects blank and missing name', () {
      expect(
        () => NewItem.validate(
          name: '',
          description: 'Desc',
          location: 'Loc',
          status: 'lost',
        ),
        throwsA(isA<InvalidItemInput>().having(
          (e) => e.fields['name'],
          'name error',
          contains('Informe o nome'),
        )),
      );

      expect(
        () => NewItem.validate(
          name: '   ',
          description: 'Desc',
          location: 'Loc',
          status: 'lost',
        ),
        throwsA(isA<InvalidItemInput>()),
      );
    });

    test('rejects name exceeding 60 characters', () {
      final longName = 'A' * 61;
      expect(
        () => NewItem.validate(
          name: longName,
          description: 'Desc',
          location: 'Loc',
          status: 'lost',
        ),
        throwsA(isA<InvalidItemInput>().having(
          (e) => e.fields['name'],
          'name error',
          contains('60 caracteres'),
        )),
      );

      // Exactly 60 characters is allowed
      final exact60 = 'A' * 60;
      final item = NewItem.validate(
        name: exact60,
        description: 'Desc',
        location: 'Loc',
        status: 'lost',
      );
      expect(item.name.length, 60);
    });

    test('rejects description exceeding 200 characters and blank description',
        () {
      expect(
        () => NewItem.validate(
          name: 'Nome',
          description: '   ',
          location: 'Loc',
          status: 'lost',
        ),
        throwsA(isA<InvalidItemInput>().having(
          (e) => e.fields['description'],
          'desc error',
          contains('Informe a descrição'),
        )),
      );

      final longDesc = 'B' * 201;
      expect(
        () => NewItem.validate(
          name: 'Nome',
          description: longDesc,
          location: 'Loc',
          status: 'lost',
        ),
        throwsA(isA<InvalidItemInput>().having(
          (e) => e.fields['description'],
          'desc error',
          contains('200 caracteres'),
        )),
      );

      final exact200 = 'B' * 200;
      final item = NewItem.validate(
        name: 'Nome',
        description: exact200,
        location: 'Loc',
        status: 'lost',
      );
      expect(item.description.length, 200);
    });

    test('rejects blank location', () {
      expect(
        () => NewItem.validate(
          name: 'Nome',
          description: 'Desc',
          location: '   ',
          status: 'lost',
        ),
        throwsA(isA<InvalidItemInput>().having(
          (e) => e.fields['location'],
          'loc error',
          contains('Informe o local'),
        )),
      );
    });

    test('rejects invalid or missing status', () {
      expect(
        () => NewItem.validate(
          name: 'Nome',
          description: 'Desc',
          location: 'Loc',
          status: 'other',
        ),
        throwsA(isA<InvalidItemInput>().having(
          (e) => e.fields['status'],
          'status error',
          contains('lost ou found'),
        )),
      );

      expect(
        () => NewItem.validate(
          name: 'Nome',
          description: 'Desc',
          location: 'Loc',
          status: null,
        ),
        throwsA(isA<InvalidItemInput>()),
      );
    });
  });

  group('LostFoundItem.toJson', () {
    test('serializes public fields without exposing createdBy', () {
      final now = DateTime.utc(2026, 11, 3, 20, 0, 0);
      final item = LostFoundItem(
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Guarda-chuva preto',
        description: 'Esquecido na cantina',
        location: 'Cantina',
        status: ItemStatus.lost,
        createdAt: now,
        createdBy: 'user-uuid-secret',
      );

      final json = item.toJson();
      expect(json['id'], '123e4567-e89b-12d3-a456-426614174000');
      expect(json['name'], 'Guarda-chuva preto');
      expect(json['description'], 'Esquecido na cantina');
      expect(json['location'], 'Cantina');
      expect(json['status'], 'lost');
      expect(json['createdAt'], '2026-11-03T20:00:00.000Z');
      expect(json.containsKey('createdBy'), isFalse);
      expect(json.containsKey('created_by'), isFalse);
    });
  });
}
