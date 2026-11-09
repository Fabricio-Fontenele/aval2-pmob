import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:hashlib/codecs.dart';
import 'package:hashlib/hashlib.dart';

class PasswordHasher {
  const PasswordHasher();

  Future<String> hash(String password) {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    return Isolate.run(() => argon2id(
          utf8.encode(password),
          salt,
          security: Argon2Security.owasp2,
          hashLength: 32,
        ).encoded());
  }

  Future<bool> verify(String password, String encodedHash) {
    return Isolate.run(() {
      final encoded = fromCrypt(encodedHash);
      final expected = encoded.hashBytes();
      final algorithm = Argon2.fromEncoded(encoded);
      if (expected == null || algorithm.type != Argon2Type.argon2id) {
        throw const FormatException('Expected an Argon2id password hash');
      }
      return algorithm.convert(utf8.encode(password)).isEqual(expected);
    });
  }
}
