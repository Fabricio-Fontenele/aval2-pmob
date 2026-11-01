import 'package:lost_and_found_api/src/auth/auth_attempt_limiter.dart';
import 'package:lost_and_found_api/src/auth/domain/auth_credentials.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late AuthAttemptLimiter limiter;
  setUp(() {
    now = DateTime.utc(2026, 11, 1, 12);
    limiter = AuthAttemptLimiter(clock: () => now);
  });

  test('allows five registration attempts per address in an hour', () {
    for (var i = 0; i < 5; i++) {
      limiter.recordAddressAttempt(AuthAction.register, 'address-a');
    }
    expect(
        () => limiter.recordAddressAttempt(AuthAction.register, 'address-a'),
        throwsA(isA<AuthAttemptLimitException>()
            .having((error) => error.retryAfterSeconds, 'retry after', 3600)));
    limiter.recordAddressAttempt(AuthAction.register, 'address-b');
    limiter.recordAddressAttempt(AuthAction.login, 'address-a');
  });

  test(
      'denied attempts do not extend the window and reset exactly at expiration',
      () {
    for (var i = 0; i < 5; i++) {
      limiter.recordLoginEmailAttempt('person@example.test');
    }
    now = now.add(const Duration(minutes: 14, seconds: 59, milliseconds: 500));
    expect(
        () => limiter.recordLoginEmailAttempt('person@example.test'),
        throwsA(isA<AuthAttemptLimitException>().having(
            (error) => error.retryAfterSeconds, 'rounded retry after', 1)));
    now = now.add(const Duration(milliseconds: 500));
    limiter.recordLoginEmailAttempt('person@example.test');
  });

  test('enforces the address limit independently of login email', () {
    for (var i = 0; i < 20; i++) {
      limiter.recordAddressAttempt(AuthAction.login, 'address-a');
    }
    expect(() => limiter.recordAddressAttempt(AuthAction.login, 'address-a'),
        throwsA(isA<AuthAttemptLimitException>()));
    limiter.recordAddressAttempt(AuthAction.login, 'address-b');
  });

  test('does not evict active buckets when memory capacity is exhausted', () {
    limiter = AuthAttemptLimiter(maxEntries: 1, clock: () => now);
    limiter.recordAddressAttempt(AuthAction.register, 'address-a');
    expect(() => limiter.recordAddressAttempt(AuthAction.register, 'address-b'),
        throwsA(isA<AuthAttemptLimitException>()));
    now = now.add(const Duration(hours: 1));
    limiter.recordAddressAttempt(AuthAction.register, 'address-b');
  });

  test('supports configured attempt thresholds', () {
    limiter = AuthAttemptLimiter(
        registerLimit: 1,
        loginEmailLimit: 1,
        loginAddressLimit: 1,
        clock: () => now);
    limiter.recordAddressAttempt(AuthAction.register, 'address');
    limiter.recordAddressAttempt(AuthAction.login, 'address');
    limiter.recordLoginEmailAttempt('person@example.test');
    expect(() => limiter.recordAddressAttempt(AuthAction.register, 'address'),
        throwsA(isA<AuthAttemptLimitException>()));
    expect(() => limiter.recordAddressAttempt(AuthAction.login, 'address'),
        throwsA(isA<AuthAttemptLimitException>()));
    expect(() => limiter.recordLoginEmailAttempt('person@example.test'),
        throwsA(isA<AuthAttemptLimitException>()));
  });
}
