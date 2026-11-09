import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/app/app_theme.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';
import 'package:lost_and_found/features/auth/domain/auth_user.dart';
import 'package:lost_and_found/features/auth/presentation/auth_session_notifier.dart';
import 'package:lost_and_found/features/lost_found/domain/item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';
import 'package:lost_and_found/features/lost_found/domain/lost_found_item.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_date_format.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_list_screen.dart';

class _FakeItemRepository implements ItemRepository {
  int fetchCallCount = 0;
  Future<List<LostFoundItem>> Function()? onFetchItems;

  @override
  Future<List<LostFoundItem>> fetchItems() {
    fetchCallCount++;
    if (onFetchItems != null) {
      return onFetchItems!();
    }
    return Future.value(const []);
  }

  @override
  Future<void> createItem({
    required String name,
    required String description,
    required String location,
    required ItemStatus status,
  }) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => const AuthUser(id: 'user-login');

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async => const AuthUser(id: 'user-register');

  @override
  Future<void> logout() async {}
}

LostFoundItem _item(
  String id, {
  String name = 'Mochila preta',
  String description = 'Mochila com cadernos de cálculo.',
  String location = 'Bloco A, sala 12',
  ItemStatus status = ItemStatus.lost,
  DateTime? createdAt,
}) {
  return LostFoundItem(
    id: id,
    name: name,
    description: description,
    location: location,
    status: status,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 7, 12, 30),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ItemRepository itemRepository,
  MediaQueryData? mediaQuery,
}) async {
  final authRepository = _FakeAuthRepository();
  final sessionNotifier = AuthSessionNotifier(repository: authRepository);
  addTearDown(sessionNotifier.dispose);

  final Widget app = MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ItemListScreen(
      itemRepository: itemRepository,
      authRepository: authRepository,
      sessionNotifier: sessionNotifier,
    ),
  );

  await tester.pumpWidget(
    mediaQuery == null ? app : MediaQuery(data: mediaQuery, child: app),
  );
}

void main() {
  group('ItemListScreen', () {
    late _FakeItemRepository repository;

    setUp(() {
      repository = _FakeItemRepository();
    });

    testWidgets(
      'A01: shows name, status, description, location, and creation date of each record, newest first',
      (tester) async {
        final newest = DateTime.utc(2026, 11, 8, 21, 30);
        repository.onFetchItems = () async => [
          _item(
            'newest',
            name: 'Mochila preta',
            description: 'Mochila com cadernos de cálculo.',
            location: 'Bloco A, sala 12',
            createdAt: newest,
          ),
          _item(
            'older',
            name: 'Garrafa térmica',
            description: 'Garrafa encontrada no auditório.',
            location: 'Auditório Central',
            status: ItemStatus.found,
            createdAt: DateTime.utc(2026, 11, 1, 8),
          ),
        ];

        await _pumpScreen(tester, itemRepository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Mochila preta'), findsOneWidget);
        expect(find.text('Mochila com cadernos de cálculo.'), findsOneWidget);
        expect(find.text('Bloco A, sala 12'), findsOneWidget);
        expect(find.text(formatItemDateTime(newest)), findsOneWidget);
        expect(find.text('Garrafa térmica'), findsOneWidget);

        final firstCard = tester.getTopLeft(
          find.byKey(ItemListScreen.cardKey('newest')),
        );
        final secondCard = tester.getTopLeft(
          find.byKey(ItemListScreen.cardKey('older')),
        );
        expect(firstCard.dy, lessThan(secondCard.dy));
      },
    );

    testWidgets(
      'distinguishes lost from found with readable labels and distinct styling',
      (tester) async {
        repository.onFetchItems = () async => [
          _item('lost-item'),
          _item('found-item', status: ItemStatus.found),
        ];

        await _pumpScreen(tester, itemRepository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Perdido'), findsOneWidget);
        expect(find.text('Encontrado'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

        final lostBorder =
            tester
                    .widget<Card>(
                      find.byKey(ItemListScreen.cardKey('lost-item')),
                    )
                    .shape
                as RoundedRectangleBorder;
        final foundBorder =
            tester
                    .widget<Card>(
                      find.byKey(ItemListScreen.cardKey('found-item')),
                    )
                    .shape
                as RoundedRectangleBorder;
        expect(lostBorder.side.color, isNot(foundBorder.side.color));
      },
    );

    testWidgets('reports progress and blocks a duplicate manual refresh', (
      tester,
    ) async {
      final response = Completer<List<LostFoundItem>>();
      repository.onFetchItems = () => response.future;

      await _pumpScreen(tester, itemRepository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Carregando objetos...'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(ItemListScreen.refreshButtonKey))
            .onPressed,
        isNull,
      );

      response.complete(const []);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.fetchCallCount, 1);
    });

    testWidgets('A02: shows a usable empty state and refreshes on demand', (
      tester,
    ) async {
      repository.onFetchItems = () async =>
          repository.fetchCallCount == 1 ? const [] : [_item('a')];

      await _pumpScreen(tester, itemRepository: repository);
      await tester.pumpAndSettle();

      expect(find.byKey(ItemListScreen.emptyStateKey), findsOneWidget);
      expect(find.text('Nenhum objeto cadastrado ainda.'), findsOneWidget);
      expect(find.text('Cadastrar objeto'), findsOneWidget);

      await tester.tap(find.byKey(ItemListScreen.refreshButtonKey));
      await tester.pumpAndSettle();

      expect(repository.fetchCallCount, 2);
      expect(find.byKey(ItemListScreen.emptyStateKey), findsNothing);
      expect(find.byKey(ItemListScreen.cardKey('a')), findsOneWidget);
    });

    testWidgets('A06: a read failure shows an error and retrying recovers', (
      tester,
    ) async {
      repository.onFetchItems = () async {
        if (repository.fetchCallCount == 1) {
          throw const ItemRepositoryException.network();
        }
        return [_item('a')];
      };

      await _pumpScreen(tester, itemRepository: repository);
      await tester.pumpAndSettle();

      expect(find.byKey(ItemListScreen.errorStateKey), findsOneWidget);
      expect(
        find.textContaining('Não foi possível conectar ao servidor'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ItemListScreen.retryButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ItemListScreen.errorStateKey), findsNothing);
      expect(find.byKey(ItemListScreen.cardKey('a')), findsOneWidget);
      expect(repository.fetchCallCount, 2);
    });

    testWidgets(
      'a failed refresh keeps the loaded content with a retry action',
      (tester) async {
        repository.onFetchItems = () async {
          if (repository.fetchCallCount == 1) {
            return [_item('a')];
          }
          throw const ItemRepositoryException('Serviço indisponível.');
        };

        await _pumpScreen(tester, itemRepository: repository);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ItemListScreen.refreshButtonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(ItemListScreen.cardKey('a')), findsOneWidget);
        expect(find.byKey(ItemListScreen.errorStateKey), findsOneWidget);
        expect(find.text('Serviço indisponível.'), findsOneWidget);
        expect(find.byKey(ItemListScreen.retryButtonKey), findsOneWidget);
      },
    );

    testWidgets('uses Material 3 and Brazilian Portuguese labels', (
      tester,
    ) async {
      await _pumpScreen(tester, itemRepository: repository);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ItemListScreen));
      expect(Theme.of(context).useMaterial3, isTrue);
      expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Achados e Perdidos'),
        ),
        findsOneWidget,
      );
      expect(find.text('Cadastrar'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(ItemListScreen.refreshButtonKey))
            .tooltip,
        'Atualizar lista',
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(ItemListScreen.signInButtonKey))
            .tooltip,
        'Entrar',
      );
    });

    testWidgets(
      'A11: adapts to a small screen with enlarged text and survives disposal while reading',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final response = Completer<List<LostFoundItem>>();
        repository.onFetchItems = () => response.future;

        await _pumpScreen(
          tester,
          itemRepository: repository,
          mediaQuery: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(1.5),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        response.complete([
          _item(
            'a',
            name: 'Caderno de anotações da disciplina de cálculo numérico',
            description:
                'Caderno com capa azul, espiral, contendo anotações das '
                'primeiras aulas e um marcador de páginas amarelo.',
            location: 'Biblioteca central, segundo andar, mesa dos fundos',
          ),
          _item('b', status: ItemStatus.found),
        ]);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(ItemListScreen.cardKey('a')), findsOneWidget);

        final pending = Completer<List<LostFoundItem>>();
        repository.onFetchItems = () => pending.future;
        await tester.tap(find.byKey(ItemListScreen.refreshButtonKey));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete([_item('c')]);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the empty state fits a small screen without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _pumpScreen(
        tester,
        itemRepository: repository,
        mediaQuery: const MediaQueryData(
          size: Size(320, 480),
          textScaler: TextScaler.linear(1.5),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ItemListScreen.emptyStateKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
