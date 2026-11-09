import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/features/lost_found/domain/item_repository.dart';
import 'package:lost_and_found/features/lost_found/domain/item_status.dart';
import 'package:lost_and_found/features/lost_found/domain/lost_found_item.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_list_notifier.dart';

class _FakeItemRepository implements ItemRepository {
  int fetchCallCount = 0;
  int createCallCount = 0;
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
  }) async {
    createCallCount++;
  }
}

LostFoundItem _item(String id, {ItemStatus status = ItemStatus.lost}) {
  return LostFoundItem(
    id: id,
    name: 'Objeto $id',
    description: 'Descrição do objeto $id.',
    location: 'Bloco A',
    status: status,
    createdAt: DateTime.utc(2026, 11, 7, 12),
  );
}

void main() {
  group('ItemListNotifier', () {
    late _FakeItemRepository repository;
    late ItemListNotifier notifier;

    setUp(() {
      repository = _FakeItemRepository();
      notifier = ItemListNotifier(repository: repository);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('starts without content and without reading the repository', () {
      expect(notifier.status, ItemListStatus.initial);
      expect(notifier.items, isEmpty);
      expect(notifier.isLoading, isFalse);
      expect(notifier.isEmpty, isFalse);
      expect(notifier.hasError, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(notifier.savedItemAwaitingRefresh, isFalse);
      expect(repository.fetchCallCount, 0);
    });

    test('reports progress and then the loaded content', () async {
      final response = Completer<List<LostFoundItem>>();
      repository.onFetchItems = () => response.future;
      final states = <ItemListStatus>[];
      notifier.addListener(() => states.add(notifier.status));

      final load = notifier.load();
      expect(notifier.isLoading, isTrue);

      response.complete([_item('a'), _item('b')]);
      await load;

      expect(states, [ItemListStatus.loading, ItemListStatus.loaded]);
      expect(notifier.items.map((item) => item.id), ['a', 'b']);
      expect(notifier.isLoading, isFalse);
      expect(notifier.isEmpty, isFalse);
      expect(notifier.hasError, isFalse);
    });

    test('an empty successful read reports the empty listing', () async {
      await notifier.load();

      expect(notifier.status, ItemListStatus.loaded);
      expect(notifier.isEmpty, isTrue);
      expect(notifier.items, isEmpty);
    });

    test('exposes the content as an unmodifiable view', () async {
      repository.onFetchItems = () async => [_item('a')];

      await notifier.load();

      expect(() => notifier.items.add(_item('b')), throwsUnsupportedError);
    });

    test('a failed read reports a message and allows a retry', () async {
      repository.onFetchItems = () async =>
          throw const ItemRepositoryException.network();

      await notifier.load();

      expect(notifier.hasError, isTrue);
      expect(notifier.isLoading, isFalse);
      expect(
        notifier.errorMessage,
        contains('Não foi possível conectar ao servidor'),
      );

      repository.onFetchItems = () async => [_item('a')];
      await notifier.refresh();

      expect(notifier.hasError, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(notifier.items.map((item) => item.id), ['a']);
      expect(repository.fetchCallCount, 2);
    });

    test('an unexpected failure reports a readable message', () async {
      repository.onFetchItems = () async => throw Exception('unexpected');

      await notifier.load();

      expect(notifier.hasError, isTrue);
      expect(
        notifier.errorMessage,
        'Não foi possível carregar a lista. Tente novamente.',
      );
    });

    test('a failed refresh preserves the content already loaded', () async {
      repository.onFetchItems = () async => [_item('a')];
      await notifier.load();

      repository.onFetchItems = () async =>
          throw const ItemRepositoryException('Serviço indisponível.');
      await notifier.refresh();

      expect(notifier.hasError, isTrue);
      expect(notifier.errorMessage, 'Serviço indisponível.');
      expect(notifier.items.map((item) => item.id), ['a']);
    });

    test('repeated refreshes while reading issue a single request', () async {
      final response = Completer<List<LostFoundItem>>();
      repository.onFetchItems = () => response.future;

      final first = notifier.load();
      final second = notifier.refresh();
      final third = notifier.refresh();
      response.complete([_item('a')]);
      await Future.wait([first, second, third]);

      expect(repository.fetchCallCount, 1);
    });

    test(
      'a confirmed save awaits the refresh and never republishes the object',
      () async {
        repository.onFetchItems = () async =>
            throw const ItemRepositoryException.network();

        await notifier.refreshAfterSave();

        expect(notifier.savedItemAwaitingRefresh, isTrue);
        expect(notifier.hasError, isTrue);
        expect(repository.createCallCount, 0);

        // Retrying the refresh only reads again.
        repository.onFetchItems = () async => [_item('saved')];
        await notifier.refresh();

        expect(notifier.savedItemAwaitingRefresh, isFalse);
        expect(notifier.hasError, isFalse);
        expect(notifier.items.map((item) => item.id), ['saved']);
        expect(repository.createCallCount, 0);
      },
    );

    test('a refresh after saving overrides an older in-flight read', () async {
      final stale = Completer<List<LostFoundItem>>();
      final fresh = Completer<List<LostFoundItem>>();
      var calls = 0;
      repository.onFetchItems = () {
        calls++;
        return calls == 1 ? stale.future : fresh.future;
      };

      final load = notifier.load();
      final afterSave = notifier.refreshAfterSave();

      fresh.complete([_item('saved'), _item('older')]);
      stale.complete([_item('older')]);
      await Future.wait([load, afterSave]);

      expect(repository.fetchCallCount, 2);
      expect(notifier.items.map((item) => item.id), ['saved', 'older']);
      expect(notifier.savedItemAwaitingRefresh, isFalse);
      expect(notifier.hasError, isFalse);
    });

    test('a response that arrives after disposal is ignored', () async {
      final response = Completer<List<LostFoundItem>>();
      repository.onFetchItems = () => response.future;
      final disposableNotifier = ItemListNotifier(repository: repository);
      var notifications = 0;
      disposableNotifier.addListener(() => notifications++);

      final load = disposableNotifier.load();
      final notificationsWhileLoading = notifications;
      disposableNotifier.dispose();
      response.complete([_item('a')]);
      await load;

      expect(notificationsWhileLoading, 1);
      expect(notifications, notificationsWhileLoading);
      expect(disposableNotifier.items, isEmpty);
    });

    test('a failure that arrives after disposal is ignored', () async {
      final response = Completer<List<LostFoundItem>>();
      repository.onFetchItems = () => response.future;
      final disposableNotifier = ItemListNotifier(repository: repository);

      final load = disposableNotifier.load();
      disposableNotifier.dispose();
      response.completeError(const ItemRepositoryException.network());

      await expectLater(load, completes);
      expect(disposableNotifier.hasError, isFalse);
    });
  });
}
