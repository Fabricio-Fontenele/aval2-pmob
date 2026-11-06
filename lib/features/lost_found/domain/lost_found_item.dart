import 'item_status.dart';

class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final ItemStatus status;
  final DateTime createdAt;
}
