import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_repository.dart';
import 'session_token_store.dart';

class SecureSessionTokenStore implements SessionTokenStore {
  const SecureSessionTokenStore({this._storage = const FlutterSecureStorage()});

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'lost_and_found.session_token';

  @override
  Future<String?> readToken() => _access(() => _storage.read(key: _tokenKey));

  @override
  Future<void> writeToken(String token) =>
      _access(() => _storage.write(key: _tokenKey, value: token));

  @override
  Future<void> deleteToken() => _access(() => _storage.delete(key: _tokenKey));

  Future<T> _access<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException {
      throw const AuthRepositoryException.storage();
    } on MissingPluginException {
      throw const AuthRepositoryException.storage();
    }
  }
}
