import 'package:hashlib/hashlib.dart';
import 'package:lost_and_found_api/src/auth/domain/auth_session.dart';
import 'package:lost_and_found_api/src/auth/domain/session_store.dart';
import 'package:lost_and_found_api/src/auth/session_service.dart';
import 'package:test/test.dart';

import '../support/memory_session_store.dart';

void main() {
  late MemorySessionStore store;
  late DateTime now;
  late SessionService service;

  setUp(() {
    store = MemorySessionStore();
    now = DateTime.utc(2026, 10, 31, 12);
    service = SessionService(
      store: store,
      lifetime: const Duration(hours: 24),
      clock: () => now,
    );
  });

  test('issues a 32-byte token and stores only its SHA-256 hash', () async {
    final issued = await service.issue('user-id');

    expect(issued.token, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(issued.session.userId, 'user-id');
    expect(issued.session.expiresAt, now.add(const Duration(hours: 24)));
    expect(store.sessions.keys, [sha256.string(issued.token).hex()]);
    expect(store.sessions.containsKey(issued.token), isFalse);
    expect(await service.authenticate(issued.token), same(issued.session));
  });

  test('each issued token is unique', () async {
    final first = await service.issue('user-id');
    final second = await service.issue('user-id');
    expect(second.token, isNot(first.token));
    expect(store.sessions, hasLength(2));
  });

  test('a new service restores an existing session from the store', () async {
    final issued = await service.issue('user-id');
    final restarted = SessionService(
      store: store,
      lifetime: const Duration(hours: 24),
      clock: () => now,
    );
    final session = await restarted.authenticate(issued.token);
    expect(session.userId, 'user-id');
    expect(session.expiresAt, issued.session.expiresAt);
  });

  test('rejects missing, malformed, unknown and tampered tokens', () async {
    final issued = await service.issue('user-id');
    for (final token in ['', 'invalid', '${issued.token}=', 'A' * 43]) {
      await expectLater(
        service.authenticate(token),
        throwsA(isA<InvalidSessionException>()),
      );
    }
  });

  test('a session expires exactly at its expiration time', () async {
    final issued = await service.issue('user-id');
    now = issued.session.expiresAt.subtract(const Duration(microseconds: 1));
    expect((await service.authenticate(issued.token)).userId, 'user-id');
    now = issued.session.expiresAt;
    await expectLater(
      service.authenticate(issued.token),
      throwsA(isA<InvalidSessionException>()),
    );
  });

  test('logout revokes only the current session and survives service restart',
      () async {
    final first = await service.issue('user-id');
    final second = await service.issue('user-id');
    await service.revoke(first.token);

    final restarted = SessionService(store: store, clock: () => now);
    await expectLater(
      restarted.authenticate(first.token),
      throwsA(isA<InvalidSessionException>()),
    );
    expect((await restarted.authenticate(second.token)).userId, 'user-id');
  });

  test('failed persistence cannot report issuance or logout success', () async {
    store.failure = const SessionStorageException();
    await expectLater(
      service.issue('user-id'),
      throwsA(isA<SessionStorageException>()),
    );

    store.failure = null;
    final issued = await service.issue('user-id');
    store.failure = const SessionStorageException();
    await expectLater(
      service.revoke(issued.token),
      throwsA(isA<SessionStorageException>()),
    );
    store.failure = null;
    expect((await service.authenticate(issued.token)).userId, 'user-id');
    await service.revoke(issued.token);
    await expectLater(
      service.authenticate(issued.token),
      throwsA(isA<InvalidSessionException>()),
    );
  });

  test('refuses nonpositive session lifetimes', () {
    for (final lifetime in [Duration.zero, const Duration(hours: -1)]) {
      expect(
        () => SessionService(store: store, lifetime: lifetime),
        throwsArgumentError,
      );
    }
  });
}
