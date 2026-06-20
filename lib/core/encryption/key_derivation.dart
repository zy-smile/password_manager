import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class KeyDerivation {
  static const int defaultIterations = 150000;
  static const int keyLength = 32;
  static const String _verifierPepper = 'password-vault-auth';

  static Future<String> deriveKey(
    String password,
    String salt, {
    int iterations = defaultIterations,
  }) async {
    final keyBytes = await deriveKeyBytes(
      password,
      salt,
      iterations: iterations,
    );
    return base64Encode(keyBytes);
  }

  static Future<Uint8List> deriveKeyBytes(
    String password,
    String salt, {
    int iterations = defaultIterations,
    int length = keyLength,
  }) async {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final saltBytes = Uint8List.fromList(base64Decode(salt));
    return _pbkdf2(
      passwordBytes: passwordBytes,
      saltBytes: saltBytes,
      iterations: iterations,
      length: length,
    );
  }

  static String buildPasswordVerifier(Uint8List keyBytes) {
    final input = <int>[...keyBytes, ...utf8.encode(_verifierPepper)];
    return base64Encode(sha256.convert(input).bytes);
  }

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static Uint8List _pbkdf2({
    required Uint8List passwordBytes,
    required Uint8List saltBytes,
    required int iterations,
    required int length,
  }) {
    final hmac = Hmac(sha256, passwordBytes);
    const hashLength = 32;
    final blockCount = (length / hashLength).ceil();
    final buffer = BytesBuilder(copy: false);

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final blockIndexBytes = Uint8List.fromList([
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ]);

      var u = Uint8List.fromList(
        hmac.convert([...saltBytes, ...blockIndexBytes]).bytes,
      );
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < hashLength; j++) {
          t[j] = t[j] ^ u[j];
        }
      }

      buffer.add(t);
    }

    return Uint8List.fromList(buffer.takeBytes().sublist(0, length));
  }
}
