import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/app/lost_and_found_app.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';
import 'package:lost_and_found/features/auth/domain/auth_user.dart';
import 'package:lost_and_found/features/auth/presentation/auth_session_notifier.dart';
import 'package:lost_and_found/features/lost_found/domain/item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';
import 'package:lost_and_found/features/lost_found/domain/lost_found_item.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_list_screen.dart';

class _FakeItemRepository implements ItemRepository {
  int fetchCallCount = 0;

  @override
  Future<List<LostFoundItem>> fetchItems() async {
    fetchCallCount++;
    return const [];
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
  int restoreCallCount = 0;

  @override
  Future<AuthUser?> restoreSession() async {
    restoreCallCount++;
    return null;
  }

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

void main() {
  late _FakeItemRepository itemRepository;
  late _FakeAuthRepository authRepository;
  late AuthSessionNotifier sessionNotifier;

  setUp(() {
    itemRepository = _FakeItemRepository();
    authRepository = _FakeAuthRepository();
    sessionNotifier = AuthSessionNotifier(repository: authRepository);
  });

  tearDown(() {
    sessionNotifier.dispose();
  });

  Widget buildApp() {
    return LostAndFoundApp(
      authRepository: authRepository,
      itemRepository: itemRepository,
      sessionNotifier: sessionNotifier,
    );
  }

  testWidgets('opens the item list screen as the home route', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Achados e Perdidos'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses Material 3 with Brazilian Portuguese localization', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ItemListScreen));
    expect(Theme.of(context).useMaterial3, isTrue);
    expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
    expect(MaterialLocalizations.of(context).backButtonTooltip, 'Voltar');
  });

  testWidgets('restores the stored session and loads the listing at startup', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(authRepository.restoreCallCount, 1);
    expect(itemRepository.fetchCallCount, 1);
  });
}
