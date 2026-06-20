import 'package:password_manager/core/encryption/aes_service.dart';
import 'package:password_manager/core/encryption/key_derivation.dart';
import 'package:password_manager/core/utils/password_generator.dart';

Future<void> main() async {
  const password = 'master-password';
  const salt = 'c2FsdC1mb3ItdGVzdA==';

  final keyA = await KeyDerivation.deriveKey(password, salt);
  final keyB = await KeyDerivation.deriveKey(password, salt);
  if (keyA != keyB) {
    throw StateError('Key derivation is not deterministic');
  }

  final encrypted = await AesService.encrypt('vault-secret', keyA);
  final decrypted = await AesService.decrypt(encrypted, keyA);
  if (decrypted != 'vault-secret') {
    throw StateError('AES encryption round trip failed');
  }

  final generated = PasswordGenerator.generate(length: 20);
  if (generated.length != 20) {
    throw StateError('Generated password length is incorrect');
  }
  if (!generated.contains(RegExp(r'[A-Z]')) ||
      !generated.contains(RegExp(r'[a-z]')) ||
      !generated.contains(RegExp(r'[0-9]')) ||
      !generated.contains(RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]'))) {
    throw StateError('Generated password is missing required character groups');
  }

  // ignore: avoid_print
  print('Core verification passed.');
}
