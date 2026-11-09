import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/app/app_theme.dart';
import 'package:lost_and_found/features/lost_found/domain/item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';
import 'package:lost_and_found/features/lost_found/domain/lost_found_item.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_form_screen.dart';

class _FakeItemRepository implements ItemRepository {
  int createCallCount = 0;
  String? lastSubmittedName;
  String? lastSubmittedDescription;
  String? lastSubmittedLocation;
  ItemStatus? lastSubmittedStatus;
  Future<void> Function()? onCreateItem;

  @override
  Future<List<LostFoundItem>> fetchItems() async => const [];

  @override
  Future<void> createItem({
    required String name,
    required String description,
    required String location,
    required ItemStatus status,
  }) async {
    createCallCount++;
    lastSubmittedName = name;
    lastSubmittedDescription = description;
    lastSubmittedLocation = location;
    lastSubmittedStatus = status;
    if (onCreateItem != null) {
      await onCreateItem!();
    }
  }
}

Widget _buildTestApp({
  required ItemRepository repository,
  VoidCallback? onUnauthorized,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ItemFormScreen(
      repository: repository,
      onUnauthorized: onUnauthorized,
    ),
  );
}

Future<void> _fillValidForm(
  WidgetTester tester, {
  String name = 'Garrafa térmica azul',
  String description = 'Encontrada perto do auditório central',
  String location = 'Auditório Central',
  ItemStatus status = ItemStatus.found,
}) async {
  await tester.enterText(find.byKey(ItemFormScreen.nameFieldKey), name);
  await tester.enterText(
    find.byKey(ItemFormScreen.descriptionFieldKey),
    description,
  );
  await tester.enterText(find.byKey(ItemFormScreen.locationFieldKey), location);
  await tester.tap(find.byKey(ItemFormScreen.statusFieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(status.label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('ItemFormScreen', () {
    late _FakeItemRepository repository;

    setUp(() {
      repository = _FakeItemRepository();
    });

    testWidgets(
      'A03: displays Brazilian Portuguese validation errors for blank and over-limit fields without calling repository',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(repository: repository));

        await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.pump();

        expect(find.text('Informe o nome do objeto.'), findsOneWidget);
        expect(find.text('Informe a descrição do objeto.'), findsOneWidget);
        expect(
          find.text('Informe o local onde foi perdido ou encontrado.'),
          findsOneWidget,
        );
        expect(find.text('Informe a situação do objeto.'), findsOneWidget);
        expect(repository.createCallCount, 0);

        await tester.enterText(
          find.byKey(ItemFormScreen.nameFieldKey),
          'A' * 61,
        );
        await tester.enterText(
          find.byKey(ItemFormScreen.descriptionFieldKey),
          'B' * 201,
        );
        await tester.enterText(
          find.byKey(ItemFormScreen.locationFieldKey),
          '   ',
        );

        await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.pump();

        expect(
          find.text('O nome deve ter no máximo 60 caracteres.'),
          findsOneWidget,
        );
        expect(
          find.text('A descrição deve ter no máximo 200 caracteres.'),
          findsOneWidget,
        );
        expect(
          find.text('Informe o local onde foi perdido ou encontrado.'),
          findsOneWidget,
        );
        expect(repository.createCallCount, 0);

        final exact60Name = 'A' * 60;
        final exact200Description = 'B' * 200;
        await _fillValidForm(
          tester,
          name: exact60Name,
          description: exact200Description,
          location: 'Bloco A',
          status: ItemStatus.lost,
        );

        await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.pumpAndSettle();

        expect(repository.createCallCount, 1);
        expect(repository.lastSubmittedName, exact60Name);
        expect(repository.lastSubmittedDescription, exact200Description);
      },
    );

    testWidgets(
      'A04 & A05: shows loading indicator, prevents duplicate submissions, and pops with true on confirmed save',
      (tester) async {
        final completer = Completer<void>();
        repository.onCreateItem = () => completer.future;
        bool? popResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      popResult = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) =>
                              ItemFormScreen(repository: repository),
                        ),
                      );
                    },
                    child: const Text('Abrir cadastro'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir cadastro'));
        await tester.pumpAndSettle();

        await _fillValidForm(
          tester,
          name: '  Chave de carro  ',
          description: '  Encontrada no estacionamento  ',
          location: '  Estacionamento principal  ',
          status: ItemStatus.found,
        );

        await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Salvando...'), findsOneWidget);

        await tester.tap(
          find.byKey(ItemFormScreen.submitButtonKey),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(repository.createCallCount, 1);

        completer.complete();
        await tester.pumpAndSettle();

        expect(popResult, isTrue);
        expect(repository.lastSubmittedName, 'Chave de carro');
        expect(
          repository.lastSubmittedDescription,
          'Encontrada no estacionamento',
        );
        expect(repository.lastSubmittedLocation, 'Estacionamento principal');
        expect(repository.lastSubmittedStatus, ItemStatus.found);
      },
    );

    testWidgets(
      'A07: preserves filled fields on failure, displays understandable error, and succeeds on retry',
      (tester) async {
        repository.onCreateItem = () async {
          throw const ItemRepositoryException.network();
        };

        await tester.pumpWidget(_buildTestApp(repository: repository));
        await _fillValidForm(
          tester,
          name: 'Mochila preta',
          description: 'Esquecida no banco do pátio',
          location: 'Pátio central',
          status: ItemStatus.lost,
        );

        await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
          ),
          findsOneWidget,
        );
        expect(find.text('Mochila preta'), findsOneWidget);
        expect(find.text('Esquecida no banco do pátio'), findsOneWidget);
        expect(find.text('Pátio central'), findsOneWidget);
        expect(find.byKey(ItemFormScreen.retryButtonKey), findsOneWidget);

        repository.onCreateItem = () async {};

        await tester.tap(find.byKey(ItemFormScreen.retryButtonKey));
        await tester.pumpAndSettle();

        expect(repository.createCallCount, 2);
      },
    );

    testWidgets(
      'A04 & A07: displays server field errors and notifies onUnauthorized when session expires (401)',
      (tester) async {
        var unauthorizedCount = 0;
        repository.onCreateItem = () async {
          throw const ItemRepositoryException(
            'Dados inválidos no servidor.',
            fieldErrors: {
              'name': 'O nome informado foi rejeitado pelo servidor.',
            },
          );
        };

        await tester.pumpWidget(
          _buildTestApp(
            repository: repository,
            onUnauthorized: () {
              unauthorizedCount++;
            },
          ),
        );
        await _fillValidForm(tester);

        await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.pumpAndSettle();

        expect(find.text('Dados inválidos no servidor.'), findsOneWidget);
        expect(
          find.text('O nome informado foi rejeitado pelo servidor.'),
          findsOneWidget,
        );
        expect(unauthorizedCount, 0);

        repository.onCreateItem = () async {
          throw const ItemRepositoryException.unauthorized();
        };

        await tester.tap(find.byKey(ItemFormScreen.retryButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.text('Sessão inválida ou expirada. Entre novamente.'),
          findsOneWidget,
        );
        expect(unauthorizedCount, 1);
      },
    );

    testWidgets(
      'A11: adapts to small screen, enlarged text scaling, and open keyboard without layout overflow and survives disposal while pending',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final completer = Completer<void>();
        repository.onCreateItem = () => completer.future;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              viewInsets: EdgeInsets.only(bottom: 180),
              textScaler: TextScaler.linear(1.5),
            ),
            child: _buildTestApp(repository: repository),
          ),
        );

        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(ItemFormScreen.nameFieldKey),
          'Garrafa',
        );
        await tester.enterText(
          find.byKey(ItemFormScreen.descriptionFieldKey),
          'Descrição curta',
        );
        await tester.enterText(
          find.byKey(ItemFormScreen.locationFieldKey),
          'Bloco A',
        );
        await tester.ensureVisible(find.byKey(ItemFormScreen.statusFieldKey));
        await tester.tap(find.byKey(ItemFormScreen.statusFieldKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Perdido').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        completer.complete();
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
