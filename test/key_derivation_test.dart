import 'package:flutter_test/flutter_test.dart';

import 'package:password_manager/core/encryption/key_derivation.dart';

void main() {
  group('KeyDerivation', () {
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
