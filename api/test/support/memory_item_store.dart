import 'dart:math';

import 'package:lost_and_found_api/src/items/domain/item.dart';
import 'package:lost_and_found_api/src/items/domain/item_store.dart';

class MemoryItemStore implements ItemStore {
  final List<LostFoundItem> items = [];
  Exception? failure;

  @override
  Future<List<LostFoundItem>> listItems() async {
    final err = failure;
    if (err != null) throw err;
    // Return sorted newest first
    final copy = List<LostFoundItem>.from(items);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  @override
  Future<LostFoundItem> createItem(NewItem item,
      {required String userId}) async {
    final err = failure;
    if (err != null) throw err;

    final created = LostFoundItem(
      id: 'item-${Random().nextInt(1000000)}',
      name: item.name,
      description: item.description,
      location: item.location,
      status: item.status,
      createdAt: DateTime.now().toUtc(),
      createdBy: userId,
    );
    items.add(created);
    return created;
  }
}
