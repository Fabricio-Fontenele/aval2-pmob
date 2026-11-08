import 'auth_user.dart';

enum AuthFailureCode {
  invalidRequest,
  invalidCredentials,
  invalidSession,
  emailInUse,
  tooManyAttempts,
  serviceUnavailable,
  networkError,
  storageError,
}

abstract interface class AuthRepository {
  Future<AuthUser?> restoreSession();

  Future<AuthUser> login({required String email, required String password});

  Future<AuthUser> register({required String email, required String password});

  Future<void> logout();
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(
    this.message, {
    required this.code,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  const AuthRepositoryException.invalidCredentials([
    this.message = 'E-mail ou senha inválidos.',
  ]) : code = AuthFailureCode.invalidCredentials,
       fieldErrors = const {},
       retryAfterSeconds = null;

  const AuthRepositoryException.invalidSession([
    this.message = 'Sessão inválida ou expirada. Entre novamente.',
  ]) : code = AuthFailureCode.invalidSession,
       fieldErrors = const {},
       retryAfterSeconds = null;

  const AuthRepositoryException.emailInUse([
    this.message =
        'Este e-mail já está cadastrado. Tente entrar ou use outro endereço.',
  ]) : code = AuthFailureCode.emailInUse,
       fieldErrors = const {},
       retryAfterSeconds = null;

  const AuthRepositoryException.tooManyAttempts({
    int? retryAfterSeconds,
    String? message,
  }) : code = AuthFailureCode.tooManyAttempts,
       fieldErrors = const {},
       retryAfterSeconds = retryAfterSeconds,
       message =
           message ??
           (retryAfterSeconds != null
               ? 'Muitas tentativas seguidas. Aguarde $retryAfterSeconds segundos e tente novamente.'
               : 'Muitas tentativas seguidas. Aguarde um momento e tente novamente.');

  const AuthRepositoryException.serviceUnavailable([
    this.message = 'Serviço indisponível no momento. Tente novamente.',
  ]) : code = AuthFailureCode.serviceUnavailable,
       fieldErrors = const {},
       retryAfterSeconds = null;

  const AuthRepositoryException.network([
    this.message = 'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
  ]) : code = AuthFailureCode.networkError,
       fieldErrors = const {},
       retryAfterSeconds = null;

  const AuthRepositoryException.storage([
    this.message = 'Não foi possível acessar a sessão salva neste dispositivo. Tente novamente.',
  ]) : code = AuthFailureCode.storageError,
       fieldErrors = const {},
       retryAfterSeconds = null;

  final String message;
  final AuthFailureCode code;
  final Map<String, String> fieldErrors;
  final int? retryAfterSeconds;

  bool get isInvalidSession => code == AuthFailureCode.invalidSession;

  @override
  String toString() => 'AuthRepositoryException($code): $message';
}
