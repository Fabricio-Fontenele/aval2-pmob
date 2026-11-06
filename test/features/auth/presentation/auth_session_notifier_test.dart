import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';
import 'package:lost_and_found/features/auth/domain/auth_user.dart';
import 'package:lost_and_found/features/auth/presentation/auth_session_notifier.dart';

class _FakeAuthRepository implements AuthRepository {
  int restoreCallCount = 0;
  int logoutCallCount = 0;
  Future<AuthUser?> Function()? onRestoreSession;
  Future<void> Function()? onLogout;

  @override
  Future<AuthUser?> restoreSession() async {
    restoreCallCount++;
    if (onRestoreSession != null) {
      return onRestoreSession!();
    }
    return null;
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    return const AuthUser(id: 'user-login');
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    return const AuthUser(id: 'user-register');
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    if (onLogout != null) {
      await onLogout!();
    }
  }
}

void main() {
  group('AuthSessionNotifier', () {
    late _FakeAuthRepository repository;
    late AuthSessionNotifier notifier;

    setUp(() {
      repository = _FakeAuthRepository();
      notifier = AuthSessionNotifier(repository: repository);
    });

    tearDown(() {
      notifier.dispose();
    });

    test(
      'restores active session when repository returns a valid user',
      () async {
        repository.onRestoreSession = () async =>
            const AuthUser(id: 'user-123');

        await notifier.restoreSession();

        expect(notifier.status, AuthSessionStatus.authenticated);
        expect(notifier.isAuthenticated, isTrue);
        expect(notifier.user, const AuthUser(id: 'user-123'));
        expect(notifier.errorMessage, isNull);
      },
    );

    test('transitions to unauthenticated when no session exists or token is invalid', () async {
      repository.onRestoreSession = () async => null;

      await notifier.restoreSession();

      expect(notifier.status, AuthSessionStatus.unauthenticated);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.user, isNull);
      expect(notifier.errorMessage, isNull);
    });

    test('A15: exposes failure state on temporary network error without claiming expiration and allows retry', () async {
      repository.onRestoreSession = () async {
        throw const AuthRepositoryException.network();
      };

      await notifier.restoreSession();

      expect(notifier.status, AuthSessionStatus.failure);
      expect(notifier.isAuthenticated, isFalse);
      expect(
        notifier.errorMessage,
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      );

      repository.onRestoreSession = () async => const AuthUser(id: 'user-123');
      await notifier.restoreSession();

      expect(notifier.status, AuthSessionStatus.authenticated);
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.user, const AuthUser(id: 'user-123'));
      expect(notifier.errorMessage, isNull);
      expect(repository.restoreCallCount, 2);
    });

    test('A14: logout revokes session on server and clears authenticated user; network failure preserves session and allows retry', () async {
      notifier.setAuthenticatedUser(const AuthUser(id: 'user-123'));
      expect(notifier.isAuthenticated, isTrue);

      repository.onLogout = () async {
        throw const AuthRepositoryException.serviceUnavailable();
      };

      final firstLogout = await notifier.logout();

      expect(firstLogout, isFalse);
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.user, const AuthUser(id: 'user-123'));
      expect(
        notifier.errorMessage,
        'Serviço indisponível no momento. Tente novamente.',
      );

      repository.onLogout = () async {};
      final secondLogout = await notifier.logout();

      expect(secondLogout, isTrue);
      expect(notifier.status, AuthSessionStatus.unauthenticated);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.user, isNull);
      expect(notifier.errorMessage, isNull);
      expect(repository.logoutCallCount, 2);
    });

    test('A14: logout treats 401 invalid_session as definitive token rejection and clears session', () async {
      notifier.setAuthenticatedUser(const AuthUser(id: 'user-123'));
      repository.onLogout = () async {
        throw const AuthRepositoryException.invalidSession();
      };

      final loggedOut = await notifier.logout();

      expect(loggedOut, isTrue);
      expect(notifier.status, AuthSessionStatus.unauthenticated);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.user, isNull);
    });

    test('A17: stale restoreSession response after logout does not restore ended session', () async {
      final restoreCompleter = Completer<AuthUser?>();
      repository.onRestoreSession = () => restoreCompleter.future;

      final restoreFuture = notifier.restoreSession();
      expect(notifier.isRestoring, isTrue);

      notifier.setAuthenticatedUser(const AuthUser(id: 'user-active'));
      await notifier.logout();
      expect(notifier.status, AuthSessionStatus.unauthenticated);

      restoreCompleter.complete(const AuthUser(id: 'stale-user'));
      await restoreFuture;

      expect(notifier.status, AuthSessionStatus.unauthenticated);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.user, isNull);
    });

    test('A17: ignores duplicate concurrent restoreSession and logout calls and does not notify after dispose', () async {
      final completer = Completer<AuthUser?>();
      repository.onRestoreSession = () => completer.future;

      final disposableNotifier = AuthSessionNotifier(repository: repository);
      var notifications = 0;
      disposableNotifier.addListener(() {
        notifications++;
      });

      final firstRestore = disposableNotifier.restoreSession();
      final secondRestore = disposableNotifier.restoreSession();

      expect(repository.restoreCallCount, 1);
      expect(notifications, 1);

      disposableNotifier.dispose();
      completer.complete(const AuthUser(id: 'user-123'));
      await Future.wait([firstRestore, secondRestore]);

      expect(notifications, 1);
    });
  });
}
