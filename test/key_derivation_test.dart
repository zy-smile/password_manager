import 'package:flutter_test/flutter_test.dart';

import 'package:password_manager/core/encryption/key_derivation.dart';

void main() {
  group('KeyDerivation', () {
    test('matches published PBKDF2-HMAC-SHA256 vector', () async {
      final bytes = await KeyDerivation.deriveKeyBytes('password', 'c2FsdA==',
          iterations: 1);
      final hex =
          bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      expect(hex,
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    });
    test('deriveKey is deterministic for the same password and salt', () async {
      const password = 'master-password';
      const salt = 'c2FsdC1mb3ItdGVzdA==';

      final first = await KeyDerivation.deriveKey(password, salt);
      final second = await KeyDerivation.deriveKey(password, salt);

      expect(first, equals(second));
    });

    test('deriveKey changes when salt changes', () async {
      const password = 'master-password';
      const saltA = 'c2FsdC1mb3ItdGVzdC0x';
      const saltB = 'c2FsdC1mb3ItdGVzdC0y';

      final first = await KeyDerivation.deriveKey(password, saltA);
      final second = await KeyDerivation.deriveKey(password, saltB);

      expect(first, isNot(equals(second)));
    });
  });
}
