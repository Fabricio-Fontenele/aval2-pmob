import 'dart:async';

import 'package:lost_and_found_api/src/auth/auth_service.dart';
import 'package:lost_and_found_api/src/auth/data/password_hasher.dart';
import 'package:lost_and_found_api/src/auth/domain/account_store.dart';
import 'package:lost_and_found_api/src/auth/domain/auth_credentials.dart';
import 'package:lost_and_found_api/src/auth/domain/session_store.dart';
import 'package:lost_and_found_api/src/auth/session_service.dart';
import 'package:test/test.dart';

import '../support/memory_account_store.dart';
import '../support/memory_session_store.dart';

class _PendingHasher extends PasswordHasher {
  Completer<String> pending = Completer<String>();

  @override
  Future<String> hash(String password) => pending.future;
}

void main() {
  late MemorySessionStore sessionStore;
  late MemoryAccountStore accounts;
  late SessionService sessions;
  late AuthService auth;

  AuthCredentials credentials(
          {String email = 'person@example.test',
          String password = ' password '}) =>
      AuthCredentials.validate(
          email: email, password: password, action: AuthAction.register);

  setUp(() {
    sessionStore = MemorySessionStore();
    accounts = MemoryAccountStore(sessionStore);
    sessions = SessionService(store: sessionStore);
    auth = AuthService(accounts: accounts, sessions: sessions);
  });

  test('registration persists an Argon2id hash and returns a usable session',
      () async {
    final issued =
        await auth.register(credentials(email: ' Person@EXAMPLE.TEST '));
    expect((await sessions.authenticate(issued.token)).userId,
        issued.session.userId);
    final account = accounts.accounts['person@example.test'];
    expect(account?.passwordHash, startsWith(r'$argon2id$'));
    expect(
        await const PasswordHasher()
            .verify(' password ', account!.passwordHash),
        isTrue);
    expect(accounts.accounts, hasLength(1));
    expect(sessionStore.sessions, hasLength(1));
  });

  test('a repeated normalized email creates neither account nor extra session',
      () async {
    await auth.register(credentials());
    await expectLater(
        auth.register(credentials(email: ' PERSON@example.test ')),
        throwsA(isA<EmailInUseException>()));
    expect(accounts.accounts, hasLength(1));
    expect(sessionStore.sessions, hasLength(1));
  });

  test(
      'valid credentials issue independent sessions without altering the password',
      () async {
    final registered = await auth.register(credentials());
    final loggedIn = await auth.login(credentials());
    expect(loggedIn.session.userId, registered.session.userId);
    expect(loggedIn.token, isNot(registered.token));
    expect((await sessions.authenticate(loggedIn.token)).userId,
        registered.session.userId);
  });

  test('unknown accounts and wrong passwords are both invalid credentials',
      () async {
    await auth.register(credentials());
    for (final input in [
      credentials(email: 'unknown@example.test'),
      credentials(password: 'password'),
      credentials(password: 'wrong-password'),
    ]) {
      await expectLater(
          auth.login(input), throwsA(isA<InvalidLoginException>()));
    }
    expect(sessionStore.sessions, hasLength(1));
  });

  test('failed registration persists nothing and permits retry', () async {
    accounts.unavailable = true;
    await expectLater(
        auth.register(credentials()), throwsA(isA<AccountStorageException>()));
    expect(accounts.accounts, isEmpty);
    expect(sessionStore.sessions, isEmpty);
    accounts.unavailable = false;
    await auth.register(credentials());
    expect(accounts.accounts, hasLength(1));
  });

  test('a failed session write cannot be presented as a successful login',
      () async {
    await auth.register(credentials());
    sessionStore.failure = const SessionStorageException();
    await expectLater(
        auth.login(credentials()), throwsA(isA<SessionStorageException>()));
    sessionStore.failure = null;
    final retry = await auth.login(credentials());
    expect((await sessions.authenticate(retry.token)).userId, isNotEmpty);
  });

  test('corrupt stored hashes become a safe storage error', () async {
    accounts.accounts['person@example.test'] = const AccountCredentials(
      id: 'user-id',
      passwordHash: 'corrupt-private-hash',
    );
    await expectLater(
        auth.login(credentials()), throwsA(isA<AccountStorageException>()));
    expect(sessionStore.sessions, isEmpty);
  });

  test('bounds pending operations and releases capacity after failure',
      () async {
    final hasher = _PendingHasher();
    auth = AuthService(
        accounts: accounts,
        sessions: sessions,
        passwords: hasher,
        maxConcurrentOperations: 1);
    final first = auth.register(credentials());
    await expectLater(auth.register(credentials(email: 'second@example.test')),
        throwsA(isA<AuthBusyException>()));
    final firstResult = expectLater(first, throwsStateError);
    hasher.pending.completeError(StateError('Hashing failed'));
    await firstResult;
    hasher.pending = Completer<String>();
    final retry = auth.register(credentials());
    hasher.pending.complete('test-password-hash');
    expect((await retry).session.userId, isNotEmpty);
  });
}
