import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/features/lost_found/domain/item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';
import 'package:lost_and_found/features/lost_found/domain/lost_found_item.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_form_notifier.dart';

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

void main() {
  group('ItemFormNotifier', () {
    late _FakeItemRepository repository;
    late ItemFormNotifier notifier;

    setUp(() {
      repository = _FakeItemRepository();
      notifier = ItemFormNotifier(repository: repository);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('starts in idle state with no errors', () {
      expect(notifier.status, ItemFormStatus.idle);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.isSucceeded, isFalse);
      expect(notifier.hasError, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(notifier.fieldErrors, isEmpty);
      expect(notifier.requiresAuthentication, isFalse);
    });

    test('rejects invalid input without calling the repository and exposes field errors', () async {
      final succeeded = await notifier.submit(
        name: '   ',
        description: 'B' * 201,
        location: '',
        status: null,
      );

      expect(succeeded, isFalse);
      expect(repository.createCallCount, 0);
      expect(notifier.status, ItemFormStatus.failed);
      expect(notifier.hasError, isTrue);
      expect(notifier.fieldErrors['name'], 'Informe o nome do objeto.');
      expect(
        notifier.fieldErrors['description'],
        'A descrição deve ter no máximo 200 caracteres.',
      );
      expect(
        notifier.fieldErrors['location'],
        'Informe o local onde foi perdido ou encontrado.',
      );
      expect(notifier.fieldErrors['status'], 'Informe a situação do objeto.');
    });

    test(
      'transitions through submitting to succeeded and sends trimmed values',
      () async {
        final completer = Completer<void>();
        repository.onCreateItem = () => completer.future;

        final observedStatuses = <ItemFormStatus>[];
        notifier.addListener(() {
          observedStatuses.add(notifier.status);
        });

        final future = notifier.submit(
          name: '  Caderno universitário  ',
          description: '  Capa azul, esquecido na sala 4  ',
          location: '  Bloco C, Sala 4  ',
          status: ItemStatus.lost,
        );

        expect(notifier.status, ItemFormStatus.submitting);
        expect(notifier.isSubmitting, isTrue);

        completer.complete();
        final succeeded = await future;

        expect(succeeded, isTrue);
        expect(notifier.status, ItemFormStatus.succeeded);
        expect(notifier.isSucceeded, isTrue);
        expect(notifier.errorMessage, isNull);
        expect(observedStatuses, [
          ItemFormStatus.submitting,
          ItemFormStatus.succeeded,
        ]);
        expect(repository.createCallCount, 1);
        expect(repository.lastSubmittedName, 'Caderno universitário');
        expect(
          repository.lastSubmittedDescription,
          'Capa azul, esquecido na sala 4',
        );
        expect(repository.lastSubmittedLocation, 'Bloco C, Sala 4');
        expect(repository.lastSubmittedStatus, ItemStatus.lost);
      },
    );

    test('ignores duplicate submit calls while a submission is already in progress', () async {
      final completer = Completer<void>();
      repository.onCreateItem = () => completer.future;

      final firstCall = notifier.submit(
        name: 'Chaveiro',
        description: 'Com duas chaves',
        location: 'Portaria',
        status: ItemStatus.found,
      );
      final secondCall = notifier.submit(
        name: 'Chaveiro',
        description: 'Com duas chaves',
        location: 'Portaria',
        status: ItemStatus.found,
      );

      expect(await secondCall, isFalse);
      expect(repository.createCallCount, 1);

      completer.complete();
      expect(await firstCall, isTrue);
      expect(repository.createCallCount, 1);
    });

    test(
      'exposes recoverable error on failure and succeeds when retried',
      () async {
        repository.onCreateItem = () async {
          throw const ItemRepositoryException.network();
        };

        final firstAttempt = await notifier.submit(
          name: 'Óculos de grau',
          description: 'Armação preta no estojo marrom',
          location: 'Laboratório 2',
          status: ItemStatus.lost,
        );

        expect(firstAttempt, isFalse);
        expect(notifier.status, ItemFormStatus.failed);
        expect(notifier.isSubmitting, isFalse);
        expect(notifier.hasError, isTrue);
        expect(
          notifier.errorMessage,
          'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
        );
        expect(notifier.requiresAuthentication, isFalse);

        repository.onCreateItem = () async {};

        final retryAttempt = await notifier.submit(
          name: 'Óculos de grau',
          description: 'Armação preta no estojo marrom',
          location: 'Laboratório 2',
          status: ItemStatus.lost,
        );

        expect(retryAttempt, isTrue);
        expect(notifier.status, ItemFormStatus.succeeded);
        expect(notifier.hasError, isFalse);
        expect(notifier.errorMessage, isNull);
        expect(repository.createCallCount, 2);
      },
    );

    test('marks requiresAuthentication and invokes callback on 401 unauthorized failure', () async {
      var unauthorizedCallbacks = 0;
      final authNotifier = ItemFormNotifier(
        repository: repository,
        onUnauthorized: () {
          unauthorizedCallbacks++;
        },
      );
      addTearDown(authNotifier.dispose);

      repository.onCreateItem = () async {
        throw const ItemRepositoryException.unauthorized();
      };

      final succeeded = await authNotifier.submit(
        name: 'Calculadora científica',
        description: 'Encontrada sobre a bancada',
        location: 'Sala 10',
        status: ItemStatus.found,
      );

      expect(succeeded, isFalse);
      expect(authNotifier.status, ItemFormStatus.failed);
      expect(authNotifier.requiresAuthentication, isTrue);
      expect(
        authNotifier.errorMessage,
        'Sessão inválida ou expirada. Entre novamente.',
      );
      expect(unauthorizedCallbacks, 1);
    });

    test('does not notify listeners if disposed while an asynchronous save is pending', () async {
      final completer = Completer<void>();
      repository.onCreateItem = () => completer.future;

      final disposableNotifier = ItemFormNotifier(repository: repository);
      var notificationCount = 0;
      disposableNotifier.addListener(() {
        notificationCount++;
      });

      final future = disposableNotifier.submit(
        name: 'Relógio digital',
        description: 'Pulseira preta de borracha',
        location: 'Quadra poliesportiva',
        status: ItemStatus.found,
      );
      expect(notificationCount, 1);

      disposableNotifier.dispose();
      completer.complete();

      await future;
      expect(notificationCount, 1);
    });
  });
}
