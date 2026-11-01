import 'package:lost_and_found_api/src/auth/domain/auth_credentials.dart';
import 'package:test/test.dart';

void main() {
  AuthCredentials validate(Object? email, Object? password,
      {AuthAction action = AuthAction.register}) {
    return AuthCredentials.validate(
      email: email,
      password: password,
      action: action,
    );
  }

  test('normalizes email while preserving every password character', () {
    final credentials = validate('  Person+demo@EXAMPLE.TEST  ', ' password ');
    expect(credentials.email, 'person+demo@example.test');
    expect(credentials.password, ' password ');
  });

  for (final email in <Object?>[
    null,
    '',
    '   ',
    123,
    'person',
    '@example.test',
    'person@',
    'person@example',
    'person name@example.test',
    'person@@example.test',
    '.person@example.test',
    'person..name@example.test',
    'person@-example.test',
  ]) {
    test('rejects invalid email input: $email', () {
      expect(
        () => validate(email, 'password'),
        throwsA(isA<InvalidAuthInput>().having(
          (error) => error.fields.keys,
          'invalid fields',
          contains('email'),
        )),
      );
    });
  }

  for (final password in <Object?>[null, '', '        ', 123, '1234567']) {
    test('rejects missing, blank, mistyped or short registration passwords',
        () {
      expect(
        () => validate('person@example.test', password),
        throwsA(isA<InvalidAuthInput>().having(
          (error) => error.fields.keys,
          'invalid fields',
          contains('password'),
        )),
      );
    });
  }

  test('counts eight Unicode code points rather than UTF-16 code units', () {
    expect(() => validate('person@example.test', '🔑' * 7),
        throwsA(isA<InvalidAuthInput>()));
    expect(validate('person@example.test', '🔑' * 8).password, '🔑' * 8);
    expect(validate('person@example.test', '12345678').password, '12345678');
  });

  test(
      'login preserves the submitted password without registration length rules',
      () {
    expect(
        validate('person@example.test', ' short ', action: AuthAction.login)
            .password,
        ' short ');
  });

  test('returns immutable errors for all invalid fields', () {
    try {
      validate(null, null);
      fail('Invalid credentials were accepted');
    } on InvalidAuthInput catch (error) {
      expect(error.fields.keys, unorderedEquals(['email', 'password']));
      expect(() => error.fields.clear(), throwsUnsupportedError);
    }
  });
}
