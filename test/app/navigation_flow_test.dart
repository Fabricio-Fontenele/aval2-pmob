import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/app/lost_and_found_app.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';
import 'package:lost_and_found/features/auth/domain/auth_user.dart';
import 'package:lost_and_found/features/auth/presentation/auth_session_notifier.dart';
import 'package:lost_and_found/features/auth/presentation/login_screen.dart';
import 'package:lost_and_found/features/lost_found/domain/item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';
import 'package:lost_and_found/features/lost_found/domain/lost_found_item.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_form_screen.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_list_screen.dart';

class _FakeItemRepository implements ItemRepository {
  int fetchCallCount = 0;
  int createCallCount = 0;
  Future<List<LostFoundItem>> Function()? onFetchItems;
  Future<void> Function()? onCreateItem;

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
  }) async {
    createCallCount++;
    if (onCreateItem != null) {
      await onCreateItem!();
    }
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.storedUser});

  AuthUser? storedUser;
  int loginCallCount = 0;
  int logoutCallCount = 0;

  @override
  Future<AuthUser?> restoreSession() async => storedUser;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    loginCallCount++;
    return const AuthUser(id: 'user-login');
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async => const AuthUser(id: 'user-register');

  @override
  Future<void> logout() async {
    logoutCallCount++;
    storedUser = null;
  }
}

const _signedInUser = AuthUser(id: 'user-session');

LostFoundItem _item(String id, {String name = 'Mochila preta'}) {
  return LostFoundItem(
    id: id,
    name: name,
    description: 'Mochila com cadernos de cálculo.',
    location: 'Bloco A, sala 12',
    status: ItemStatus.lost,
    createdAt: DateTime.utc(2026, 11, 7, 12, 30),
  );
}

void main() {
  late _FakeItemRepository itemRepository;
  late _FakeAuthRepository authRepository;
  late AuthSessionNotifier sessionNotifier;

  void createDependencies({AuthUser? storedUser}) {
    itemRepository = _FakeItemRepository();
    authRepository = _FakeAuthRepository(storedUser: storedUser);
    sessionNotifier = AuthSessionNotifier(repository: authRepository);
    addTearDown(sessionNotifier.dispose);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      LostAndFoundApp(
        authRepository: authRepository,
        itemRepository: itemRepository,
        sessionNotifier: sessionNotifier,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillItemForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(ItemFormScreen.nameFieldKey),
      'Garrafa térmica azul',
    );
    await tester.enterText(
      find.byKey(ItemFormScreen.descriptionFieldKey),
      'Encontrada perto do auditório central.',
    );
    await tester.enterText(
      find.byKey(ItemFormScreen.locationFieldKey),
      'Auditório Central',
    );
    await tester.tap(find.byKey(ItemFormScreen.statusFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encontrado').last);
    await tester.pumpAndSettle();
  }

  Future<void> submitItemForm(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(ItemFormScreen.submitButtonKey));
    await tester.tap(find.byKey(ItemFormScreen.submitButtonKey));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(LoginScreen.emailFieldKey),
      'avaliador@example.test',
    );
    await tester.enterText(
      find.byKey(LoginScreen.passwordFieldKey),
      'SenhaDemo123',
    );
    await tester.tap(find.byKey(LoginScreen.submitButtonKey));
    await tester.pumpAndSettle();
  }

  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'A16: publishing without a session asks for sign-in and returns to the requested screen',
    (tester) async {
      createDependencies();
      await pumpApp(tester);

      expect(find.byKey(ItemListScreen.signInButtonKey), findsOneWidget);

      await tester.tap(find.byKey(ItemListScreen.publishButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ItemFormScreen), findsNothing);

      await signIn(tester);

      expect(authRepository.loginCallCount, 1);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(ItemFormScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Cadastrar objeto'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('A16: cancelling sign-in keeps the public listing available', (
    tester,
  ) async {
    createDependencies();
    itemRepository.onFetchItems = () async => [_item('a')];
    await pumpApp(tester);

    await tester.tap(find.byKey(ItemListScreen.publishButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(ItemFormScreen), findsNothing);
    expect(find.byKey(ItemListScreen.cardKey('a')), findsOneWidget);
    expect(authRepository.loginCallCount, 0);
  });

  testWidgets(
    'A04: a restored session publishes an object and the list shows it without restarting',
    (tester) async {
      createDependencies(storedUser: _signedInUser);
      itemRepository.onFetchItems = () async =>
          itemRepository.fetchCallCount == 1 ? const [] : [_item('saved')];
      await pumpApp(tester);

      expect(find.byKey(ItemListScreen.signOutButtonKey), findsOneWidget);

      await tester.tap(find.byKey(ItemListScreen.publishButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(ItemFormScreen), findsOneWidget);

      await fillItemForm(tester);
      await submitItemForm(tester);

      expect(itemRepository.createCallCount, 1);
      expect(find.byType(ItemFormScreen), findsNothing);
      expect(find.text('Objeto cadastrado com sucesso.'), findsOneWidget);
      expect(find.byKey(ItemListScreen.cardKey('saved')), findsOneWidget);
      expect(itemRepository.fetchCallCount, 2);

      await settleSnackBar(tester);
    },
  );

  testWidgets(
    'A08: a confirmed save with a failed refresh is distinguished and retrying does not publish again',
    (tester) async {
      createDependencies(storedUser: _signedInUser);
      itemRepository.onFetchItems = () async {
        switch (itemRepository.fetchCallCount) {
          case 1:
            return [_item('existing')];
          case 2:
            throw const ItemRepositoryException.network();
          default:
            return [_item('saved'), _item('existing')];
        }
      };
      await pumpApp(tester);

      await tester.tap(find.byKey(ItemListScreen.publishButtonKey));
      await tester.pumpAndSettle();
      await fillItemForm(tester);
      await submitItemForm(tester);

      expect(itemRepository.createCallCount, 1);
      expect(
        find.textContaining('O objeto foi salvo no servidor'),
        findsOneWidget,
      );
      expect(find.byKey(ItemListScreen.cardKey('existing')), findsOneWidget);

      await settleSnackBar(tester);

      await tester.tap(find.byKey(ItemListScreen.retryButtonKey));
      await tester.pumpAndSettle();

      expect(itemRepository.createCallCount, 1);
      expect(itemRepository.fetchCallCount, 3);
      expect(find.byKey(ItemListScreen.cardKey('saved')), findsOneWidget);
      expect(
        find.textContaining('O objeto foi salvo no servidor'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'A16: signing out blocks the protected action and leaves no protected screen to return to',
    (tester) async {
      createDependencies(storedUser: _signedInUser);
      await pumpApp(tester);

      await tester.tap(find.byKey(ItemListScreen.signOutButtonKey));
      await tester.pumpAndSettle();

      expect(authRepository.logoutCallCount, 1);
      expect(find.text('Sessão encerrada.'), findsOneWidget);
      expect(find.byKey(ItemListScreen.signInButtonKey), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);

      await settleSnackBar(tester);

      await tester.tap(find.byKey(ItemListScreen.publishButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ItemFormScreen), findsNothing);
    },
  );

  testWidgets(
    'a session rejected while saving asks for sign-in without losing the typed data',
    (tester) async {
      createDependencies(storedUser: _signedInUser);
      itemRepository.onCreateItem = () async =>
          throw const ItemRepositoryException.unauthorized();
      await pumpApp(tester);

      await tester.tap(find.byKey(ItemListScreen.publishButtonKey));
      await tester.pumpAndSettle();
      await fillItemForm(tester);
      await submitItemForm(tester);

      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ItemFormScreen), findsOneWidget);
      final nameField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(ItemFormScreen.nameFieldKey),
          matching: find.byType(EditableText),
        ),
      );
      expect(nameField.controller.text, 'Garrafa térmica azul');
      expect(itemRepository.createCallCount, 1);
    },
  );
}
