import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/app/app_theme.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';
import 'package:lost_and_found/features/auth/domain/auth_user.dart';
import 'package:lost_and_found/features/auth/presentation/auth_session_notifier.dart';
import 'package:lost_and_found/features/auth/presentation/login_screen.dart';
import 'package:lost_and_found/features/auth/presentation/register_screen.dart';

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
  group('LoginScreen and RegisterScreen', () {
    late _FakeAuthRepository repository;
    late AuthSessionNotifier sessionNotifier;

    setUp(() {
      repository = _FakeAuthRepository();
      sessionNotifier = AuthSessionNotifier(repository: repository);
    });

    tearDown(() {
      sessionNotifier.dispose();
    });

    testWidgets(
      'AU02 & A14: LoginScreen validates blank fields, displays invalid credentials error, allows retry, and pops with true on success',
      (tester) async {
        bool? loginResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      loginResult = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => LoginScreen(
                            repository: repository,
                            sessionNotifier: sessionNotifier,
                          ),
                        ),
                      );
                    },
                    child: const Text('Ir para login'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Ir para login'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(LoginScreen.submitButtonKey));
        await tester.pump();

        expect(find.text('Informe um e-mail válido.'), findsOneWidget);
        expect(find.text('Informe a senha.'), findsOneWidget);
        expect(repository.loginCallCount, 0);

        repository.onLogin = (_, _) async {
          throw const AuthRepositoryException.invalidCredentials();
        };

        await tester.enterText(
          find.byKey(LoginScreen.emailFieldKey),
          '  Aluno@EXAMPLE.TEST  ',
        );
        await tester.enterText(
          find.byKey(LoginScreen.passwordFieldKey),
          ' senha errada ',
        );
        await tester.tap(find.byKey(LoginScreen.submitButtonKey));
        await tester.pumpAndSettle();

        expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
        expect(sessionNotifier.isAuthenticated, isFalse);

        repository.onLogin = (_, _) async => const AuthUser(id: 'user-42');

        await tester.tap(find.byKey(LoginScreen.retryButtonKey));
        await tester.pumpAndSettle();

        expect(loginResult, isTrue);
        expect(sessionNotifier.isAuthenticated, isTrue);
        expect(sessionNotifier.user, const AuthUser(id: 'user-42'));
        expect(repository.loginCallCount, 2);
        expect(repository.lastEmail, 'aluno@example.test');
        expect(repository.lastPassword, ' senha errada ');
      },
    );

    testWidgets(
      'AU01 & A13: RegisterScreen validates email, 8-char password, and confirmation, handles email_in_use, and authenticates on success',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: RegisterScreen(
              repository: repository,
              sessionNotifier: sessionNotifier,
            ),
          ),
        );

        await tester.enterText(
          find.byKey(RegisterScreen.emailFieldKey),
          'email-invalido',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.passwordFieldKey),
          '1234567',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.passwordConfirmationFieldKey),
          'diferente',
        );

        await tester.tap(find.byKey(RegisterScreen.submitButtonKey));
        await tester.pump();

        expect(find.text('Informe um e-mail válido.'), findsOneWidget);
        expect(
          find.text('A senha deve ter pelo menos 8 caracteres.'),
          findsOneWidget,
        );
        expect(
          find.text('A confirmação de senha não confere.'),
          findsOneWidget,
        );
        expect(repository.registerCallCount, 0);

        repository.onRegister = (_, _) async {
          throw const AuthRepositoryException.emailInUse();
        };

        await tester.enterText(
          find.byKey(RegisterScreen.emailFieldKey),
          '  Novo+1@EXAMPLE.TEST ',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.passwordFieldKey),
          ' senha 123 ',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.passwordConfirmationFieldKey),
          ' senha 123 ',
        );

        await tester.tap(find.byKey(RegisterScreen.submitButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Este e-mail já está cadastrado. Tente entrar ou use outro endereço.',
          ),
          findsOneWidget,
        );
        expect(sessionNotifier.isAuthenticated, isFalse);

        repository.onRegister = (_, _) async => const AuthUser(id: 'user-99');

        await tester.tap(find.byKey(RegisterScreen.retryButtonKey));
        await tester.pumpAndSettle();

        expect(sessionNotifier.isAuthenticated, isTrue);
        expect(sessionNotifier.user, const AuthUser(id: 'user-99'));
        expect(repository.registerCallCount, 2);
        expect(repository.lastEmail, 'novo+1@example.test');
        expect(repository.lastPassword, ' senha 123 ');
      },
    );

    testWidgets(
      'A11 & A17: prevents duplicate taps while submitting, adapts to small screens with scaled text, and survives disposal while pending',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final completer = Completer<AuthUser>();
        repository.onRegister = (_, _) => completer.future;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.light,
              home: RegisterScreen(
                repository: repository,
                sessionNotifier: sessionNotifier,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(RegisterScreen.emailFieldKey),
          'pessoa@example.test',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.passwordFieldKey),
          '12345678',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.passwordConfirmationFieldKey),
          '12345678',
        );

        await tester.ensureVisible(find.byKey(RegisterScreen.submitButtonKey));
        await tester.tap(find.byKey(RegisterScreen.submitButtonKey));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Criando conta...'), findsOneWidget);

        await tester.tap(
          find.byKey(RegisterScreen.submitButtonKey),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(repository.registerCallCount, 1);

        // Dispose while operation is pending.
        await tester.pumpWidget(const SizedBox.shrink());
        completer.complete(const AuthUser(id: 'late-user'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(sessionNotifier.isAuthenticated, isFalse);
      },
    );

    testWidgets(
      'A11: LoginScreen adapts to small screens, scaled text, open keyboard, displays server field errors, supports back navigation from RegisterScreen, and survives disposal while pending',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              viewInsets: EdgeInsets.only(bottom: 160),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.light,
              home: LoginScreen(
                repository: repository,
                sessionNotifier: sessionNotifier,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Navigate to RegisterScreen and return to LoginScreen without errors.
        await tester.ensureVisible(
          find.byKey(LoginScreen.createAccountButtonKey),
        );
        await tester.tap(find.byKey(LoginScreen.createAccountButtonKey));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(RegisterScreen.alreadyHaveAccountButtonKey),
        );
        await tester.tap(
          find.byKey(RegisterScreen.alreadyHaveAccountButtonKey),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);

        repository.onLogin = (_, _) async {
          throw const AuthRepositoryException(
            'Não foi possível validar os dados informados.',
            code: AuthFailureCode.invalidRequest,
            fieldErrors: {'email': 'E-mail rejeitado pelo servidor.'},
          );
        };

        await tester.ensureVisible(find.byKey(LoginScreen.emailFieldKey));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(LoginScreen.emailFieldKey),
          'pessoa@example.test',
        );
        await tester.ensureVisible(find.byKey(LoginScreen.passwordFieldKey));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(LoginScreen.passwordFieldKey),
          '12345678',
        );
        await tester.ensureVisible(find.byKey(LoginScreen.submitButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LoginScreen.submitButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.text('Não foi possível validar os dados informados.'),
          findsOneWidget,
        );
        expect(find.text('E-mail rejeitado pelo servidor.'), findsOneWidget);

        final completer = Completer<AuthUser>();
        repository.onLogin = (_, _) => completer.future;

        await tester.ensureVisible(find.byKey(LoginScreen.retryButtonKey));
        await tester.tap(find.byKey(LoginScreen.retryButtonKey));
        await tester.pump();

        expect(find.text('Entrando...'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        completer.complete(const AuthUser(id: 'disposed-login-user'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(sessionNotifier.isAuthenticated, isFalse);
      },
    );
  });
}
