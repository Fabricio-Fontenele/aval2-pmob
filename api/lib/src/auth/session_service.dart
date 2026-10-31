import 'dart:convert';
import 'dart:math';

import 'package:hashlib/hashlib.dart';

import 'domain/auth_session.dart';
import 'domain/session_store.dart';

class SessionService {
  final SessionStore _store;
  final Duration _lifetime;
  final DateTime Function() _clock;
  final Random _random = Random.secure();
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  SessionService({
    required SessionStore store,
    Duration lifetime = const Duration(hours: 24),
    DateTime Function()? clock,
  })  : _store = store,
        _lifetime = lifetime,
        _clock = clock ?? DateTime.now {
    if (lifetime <= Duration.zero) {
      throw ArgumentError.value(lifetime, 'lifetime', 'Must be positive');
    }
  }

  Future<IssuedSession> issue(String userId) async {
    final token = base64Url
        .encode(List<int>.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    final session = AuthSession(
      userId: userId,
      expiresAt: _clock().toUtc().add(_lifetime),
    );
    await _store.create(_hashToken(token), session);
    return IssuedSession(token: token, session: session);
  }

  Future<AuthSession> authenticate(String token) async {
    final session = await _store.find(_hashToken(token));
    if (session == null ||
        session.revokedAt != null ||
        !session.expiresAt.isAfter(_clock().toUtc())) {
      throw const InvalidSessionException();
    }
    return session;
  }

  Future<void> revoke(String token) async {
    final revoked = await _store.revoke(_hashToken(token), _clock().toUtc());
    if (!revoked) throw const InvalidSessionException();
  }

  String _hashToken(String token) {
    if (!_tokenPattern.hasMatch(token)) throw const InvalidSessionException();
    return sha256.string(token).hex();
  }
}
