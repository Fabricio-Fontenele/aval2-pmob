import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/features/lost_found/domain/item_input_validator.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';

void main() {
  group('ItemStatus', () {
    test('exposes Brazilian Portuguese display labels for lost and found', () {
      expect(ItemStatus.lost.label, 'Perdido');
      expect(ItemStatus.found.label, 'Encontrado');
    });

    test(
      'parses valid status identifiers case-insensitively and trims spaces',
      () {
        expect(ItemStatus.tryParse('lost'), ItemStatus.lost);
        expect(ItemStatus.tryParse('  LOST '), ItemStatus.lost);
        expect(ItemStatus.tryParse('found'), ItemStatus.found);
        expect(ItemStatus.tryParse(' Found  '), ItemStatus.found);
      },
    );

    test('returns null for null, blank, or unknown status values', () {
      expect(ItemStatus.tryParse(null), isNull);
      expect(ItemStatus.tryParse(''), isNull);
      expect(ItemStatus.tryParse('   '), isNull);
      expect(ItemStatus.tryParse('perdido'), isNull);
      expect(ItemStatus.tryParse('other'), isNull);
    });
  });

  group('ItemInputValidator field validators', () {
    test('rejects null, empty, and whitespace-only object name', () {
      expect(
        ItemInputValidator.validateName(null),
        'Informe o nome do objeto.',
      );
      expect(ItemInputValidator.validateName(''), 'Informe o nome do objeto.');
      expect(
        ItemInputValidator.validateName('   \t\n  '),
        'Informe o nome do objeto.',
      );
    });

    test(
      'enforces the 60-character Unicode code point limit on trimmed name',
      () {
        final exact60 = 'A' * 60;
        final exact60WithOuterSpaces = '  $exact60  ';
        final over60 = 'A' * 61;
        final emoji60 = '🔑' * 60;
        final emoji61 = '🔑' * 61;

        expect(ItemInputValidator.validateName(exact60), isNull);
        expect(ItemInputValidator.validateName(exact60WithOuterSpaces), isNull);
        expect(ItemInputValidator.validateName(emoji60), isNull);
        expect(
          ItemInputValidator.validateName(over60),
          'O nome deve ter no máximo 60 caracteres.',
        );
        expect(
          ItemInputValidator.validateName(emoji61),
          'O nome deve ter no máximo 60 caracteres.',
        );
      },
    );

    test('rejects null, empty, and whitespace-only description', () {
      expect(
        ItemInputValidator.validateDescription(null),
        'Informe a descrição do objeto.',
      );
      expect(
        ItemInputValidator.validateDescription(''),
        'Informe a descrição do objeto.',
      );
      expect(
        ItemInputValidator.validateDescription('   \n '),
        'Informe a descrição do objeto.',
      );
    });

    test('enforces the 200-character Unicode code point limit on trimmed description', () {
      final exact200 = 'B' * 200;
      final exact200WithOuterSpaces = '  $exact200  ';
      final over200 = 'B' * 201;
      final emoji200 = '🎒' * 200;
      final emoji201 = '🎒' * 201;

      expect(ItemInputValidator.validateDescription(exact200), isNull);
      expect(
        ItemInputValidator.validateDescription(exact200WithOuterSpaces),
        isNull,
      );
      expect(ItemInputValidator.validateDescription(emoji200), isNull);
      expect(
        ItemInputValidator.validateDescription(over200),
        'A descrição deve ter no máximo 200 caracteres.',
      );
      expect(
        ItemInputValidator.validateDescription(emoji201),
        'A descrição deve ter no máximo 200 caracteres.',
      );
    });

    test('rejects null, empty, and whitespace-only location', () {
      expect(
        ItemInputValidator.validateLocation(null),
        'Informe o local onde foi perdido ou encontrado.',
      );
      expect(
        ItemInputValidator.validateLocation(''),
        'Informe o local onde foi perdido ou encontrado.',
      );
      expect(
        ItemInputValidator.validateLocation('   '),
        'Informe o local onde foi perdido ou encontrado.',
      );
      expect(
        ItemInputValidator.validateLocation(' Biblioteca Central '),
        isNull,
      );
    });

    test('rejects missing status and accepts lost or found', () {
      expect(
        ItemInputValidator.validateStatus(null),
        'Informe a situação do objeto.',
      );
      expect(ItemInputValidator.validateStatus(ItemStatus.lost), isNull);
      expect(ItemInputValidator.validateStatus(ItemStatus.found), isNull);
    });
  });

  group('ItemInputValidator.validate', () {
    test('returns normalized ValidatedItemInput when all fields are valid', () {
      final result = ItemInputValidator.validate(
        name: '  Garrafa térmica azul  ',
        description: '  Encontrada próxima ao bebedouro do bloco B.  ',
        location: '  Bloco B, corredor principal  ',
        status: ItemStatus.found,
      );

      expect(result.name, 'Garrafa térmica azul');
      expect(result.description, 'Encontrada próxima ao bebedouro do bloco B.');
      expect(result.location, 'Bloco B, corredor principal');
      expect(result.status, ItemStatus.found);
    });

    test('collects field errors for all invalid inputs simultaneously', () {
      expect(
        () => ItemInputValidator.validate(
          name: '   ',
          description: 'D' * 201,
          location: '',
          status: null,
        ),
        throwsA(
          isA<ItemValidationException>()
              .having(
                (e) => e.fields['name'],
                'name error',
                'Informe o nome do objeto.',
              )
              .having(
                (e) => e.fields['description'],
                'description error',
                'A descrição deve ter no máximo 200 caracteres.',
              )
              .having(
                (e) => e.fields['location'],
                'location error',
                'Informe o local onde foi perdido ou encontrado.',
              )
              .having(
                (e) => e.fields['status'],
                'status error',
                'Informe a situação do objeto.',
              ),
        ),
      );
    });
  });
}
