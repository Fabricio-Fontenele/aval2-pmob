import 'package:flutter/foundation.dart';

import '../domain/item_input_validator.dart';
import '../domain/item_repository.dart';
import '../domain/item_status.dart';

enum ItemFormStatus { idle, submitting, succeeded, failed }

class ItemFormNotifier extends ChangeNotifier {
  ItemFormNotifier({required this._repository, this._onUnauthorized});

  final ItemRepository _repository;
  final VoidCallback? _onUnauthorized;

  ItemFormStatus _status = ItemFormStatus.idle;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _requiresAuthentication = false;
  bool _isDisposed = false;

  ItemFormStatus get status => _status;
  bool get isSubmitting => _status == ItemFormStatus.submitting;
  bool get isSucceeded => _status == ItemFormStatus.succeeded;
  bool get hasError => _status == ItemFormStatus.failed;
  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => _fieldErrors;
  bool get requiresAuthentication => _requiresAuthentication;

  Future<bool> submit({
    required String? name,
    required String? description,
    required String? location,
    required ItemStatus? status,
  }) async {
    if (_isDisposed || _status == ItemFormStatus.submitting) {
      return false;
    }

    final ValidatedItemInput validated;
    try {
      validated = ItemInputValidator.validate(
        name: name,
        description: description,
        location: location,
        status: status,
      );
    } on ItemValidationException catch (error) {
      _status = ItemFormStatus.failed;
      _errorMessage = 'Confira os campos destacados antes de salvar.';
      _fieldErrors = error.fields;
      _requiresAuthentication = false;
      _notifySafely();
      return false;
    }

    _status = ItemFormStatus.submitting;
    _errorMessage = null;
    _fieldErrors = const {};
    _requiresAuthentication = false;
    _notifySafely();

    try {
      await _repository.createItem(
        name: validated.name,
        description: validated.description,
        location: validated.location,
        status: validated.status,
      );
      _status = ItemFormStatus.succeeded;
      _notifySafely();
      return true;
    } on ItemRepositoryException catch (error) {
      _status = ItemFormStatus.failed;
      _errorMessage = error.message;
      _fieldErrors = Map.unmodifiable(error.fieldErrors);
      _requiresAuthentication = error.isUnauthorized;
      if (error.isUnauthorized && !_isDisposed) {
        _onUnauthorized?.call();
      }
      _notifySafely();
      return false;
    } on Object {
      _status = ItemFormStatus.failed;
      _errorMessage = 'Não foi possível salvar o objeto. Tente novamente.';
      _fieldErrors = const {};
      _requiresAuthentication = false;
      _notifySafely();
      return false;
    }
  }

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
