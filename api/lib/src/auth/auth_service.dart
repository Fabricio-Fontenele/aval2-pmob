import 'data/password_hasher.dart';
import 'domain/account_store.dart';
import 'domain/auth_credentials.dart';
import 'domain/auth_session.dart';
import 'session_service.dart';

class AuthService {
  final AccountStore _accounts;
  final SessionService _sessions;
  final PasswordHasher _passwords;
  final int _maxConcurrentOperations;
  Future<String>? _dummyHash;
  var _activeOperations = 0;

  AuthService({
    required AccountStore accounts,
    required SessionService sessions,
    PasswordHasher passwords = const PasswordHasher(),
    int maxConcurrentOperations = 2,
  })  : _accounts = accounts,
        _sessions = sessions,
        _passwords = passwords,
        _maxConcurrentOperations = maxConcurrentOperations {
    if (maxConcurrentOperations < 1) {
      throw ArgumentError.value(
          maxConcurrentOperations, 'maxConcurrentOperations');
    }
  }

  Future<IssuedSession> register(AuthCredentials credentials) =>
      _withCapacity(() async {
        final hash = await _passwords.hash(credentials.password);
        final pending = _sessions.prepareToken();
        final id = await _accounts.create(credentials.email, hash, pending);
        return IssuedSession(
          token: pending.token,
          session: AuthSession(userId: id, expiresAt: pending.expiresAt),
        );
      });

  Future<IssuedSession> login(AuthCredentials credentials) =>
      _withCapacity(() async {
        final account = await _accounts.findByEmail(credentials.email);
        // An unknown email still performs an Argon2id verification.
        final hash = account?.passwordHash ??
            await (_dummyHash ??=
                _passwords.hash(_sessions.prepareToken().token));
        final bool verified;
        try {
          verified = await _passwords.verify(credentials.password, hash);
        } on FormatException {
          throw const AccountStorageException();
        } on ArgumentError {
          throw const AccountStorageException();
        }
        if (account == null || !verified) throw const InvalidLoginException();
        return _sessions.issue(account.id);
      });

  Future<T> _withCapacity<T>(Future<T> Function() operation) async {
    if (_activeOperations >= _maxConcurrentOperations) {
      throw const AuthBusyException();
    }
    _activeOperations++;
    try {
      return await operation();
    } finally {
      _activeOperations--;
    }
  }
}

class InvalidLoginException implements Exception {
  const InvalidLoginException();
}

class AuthBusyException implements Exception {
  const AuthBusyException();
}
