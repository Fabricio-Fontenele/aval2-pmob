import 'package:flutter/foundation.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

enum AuthSessionStatus { restoring, authenticated, unauthenticated, failure }

class AuthSessionNotifier extends ChangeNotifier {
  AuthSessionNotifier({required this._repository});

  final AuthRepository _repository;

  AuthSessionStatus _status = AuthSessionStatus.unauthenticated;
  AuthUser? _user;
  String? _errorMessage;
  bool _isLoggingOut = false;
  bool _isDisposed = false;
  int _sessionEpoch = 0;

  AuthSessionStatus get status => _status;
  AuthUser? get user => _user;
  bool get isAuthenticated =>
      _status == AuthSessionStatus.authenticated && _user != null;
  bool get isRestoring => _status == AuthSessionStatus.restoring;
  bool get isLoggingOut => _isLoggingOut;
  bool get hasFailure => _status == AuthSessionStatus.failure;
  String? get errorMessage => _errorMessage;

  Future<void> restoreSession() async {
    if (_isDisposed || _status == AuthSessionStatus.restoring) {
      return;
    }

    final operationEpoch = ++_sessionEpoch;
    _status = AuthSessionStatus.restoring;
    _errorMessage = null;
    _notifySafely();

    try {
      final restoredUser = await _repository.restoreSession();
      if (_isDisposed || operationEpoch != _sessionEpoch) {
        return;
      }

      if (restoredUser != null) {
        _user = restoredUser;
        _status = AuthSessionStatus.authenticated;
      } else {
        _user = null;
        _status = AuthSessionStatus.unauthenticated;
      }
      _errorMessage = null;
      _notifySafely();
    } on AuthRepositoryException catch (error) {
      if (_isDisposed || operationEpoch != _sessionEpoch) {
        return;
      }

      if (error.isInvalidSession) {
        _user = null;
        _status = AuthSessionStatus.unauthenticated;
        _errorMessage = null;
      } else {
        _status = AuthSessionStatus.failure;
        _errorMessage = error.message;
      }
      _notifySafely();
    } on Object {
      if (_isDisposed || operationEpoch != _sessionEpoch) {
        return;
      }
      _status = AuthSessionStatus.failure;
      _errorMessage =
          'Não foi possível verificar a sessão atual. Tente novamente.';
      _notifySafely();
    }
  }

  void setAuthenticatedUser(AuthUser user) {
    if (_isDisposed) {
      return;
    }
    _sessionEpoch++;
    _user = user;
    _status = AuthSessionStatus.authenticated;
    _errorMessage = null;
    _notifySafely();
  }

  void handleSessionExpired([
    String message = 'Sessão inválida ou expirada. Entre novamente.',
  ]) {
    if (_isDisposed) {
      return;
    }
    _sessionEpoch++;
    _user = null;
    _status = AuthSessionStatus.unauthenticated;
    _errorMessage = message;
    _notifySafely();
  }

  Future<bool> logout() async {
    if (_isDisposed || _isLoggingOut) {
      return false;
    }

    final operationEpoch = ++_sessionEpoch;
    _isLoggingOut = true;
    _errorMessage = null;
    _notifySafely();

    try {
      await _repository.logout();
      if (_isDisposed || operationEpoch != _sessionEpoch) {
        return false;
      }
      _isLoggingOut = false;
      _user = null;
      _status = AuthSessionStatus.unauthenticated;
      _errorMessage = null;
      _notifySafely();
      return true;
    } on AuthRepositoryException catch (error) {
      if (_isDisposed || operationEpoch != _sessionEpoch) {
        return false;
      }
      _isLoggingOut = false;
      if (error.isInvalidSession) {
        _user = null;
        _status = AuthSessionStatus.unauthenticated;
        _errorMessage = null;
        _notifySafely();
        return true;
      }
      _errorMessage = error.message;
      _notifySafely();
      return false;
    } on Object {
      if (_isDisposed || operationEpoch != _sessionEpoch) {
        return false;
      }
      _isLoggingOut = false;
      _errorMessage = 'Não foi possível encerrar a sessão. Tente novamente.';
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
