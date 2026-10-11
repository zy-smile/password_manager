import 'dart:convert';
import 'dart:math';

import 'aes_service.dart';
import 'key_derivation.dart';

/// Password changes only replace this record; the database data key stays stable.
class MasterKeyRecord {
  const MasterKeyRecord({required this.salt, required this.wrappedKey});

  static const _associatedData = 'personal-assistant-master-key-v3';
  final String salt;
  final String wrappedKey;

  static String generateDataKey() {
    final random = Random.secure();
    return base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  static Future<MasterKeyRecord> create(String password, String dataKey) async {
    final salt = KeyDerivation.generateSalt();
    final wrappingKey = await KeyDerivation.deriveKey(password, salt);
    return wrap(salt: salt, wrappingKey: wrappingKey, dataKey: dataKey);
  }

  static Future<MasterKeyRecord> wrap({
    required String salt,
    required String wrappingKey,
    required String dataKey,
  }) async {
    final payload = await AesService.encryptToPayload(
      dataKey,
      wrappingKey,
      associatedData: _associatedData,
    );
    return MasterKeyRecord(salt: salt, wrappedKey: payload.toStorageString());
  }

  Future<String> unlock(String password) async {
    final wrappingKey = await KeyDerivation.deriveKey(password, salt);
    final key = await AesService.decrypt(
      wrappedKey,
      wrappingKey,
      associatedData: _associatedData,
    );
    if (base64Decode(key).length != 32) {
      throw const FormatException('Invalid data key');
    }
    return key;
  }

  String encode() => jsonEncode({
        'version': 3,
        'kdf': 'PBKDF2-SHA256',
        'iterations': KeyDerivation.defaultIterations,
        'salt': salt,
        'wrappedKey': wrappedKey,
      });

  factory MasterKeyRecord.decode(String value) {
    final map = jsonDecode(value) as Map<String, dynamic>;
    if (map['version'] != 3 ||
        map['kdf'] != 'PBKDF2-SHA256' ||
        map['iterations'] != KeyDerivation.defaultIterations ||
        map['salt'] is! String ||
        map['wrappedKey'] is! String ||
        base64Decode(map['salt'] as String).length != 16 ||
        AesService.tryParsePayload(map['wrappedKey'] as String) == null) {
      throw const FormatException('Invalid master key record');
    }
    return MasterKeyRecord(
        salt: map['salt'] as String, wrappedKey: map['wrappedKey'] as String);
  }
}
