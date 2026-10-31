import 'dart:convert';
import 'dart:io';

import 'package:lost_and_found_api/src/auth/data/password_hasher.dart';

Future<void> main() async {
  const hasher = PasswordHasher();
  const password = 'demonstration-benchmark-password';
  final warmup = await hasher.hash(password);
  await hasher.verify(password, warmup);

  final hashTimes = <int>[];
  final verifyTimes = <int>[];
  for (var index = 0; index < 3; index++) {
    final stopwatch = Stopwatch()..start();
    final hash = await hasher.hash(password);
    hashTimes.add(stopwatch.elapsedMilliseconds);
    stopwatch.reset();
    final verified = await hasher.verify(password, hash);
    verifyTimes.add(stopwatch.elapsedMilliseconds);
    if (!verified) throw StateError('Password verification failed');
  }

  print(jsonEncode({
    'runtime': Platform.version.split(' ').first,
    'platform': Platform.operatingSystem,
    'argon2id': {'memoryKiB': 19456, 'iterations': 2, 'parallelism': 1},
    'hashMilliseconds': hashTimes,
    'verifyMilliseconds': verifyTimes,
    'processPeakRssMiB': ProcessInfo.maxRss / (1024 * 1024),
  }));
}
