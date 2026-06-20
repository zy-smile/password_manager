import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

class AesEncryptionResult {
  const AesEncryptionResult({
    required this.algorithm,
    required this.iv,
    required this.cipherText,
    this.version = 2,
  });

  final String algorithm;
  final String iv;
  final String cipherText;
  final int version;

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'algorithm': algorithm,
      'iv': iv,
      'cipherText': cipherText,
    };
  }

  String toStorageString() => jsonEncode(toMap());
}

class AesService {
  static const String algorithm = 'AES-256-GCM';

  static Future<String> encrypt(String plainText, String key) async {
    final payload = await encryptToPayload(plainText, key);
    return payload.toStorageString();
  }

  static Future<AesEncryptionResult> encryptToPayload(
    String plainText,
    String key, {
    Uint8List? ivBytes,
    String? associatedData,
  }) async {
    final secretKey = _decodeKey(key);
    final iv = ivBytes != null ? IV(ivBytes) : IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(secretKey, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(
      plainText,
      iv: iv,
      associatedData: associatedData == null
          ? null
          : Uint8List.fromList(utf8.encode(associatedData)),
    );

    return AesEncryptionResult(
      algorithm: algorithm,
      iv: base64Encode(iv.bytes),
      cipherText: encrypted.base64,
    );
  }

  static Future<String> decrypt(
    String encryptedText,
    String key, {
    String? associatedData,
  }) async {
    final payload = tryParsePayload(encryptedText);
    if (payload != null) {
      return decryptPayload(
        iv: payload.iv,
        cipherText: payload.cipherText,
        key: key,
        associatedData: associatedData,
      );
    }

    return decryptLegacy(encryptedText, key);
  }

  static Future<String> decryptPayload({
    required String iv,
    required String cipherText,
    required String key,
    String? associatedData,
  }) async {
    final secretKey = _decodeKey(key);
    final encrypter = Encrypter(AES(secretKey, mode: AESMode.gcm));
    return encrypter.decrypt64(
      cipherText,
      iv: IV(base64Decode(iv)),
      associatedData: associatedData == null
          ? null
          : Uint8List.fromList(utf8.encode(associatedData)),
    );
  }

  static Future<String> decryptLegacy(String encryptedText, String key) async {
    final data = base64Decode(encryptedText);
    final iv = IV(data.sublist(0, 16));
    final encryptedBytes = data.sublist(16);
    final secretKey = _legacyKeyFromPassword(key);
    final encrypter = Encrypter(AES(secretKey, mode: AESMode.cbc));
    return encrypter.decrypt(Encrypted(encryptedBytes), iv: iv);
  }

  static AesEncryptionResult? tryParsePayload(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final iv = decoded['iv'];
      final cipherText = decoded['cipherText'];
      if (iv is! String || cipherText is! String) {
        return null;
      }
      return AesEncryptionResult(
        algorithm: decoded['algorithm'] as String? ?? algorithm,
        iv: iv,
        cipherText: cipherText,
        version: decoded['version'] as int? ?? 2,
      );
    } catch (_) {
      return null;
    }
  }

  static Key _decodeKey(String key) {
    return Key(Uint8List.fromList(base64Decode(key)));
  }

  static Key _legacyKeyFromPassword(String password) {
    final keyBytes = Uint8List.fromList(
      List<int>.generate(32, (index) {
        final passwordByte =
            index < password.length ? password.codeUnitAt(index) : 0;
        return passwordByte ^ (index * 17);
      }),
    );
    return Key(keyBytes);
  }
}
