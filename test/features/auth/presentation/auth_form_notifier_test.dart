import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';
import 'package:lost_and_found/features/auth/domain/auth_user.dart';
import 'package:lost_and_found/features/auth/presentation/auth_form_notifier.dart';
import 'package:lost_and_found/features/auth/presentation/auth_session_notifier.dart';

class _FakeAuthRepository implements AuthRepository {
  int loginCallCount = 0;
  int registerCallCount = 0;
  String? lastEmail;
  String? lastPassword;
  Future<AuthUser> Function(String email, String password)? onLogin;
  Future<AuthUser> Function(String email, String password)? onRegister;

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    loginCallCount++;
    lastEmail = email;
    lastPassword = password;
    if (onLogin != null) {
      return onLogin!(email, password);
    }
    return const AuthUser(id: 'user-login');
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    registerCallCount++;
    lastEmail = email;
    lastPassword = password;
    if (onRegister != null) {
      return onRegister!(email, password);
    }
    return const AuthUser(id: 'user-register');
  }

  @override
  Future<void> logout() async {}
}

void main() {
  group('AuthFormNotifier', () {
    late _FakeAuthRepository repository;
    late AuthSessionNotifier sessionNotifier;
    late AuthFormNotifier formNotifier;

    setUp(() {
      repository = _FakeAuthRepository();
      sessionNotifier = AuthSessionNotifier(repository: repository);
      formNotifier = AuthFormNotifier(
        repository: repository,
        sessionNotifier: sessionNotifier,
      );
    });

    tearDown(() {
      formNotifier.dispose();
      sessionNotifier.dispose();
    });

    test('A13: rejects invalid registration input locally without calling repository or notifying session', () async {
      var sessionNotifications = 0;
      sessionNotifier.addListener(() {
        sessionNotifications++;
      });

      final succeeded = await formNotifier.submitRegistration(
        email: 'invalid',
        password: 'short',
        passwordConfirmation: 'different',
      );

      expect(succeeded, isFalse);
      expect(repository.registerCallCount, 0);
      expect(sessionNotifications, 0);
      expect(sessionNotifier.isAuthenticated, isFalse);
      expect(formNotifier.hasError, isTrue);
      expect(formNotifier.fieldErrors['email'], 'Informe um e-mail válido.');
      expect(
        formNotifier.fieldErrors['password'],
        'A senha deve ter pelo menos 8 caracteres.',
      );
      expect(
        formNotifier.fieldErrors['passwordConfirmation'],
        'A confirmação de senha não confere.',
      );
    });

    test('A13 & A14: normalizes email, preserves password spaces, and updates session on registration and login', () async {
      final registered = await formNotifier.submitRegistration(
        email: '  Student+1@EXAMPLE.TEST  ',
        password: ' password 123 ',
        passwordConfirmation: ' password 123 ',
      );

      expect(registered, isTrue);
      expect(repository.registerCallCount, 1);
      expect(repository.lastEmail, 'student+1@example.test');
      expect(repository.lastPassword, ' password 123 ');
      expect(sessionNotifier.isAuthenticated, isTrue);
      expect(sessionNotifier.user, const AuthUser(id: 'user-register'));

      final loggedIn = await formNotifier.submitLogin(
        email: '  Student+1@EXAMPLE.TEST ',
        password: ' short ',
      );

      expect(loggedIn, isTrue);
      expect(repository.loginCallCount, 1);
      expect(repository.lastEmail, 'student+1@example.test');
      expect(repository.lastPassword, ' short ');
      expect(sessionNotifier.user, const AuthUser(id: 'user-login'));
    });

    test('A13 & A14: surfaces email_in_use, invalid_credentials, and too_many_attempts errors without authenticating', () async {
      repository.onRegister = (_, _) async {
        throw const AuthRepositoryException.emailInUse();
      };

      final duplicateAttempt = await formNotifier.submitRegistration(
        email: 'user@example.test',
        password: 'password123',
        passwordConfirmation: 'password123',
      );

      expect(duplicateAttempt, isFalse);
      expect(sessionNotifier.isAuthenticated, isFalse);
      expect(
        formNotifier.errorMessage,
        'Este e-mail já está cadastrado. Tente entrar ou use outro endereço.',
      );

      repository.onLogin = (_, _) async {
        throw const AuthRepositoryException.invalidCredentials();
      };

      final wrongCredentials = await formNotifier.submitLogin(
        email: 'user@example.test',
        password: 'wrong-password',
      );

      expect(wrongCredentials, isFalse);
      expect(sessionNotifier.isAuthenticated, isFalse);
      expect(formNotifier.errorMessage, 'E-mail ou senha inválidos.');

      repository.onLogin = (_, _) async {
        throw const AuthRepositoryException.tooManyAttempts(
          retryAfterSeconds: 30,
        );
      };

      final rateLimited = await formNotifier.submitLogin(
        email: 'user@example.test',
        password: 'wrong-password',
      );

      expect(rateLimited, isFalse);
      expect(
        formNotifier.errorMessage,
        'Muitas tentativas seguidas. Aguarde 30 segundos e tente novamente.',
      );
    });

    test('A17: prevents duplicate concurrent submissions and does not update session if disposed while pending', () async {
      final completer = Completer<AuthUser>();
      repository.onLogin = (_, _) => completer.future;

      final localForm = AuthFormNotifier(
        repository: repository,
        sessionNotifier: sessionNotifier,
      );

      final firstAttempt = localForm.submitLogin(
        email: 'user@example.test',
        password: 'password123',
      );
      final secondAttempt = localForm.submitLogin(
        email: 'user@example.test',
        password: 'password123',
      );

      expect(await secondAttempt, isFalse);
      expect(repository.loginCallCount, 1);

      localForm.dispose();
      completer.complete(const AuthUser(id: 'user-late'));
      expect(await firstAttempt, isFalse);
      expect(sessionNotifier.isAuthenticated, isFalse);
    });
  });
}
