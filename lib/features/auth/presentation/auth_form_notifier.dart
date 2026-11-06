import 'package:flutter/foundation.dart';

import '../domain/auth_input_validator.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_session_notifier.dart';

enum AuthFormStatus { idle, submitting, succeeded, failed }

class AuthFormNotifier extends ChangeNotifier {
  AuthFormNotifier({required this._repository, required this._sessionNotifier});

  final AuthRepository _repository;
  final AuthSessionNotifier _sessionNotifier;

  AuthFormStatus _status = AuthFormStatus.idle;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _isDisposed = false;

  AuthFormStatus get status => _status;
  bool get isSubmitting => _status == AuthFormStatus.submitting;
  bool get isSucceeded => _status == AuthFormStatus.succeeded;
  bool get hasError => _status == AuthFormStatus.failed;
  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => _fieldErrors;

  Future<bool> submitLogin({
    required String? email,
    required String? password,
  }) async {
    if (_isDisposed || _status == AuthFormStatus.submitting) {
      return false;
    }

    final ValidatedAuthCredentials credentials;
    try {
      credentials = AuthInputValidator.validateLogin(
        email: email,
        password: password,
      );
    } on AuthValidationException catch (error) {
      _applyValidationError(error);
      return false;
    }

    return _executeSubmission(
      () => _repository.login(
        email: credentials.email,
        password: credentials.password,
      ),
    );
  }

  Future<bool> submitRegistration({
    required String? email,
    required String? password,
    required String? passwordConfirmation,
  }) async {
    if (_isDisposed || _status == AuthFormStatus.submitting) {
      return false;
    }

    final ValidatedAuthCredentials credentials;
    try {
      credentials = AuthInputValidator.validateRegistration(
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
    } on AuthValidationException catch (error) {
      _applyValidationError(error);
      return false;
    }

    return _executeSubmission(
      () => _repository.register(
        email: credentials.email,
        password: credentials.password,
      ),
    );
  }

  void _applyValidationError(AuthValidationException error) {
    _status = AuthFormStatus.failed;
    _errorMessage = 'Confira os campos destacados antes de continuar.';
    _fieldErrors = error.fields;
    _notifySafely();
  }

  Future<bool> _executeSubmission(Future<AuthUser> Function() operation) async {
    _status = AuthFormStatus.submitting;
    _errorMessage = null;
    _fieldErrors = const {};
    _notifySafely();

    try {
      final user = await operation();
      if (_isDisposed) {
        return false;
      }
      _status = AuthFormStatus.succeeded;
      _sessionNotifier.setAuthenticatedUser(user);
      _notifySafely();
      return true;
    } on AuthRepositoryException catch (error) {
      if (_isDisposed) {
        return false;
      }
      _status = AuthFormStatus.failed;
      _errorMessage = error.message;
      _fieldErrors = Map.unmodifiable(error.fieldErrors);
      _notifySafely();
      return false;
    } on Object {
      if (_isDisposed) {
        return false;
      }
      _status = AuthFormStatus.failed;
      _errorMessage =
          'Não foi possível concluir a autenticação. Tente novamente.';
      _fieldErrors = const {};
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
