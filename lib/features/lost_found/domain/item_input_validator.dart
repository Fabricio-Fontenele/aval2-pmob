import 'item_status.dart';

class ValidatedItemInput {
  const ValidatedItemInput({
    required this.name,
    required this.description,
    required this.location,
    required this.status,
  });

  final String name;
  final String description;
  final String location;
  final ItemStatus status;
}

class ItemValidationException implements Exception {
  ItemValidationException(Map<String, String> fields)
    : fields = Map.unmodifiable(fields);

  final Map<String, String> fields;

  String? get nameError => fields['name'];
  String? get descriptionError => fields['description'];
  String? get locationError => fields['location'];
  String? get statusError => fields['status'];

  @override
  String toString() => 'ItemValidationException: $fields';
}

abstract final class ItemInputValidator {
  static const int maxNameLength = 60;
  static const int maxDescriptionLength = 200;

  static String? validateName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe o nome do objeto.';
    }
    if (trimmed.runes.length > maxNameLength) {
      return 'O nome deve ter no máximo $maxNameLength caracteres.';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe a descrição do objeto.';
    }
    if (trimmed.runes.length > maxDescriptionLength) {
      return 'A descrição deve ter no máximo $maxDescriptionLength caracteres.';
    }
    return null;
  }

  static String? validateLocation(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe o local onde foi perdido ou encontrado.';
    }
    return null;
  }

  static String? validateStatus(ItemStatus? status) {
    if (status == null) {
      return 'Informe a situação do objeto.';
    }
    return null;
  }

  static ValidatedItemInput validate({
    required String? name,
    required String? description,
    required String? location,
    required ItemStatus? status,
  }) {
    final errors = <String, String>{};

    final nameError = validateName(name);
    if (nameError != null) {
      errors['name'] = nameError;
    }

    final descriptionError = validateDescription(description);
    if (descriptionError != null) {
      errors['description'] = descriptionError;
    }

    final locationError = validateLocation(location);
    if (locationError != null) {
      errors['location'] = locationError;
    }

    final statusError = validateStatus(status);
    if (statusError != null) {
      errors['status'] = statusError;
    }

    if (errors.isNotEmpty) {
      throw ItemValidationException(errors);
    }

    return ValidatedItemInput(
      name: name!.trim(),
      description: description!.trim(),
      location: location!.trim(),
      status: status!,
    );
  }
}
