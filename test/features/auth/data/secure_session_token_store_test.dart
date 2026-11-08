import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/features/auth/data/secure_session_token_store.dart';
import 'package:lost_and_found/features/auth/data/session_token_store.dart';
import 'package:lost_and_found/features/auth/domain/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final operation in ['read', 'write', 'delete']) {
    test(
      '$operation translates device storage failures without exposing platform details',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'locked',
            message: 'private platform details',
          ),
        );
        const store = SecureSessionTokenStore();
        final Future<Object?> result = switch (operation) {
          'read' => store.readToken(),
          'write' => store.writeToken('test-session-token'),
          _ => store.deleteToken(),
        };
        await expectLater(
          result,
          throwsA(
            isA<AuthRepositoryException>()
                .having(
                  (error) => error.code,
                  'code',
                  AuthFailureCode.storageError,
                )
                .having(
                  (error) => error.message,
                  'safe feedback',
                  isNot(contains('private platform details')),
                ),
          ),
        );
      },
    );
  }

  test(
    'an unavailable platform reports a recoverable storage failure',
    () async {
      const store = SecureSessionTokenStore();
      await expectLater(
        store.readToken(),
        throwsA(
          isA<AuthRepositoryException>().having(
            (error) => error.code,
            'code',
            AuthFailureCode.storageError,
          ),
        ),
      );
    },
  );

  test('token survives store reconstruction and logout preserves unrelated secure values', () async {
    final secureValues = {'unrelated': 'keep'};
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map<Object?, Object?>;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return secureValues[key];
        case 'write':
          secureValues[key] = args['value'] as String;
          return null;
        case 'delete':
          secureValues.remove(key);
          return null;
        default:
          fail('Unexpected secure storage operation: ${call.method}');
      }
    });
    const SessionTokenStore first = SecureSessionTokenStore();
    expect(await first.readToken(), isNull);
    await first.writeToken('test-session-token');
    const SessionTokenStore restarted = SecureSessionTokenStore();
    expect(await restarted.readToken(), 'test-session-token');
    await restarted.deleteToken();
    expect(await restarted.readToken(), isNull);
    expect(secureValues, {'unrelated': 'keep'});
  });
}
