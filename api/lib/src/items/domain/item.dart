enum ItemStatus {
  lost,
  found;

  static ItemStatus? tryParse(String? value) {
    if (value == 'lost') return ItemStatus.lost;
    if (value == 'found') return ItemStatus.found;
    return null;
  }
}

class LostFoundItem {
  final String id;
  final String name;
  final String description;
  final String location;
  final ItemStatus status;
  final DateTime createdAt;
  final String createdBy;

  const LostFoundItem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'location': location,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class NewItem {
  static const maxNameLength = 60;
  static const maxDescriptionLength = 200;

  final String name;
  final String description;
  final String location;
  final ItemStatus status;

  const NewItem._({
    required this.name,
    required this.description,
    required this.location,
    required this.status,
  });

  factory NewItem.validate({
    required Object? name,
    required Object? description,
    required Object? location,
    required Object? status,
  }) {
    final errors = <String, String>{};

    final rawName = name is String ? name.trim() : '';
    if (rawName.isEmpty) {
      errors['name'] = 'Informe o nome do objeto.';
    } else if (rawName.runes.length > maxNameLength) {
      errors['name'] = 'O nome deve ter no máximo $maxNameLength caracteres.';
    }

    final rawDescription = description is String ? description.trim() : '';
    if (rawDescription.isEmpty) {
      errors['description'] = 'Informe a descrição do objeto.';
    } else if (rawDescription.runes.length > maxDescriptionLength) {
      errors['description'] =
          'A descrição deve ter no máximo $maxDescriptionLength caracteres.';
    }

    final rawLocation = location is String ? location.trim() : '';
    if (rawLocation.isEmpty) {
      errors['location'] = 'Informe o local onde foi perdido ou encontrado.';
    }

    final parsedStatus = status is String
        ? ItemStatus.tryParse(status.trim().toLowerCase())
        : null;
    if (parsedStatus == null) {
      errors['status'] = 'Informe a situação (lost ou found).';
    }

    if (errors.isNotEmpty) {
      throw InvalidItemInput(errors);
    }

    return NewItem._(
      name: rawName,
      description: rawDescription,
      location: rawLocation,
      status: parsedStatus!,
    );
  }
}

class InvalidItemInput implements Exception {
  final Map<String, String> fields;

  InvalidItemInput(Map<String, String> fields)
      : fields = Map.unmodifiable(fields);

  @override
  String toString() => 'InvalidItemInput: $fields';
}
