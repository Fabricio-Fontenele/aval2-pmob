import 'item_status.dart';
import 'lost_found_item.dart';

abstract interface class ItemRepository {
  Future<List<LostFoundItem>> fetchItems();

  Future<void> createItem({
    required String name,
    required String description,
    required String location,
    required ItemStatus status,
  });
}

class ItemRepositoryException implements Exception {
  const ItemRepositoryException(
    this.message, {
    this.isUnauthorized = false,
    this.fieldErrors = const {},
  });

  const ItemRepositoryException.unauthorized([
    this.message = 'Sessão inválida ou expirada. Entre novamente.',
  ]) : isUnauthorized = true,
       fieldErrors = const {};

  const ItemRepositoryException.network([
    this.message = 'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
  ]) : isUnauthorized = false,
       fieldErrors = const {};

  final String message;
  final bool isUnauthorized;
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'ItemRepositoryException: $message';
}
