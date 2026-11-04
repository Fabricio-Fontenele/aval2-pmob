import 'item.dart';

abstract interface class ItemStore {
  Future<List<LostFoundItem>> listItems();
  Future<LostFoundItem> createItem(NewItem item, {required String userId});
}

class ItemStorageException implements Exception {
  final String? message;
  final Object? cause;

  const ItemStorageException([this.message, this.cause]);

  @override
  String toString() => message != null
      ? 'ItemStorageException: $message'
      : 'ItemStorageException';
}
