import 'package:flutter_test/flutter_test.dart';

import 'package:password_manager/core/encryption/aes_service.dart';
import 'package:password_manager/core/encryption/key_derivation.dart';

void main() {
  group('AesService', () {
    test('encrypt and decrypt round trip succeeds', () async {
      final key = await KeyDerivation.deriveKey(
        'master-password',
        'c2FsdC1mb3ItdGVzdA==',
      );

      final encrypted = await AesService.encrypt('hello-vault', key);
      final decrypted = await AesService.decrypt(encrypted, key);

      expect(decrypted, equals('hello-vault'));
      expect(AesService.tryParsePayload(encrypted), isNotNull);
    });
  });
}
