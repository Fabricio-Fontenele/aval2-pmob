import 'domain/auth_credentials.dart';

class AuthAttemptLimiter {
  final int _registerLimit;
  final int _loginEmailLimit;
  final int _loginAddressLimit;
  final int _maxEntries;
  final DateTime Function() _clock;
  final _buckets = <String, _AttemptBucket>{};

  AuthAttemptLimiter({
    int registerLimit = 5,
    int loginEmailLimit = 5,
    int loginAddressLimit = 20,
    int maxEntries = 10000,
    DateTime Function()? clock,
  })  : _registerLimit = registerLimit,
        _loginEmailLimit = loginEmailLimit,
        _loginAddressLimit = loginAddressLimit,
        _maxEntries = maxEntries,
        _clock = clock ?? DateTime.now {
    if ([registerLimit, loginEmailLimit, loginAddressLimit, maxEntries]
        .any((value) => value < 1)) {
      throw ArgumentError(
          'Attempt limits and memory capacity must be positive');
    }
  }

  void recordAddressAttempt(AuthAction action, String address) {
    if (action == AuthAction.register) {
      _record('register:$address', _registerLimit, const Duration(hours: 1));
      return;
    }
    _record('login:$address', _loginAddressLimit, const Duration(minutes: 15));
  }

  void recordLoginEmailAttempt(String normalizedEmail) {
    _record('email:$normalizedEmail', _loginEmailLimit,
        const Duration(minutes: 15));
  }

  void _record(String key, int limit, Duration window) {
    final now = _clock().toUtc();
    var bucket = _buckets[key];
    if (bucket == null || !bucket.expiresAt.isAfter(now)) {
      if (bucket == null && _buckets.length >= _maxEntries) {
        _buckets.removeWhere((_, value) => !value.expiresAt.isAfter(now));
        if (_buckets.length >= _maxEntries) {
          final earliest = _buckets.values
              .map((value) => value.expiresAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          throw AuthAttemptLimitException(_retrySeconds(earliest, now));
        }
      }
      bucket = _AttemptBucket(now.add(window));
      _buckets[key] = bucket;
    }
    if (bucket.count >= limit) {
      throw AuthAttemptLimitException(_retrySeconds(bucket.expiresAt, now));
    }
    bucket.count++;
  }

  int _retrySeconds(DateTime expiresAt, DateTime now) {
    return (expiresAt.difference(now).inMicroseconds +
            Duration.microsecondsPerSecond -
            1) ~/
        Duration.microsecondsPerSecond;
  }
}

class _AttemptBucket {
  final DateTime expiresAt;
  var count = 0;

  _AttemptBucket(this.expiresAt);
}

class AuthAttemptLimitException implements Exception {
  final int retryAfterSeconds;

  const AuthAttemptLimitException(this.retryAfterSeconds);
}
