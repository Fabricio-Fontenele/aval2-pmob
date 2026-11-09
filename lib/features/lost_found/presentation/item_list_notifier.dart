import 'package:flutter/foundation.dart';

import '../domain/item_repository.dart';
import '../domain/lost_found_item.dart';

enum ItemListStatus { initial, loading, loaded, failed }

/// Holds the shared listing content and the state of its remote reads.
///
/// A failed read keeps the last content that was loaded successfully, so a
/// refresh failure never empties the list the user is already browsing.
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

  /// Whether a confirmed remote save still has not appeared in the listing.
  ///
  /// It keeps a persisted object distinguishable from a failed refresh, so
  /// retrying the refresh never republishes the object.
  bool get savedItemAwaitingRefresh => _savedItemAwaitingRefresh;

  /// Loads the listing for the first time or after a failure.
  Future<void> load() => _read();

  /// Reads the listing again on demand, keeping the current content visible.
  Future<void> refresh() => _read();

  /// Reads the listing after a confirmed save, even while another read runs,
  /// so the new object cannot be missed by an older in-flight response.
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
