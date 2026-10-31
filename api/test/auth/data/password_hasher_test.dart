import 'package:lost_and_found_api/src/auth/data/password_hasher.dart';
import 'package:test/test.dart';

void main() {
  const hasher = PasswordHasher();

  test('stores Argon2id parameters and a unique salt in each hash', () async {
    final first = await hasher.hash(' example-password ');
    final second = await hasher.hash(' example-password ');

    expect(first, startsWith(r'$argon2id$v=19$m=19456,t=2,p=1$'));
    expect(first, isNot(contains('example-password')));
    expect(first, isNot(second));
    expect(await hasher.verify(' example-password ', first), isTrue);
    expect(await hasher.verify('example-password', first), isFalse);
    expect(await hasher.verify('wrong-password', first), isFalse);
  });
}
