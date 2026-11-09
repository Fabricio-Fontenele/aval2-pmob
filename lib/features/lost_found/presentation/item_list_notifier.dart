import 'package:flutter/foundation.dart';

import '../domain/item_repository.dart';
import '../domain/lost_found_item.dart';

enum ItemListStatus { initial, loading, loaded, failed }

class ItemListNotifier extends ChangeNotifier {
  ItemListNotifier({required this.repository});

  final ItemRepository repository;

  ItemListStatus _status = ItemListStatus.initial;
  List<LostFoundItem> _items = const [];
  String? _errorMessage;
  bool _savedItemAwaitingRefresh = false;
  bool _isDisposed = false;
  int _readEpoch = 0;

  ItemListStatus get status => _status;
  List<LostFoundItem> get items => _items;
  bool get isLoading => _status == ItemListStatus.loading;
  bool get hasError => _status == ItemListStatus.failed;
  bool get isEmpty => _status == ItemListStatus.loaded && _items.isEmpty;
  String? get errorMessage => _errorMessage;

  bool get savedItemAwaitingRefresh => _savedItemAwaitingRefresh;

  Future<void> load() => _read();

  Future<void> refresh() => _read();

  Future<void> refreshAfterSave() {
    _savedItemAwaitingRefresh = true;
    return _read(force: true);
  }

  Future<void> _read({bool force = false}) async {
    if (_status == ItemListStatus.loading && !force) {
      return;
    }

    final operationEpoch = ++_readEpoch;
    _status = ItemListStatus.loading;
    _errorMessage = null;
    _notifySafely();

    try {
      final items = await repository.fetchItems();
      if (_isOutdated(operationEpoch)) {
        return;
      }
      _items = List.unmodifiable(items);
      _status = ItemListStatus.loaded;
      _errorMessage = null;
      _savedItemAwaitingRefresh = false;
      _notifySafely();
    } on ItemRepositoryException catch (error) {
      _fail(operationEpoch, error.message);
    } on Object {
      _fail(
        operationEpoch,
        'Não foi possível carregar a lista. Tente novamente.',
      );
    }
  }

  void _fail(int operationEpoch, String message) {
    if (_isOutdated(operationEpoch)) {
      return;
    }
    _status = ItemListStatus.failed;
    _errorMessage = message;
    _notifySafely();
  }

  bool _isOutdated(int operationEpoch) =>
      _isDisposed || operationEpoch != _readEpoch;

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
