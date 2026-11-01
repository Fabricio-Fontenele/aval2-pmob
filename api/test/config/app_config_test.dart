import 'package:lost_and_found_api/src/config/app_config.dart';
import 'package:test/test.dart';

void main() {
  test('loads positive auth limits and a normalized trusted proxy allowlist',
      () {
    final config = AppConfig.fromEnvironment({
      'AUTH_REGISTER_LIMIT': '2',
      'AUTH_LOGIN_EMAIL_LIMIT': '3',
      'AUTH_LOGIN_ADDRESS_LIMIT': '10',
      'AUTH_MAX_CONCURRENT': '1',
      'TRUSTED_PROXY_IPS': '127.0.0.1, ::1',
    });
    expect(config.authRegisterLimit, 2);
    expect(config.authLoginEmailLimit, 3);
    expect(config.authLoginAddressLimit, 10);
    expect(config.authMaxConcurrent, 1);
    expect(config.trustedProxyAddresses, {'127.0.0.1', '::1'});
  });

  test('rejects invalid auth limits and proxy addresses', () {
    for (final values in [
      {'AUTH_REGISTER_LIMIT': '0'},
      {'AUTH_LOGIN_EMAIL_LIMIT': '-1'},
      {'AUTH_LOGIN_ADDRESS_LIMIT': 'invalid'},
      {'AUTH_MAX_CONCURRENT': '0'},
      {'TRUSTED_PROXY_IPS': '*'},
      {'SESSION_TTL_HOURS': '0'},
    ]) {
      expect(() => AppConfig.fromEnvironment(values), throwsFormatException);
    }
  });

  group('AppConfig', () {
    test('loads default values when environment is empty', () {
      final config = AppConfig.fromEnvironment({});

      expect(config.port, equals(8080));
      expect(config.host, equals('0.0.0.0'));
      expect(config.environment, equals('development'));
      expect(config.isProduction, isFalse);
      expect(config.databaseUrl, isNull);
      expect(config.sessionTtlHours, equals(24));
    });

    test('correctly parses environment variables', () {
      final env = {
        'PORT': '3000',
        'HOST': '127.0.0.1',
        'ENVIRONMENT': 'production',
        'DATABASE_URL': 'postgres://user:secret@localhost:5432/dbname',
        'SESSION_TTL_HOURS': '48',
      };

      final config = AppConfig.fromEnvironment(env);

      expect(config.port, equals(3000));
      expect(config.host, equals('127.0.0.1'));
      expect(config.environment, equals('production'));
      expect(config.isProduction, isTrue);
      expect(config.databaseUrl,
          equals('postgres://user:secret@localhost:5432/dbname'));
      expect(config.sessionTtlHours, equals(48));
    });

    test('falls back to default port when PORT is invalid', () {
      final config = AppConfig.fromEnvironment({'PORT': 'invalid'});
      expect(config.port, equals(8080));
    });

    test('falls back to default session TTL when SESSION_TTL_HOURS is invalid',
        () {
      final config =
          AppConfig.fromEnvironment({'SESSION_TTL_HOURS': 'invalid'});
      expect(config.sessionTtlHours, equals(24));
    });
  });
}
