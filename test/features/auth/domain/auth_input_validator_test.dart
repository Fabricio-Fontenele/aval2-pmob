import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/features/auth/domain/auth_input_validator.dart';

void main() {
  group('AuthInputValidator.validateEmail and normalizeEmail', () {
    test('normalizes email by trimming whitespace and lowercasing', () {
      expect(
        AuthInputValidator.normalizeEmail('  Person+Demo@EXAMPLE.TEST  '),
        'person+demo@example.test',
      );
      expect(
        AuthInputValidator.validateEmail('  Person+Demo@EXAMPLE.TEST  '),
        isNull,
      );
    });

    for (final invalidEmail in <String?>[
      null,
      '',
      '   ',
      'person',
      '@example.test',
      'person@',
      'person@example',
      'person name@example.test',
      'person@@example.test',
      '.person@example.test',
      'person.@example.test',
      'person..name@example.test',
      'person@-example.test',
      'person@example-.test',
      'person@example..test',
    ]) {
      test('rejects invalid email input: "$invalidEmail"', () {
        expect(
          AuthInputValidator.validateEmail(invalidEmail),
          'Informe um e-mail válido.',
        );
      });
    }

    test(
      'enforces local-part, domain-label, and total email length limits',
      () {
        final local64 = 'a' * 64;
        final local65 = 'a' * 65;
        final label63 = 'b' * 63;
        final label64 = 'b' * 64;

        expect(
          AuthInputValidator.validateEmail('$local64@example.test'),
          isNull,
        );
        expect(
          AuthInputValidator.validateEmail('$local65@example.test'),
          'Informe um e-mail válido.',
        );
        expect(AuthInputValidator.validateEmail('user@$label63.test'), isNull);
        expect(
          AuthInputValidator.validateEmail('user@$label64.test'),
          'Informe um e-mail válido.',
        );
      },
    );
  });

  group('AuthInputValidator password and confirmation validators', () {
    test('rejects null, empty, and whitespace-only passwords', () {
      for (final blank in <String?>[null, '', '        ', '\t\n']) {
        expect(
          AuthInputValidator.validateLoginPassword(blank),
          'Informe a senha.',
        );
        expect(
          AuthInputValidator.validateRegistrationPassword(blank),
          'Informe a senha.',
        );
      }
    });

    test('counts eight Unicode code points for registration without trimming spaces', () {
      expect(
        AuthInputValidator.validateRegistrationPassword('1234567'),
        'A senha deve ter pelo menos 8 caracteres.',
      );
      expect(
        AuthInputValidator.validateRegistrationPassword('🔑' * 7),
        'A senha deve ter pelo menos 8 caracteres.',
      );
      expect(
        AuthInputValidator.validateRegistrationPassword('12345678'),
        isNull,
      );
      expect(AuthInputValidator.validateRegistrationPassword('🔑' * 8), isNull);
      expect(
        AuthInputValidator.validateRegistrationPassword(' pass 7 '),
        isNull,
      );
    });

    test(
      'accepts non-blank login passwords shorter than eight code points',
      () {
        expect(AuthInputValidator.validateLoginPassword(' short '), isNull);
      },
    );

    test('requires non-blank confirmation matching the exact password including spaces', () {
      expect(
        AuthInputValidator.validatePasswordConfirmation(
          password: ' password123 ',
          confirmation: null,
        ),
        'Confirme a senha.',
      );
      expect(
        AuthInputValidator.validatePasswordConfirmation(
          password: ' password123 ',
          confirmation: '   ',
        ),
        'Confirme a senha.',
      );
      expect(
        AuthInputValidator.validatePasswordConfirmation(
          password: ' password123 ',
          confirmation: 'password123',
        ),
        'A confirmação de senha não confere.',
      );
      expect(
        AuthInputValidator.validatePasswordConfirmation(
          password: ' password123 ',
          confirmation: ' password123 ',
        ),
        isNull,
      );
    });
  });

  group('AuthInputValidator.validateLogin and validateRegistration', () {
    test(
      'validateLogin returns normalized email and preserves original password',
      () {
        final credentials = AuthInputValidator.validateLogin(
          email: '  Student@UESPI.EDU.BR ',
          password: ' short ',
        );

        expect(credentials.email, 'student@uespi.edu.br');
        expect(credentials.password, ' short ');
      },
    );

    test(
      'validateRegistration returns normalized email and untrimmed password',
      () {
        final credentials = AuthInputValidator.validateRegistration(
          email: '  Person+demo@EXAMPLE.TEST  ',
          password: ' password ',
          passwordConfirmation: ' password ',
        );

        expect(credentials.email, 'person+demo@example.test');
        expect(credentials.password, ' password ');
      },
    );

    test('validateRegistration throws immutable AuthValidationException for invalid fields', () {
      try {
        AuthInputValidator.validateRegistration(
          email: 'invalid-email',
          password: '1234567',
          passwordConfirmation: 'different',
        );
        fail('Expected AuthValidationException');
      } on AuthValidationException catch (error) {
        expect(error.emailError, 'Informe um e-mail válido.');
        expect(
          error.passwordError,
          'A senha deve ter pelo menos 8 caracteres.',
        );
        expect(
          error.passwordConfirmationError,
          'A confirmação de senha não confere.',
        );
        expect(() => error.fields.clear(), throwsUnsupportedError);
      }
    });
  });
}
