import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/core/encryption/aes_service.dart';
import 'package:password_manager/core/encryption/key_derivation.dart';
import 'package:password_manager/features/vault/backup/backup_service.dart';
import 'package:password_manager/features/vault/domain/entities/vault_account.dart';

void main() {
  late Directory directory;
  late BackupService service;
  final account = VaultAccount(
      id: '1',
      title: 'Example',
      website: 'https://example.com',
      username: 'private-user',
      password: 'secret-password',
      note: 'private-note',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  setUp(() async {
    directory = await Directory.systemTemp
        .createTemp('personal-assistant-backup-test-');
    service = BackupService(directory: directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('backup restores on another device independently of its vault key',
      () async {
    final result = await service
        .exportBackup(accounts: [account], backupPassword: 'backup-password1');
    final text = await File(result.file.path).readAsString();
    expect(text.contains(account.password), isFalse);
    expect(text.contains(account.username), isFalse);
    final otherDevice = BackupService(directory: directory);
    final restored = await otherDevice.importBackup(
        filePath: result.file.path,
        backupPassword: 'backup-password1',
        encryptionKey: 'unrelated-device-key');
    expect(restored.single.toBackupMap(), account.toBackupMap());
  });

  test('wrong password and ciphertext tampering are rejected', () async {
    final result = await service
        .exportBackup(accounts: [account], backupPassword: 'backup-password1');
    await expectLater(
        service.importBackup(
            filePath: result.file.path, backupPassword: 'wrong-password'),
        throwsException);
    final file = File(result.file.path);
    final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final bytes = base64Decode(map['cipherText'] as String);
    bytes[0] ^= 1;
    map['cipherText'] = base64Encode(bytes);
    await file.writeAsString(jsonEncode(map));
    await expectLater(
        service.importBackup(
            filePath: file.path, backupPassword: 'backup-password1'),
        throwsException);
  });

  test('unsupported versions and KDF parameters are rejected', () async {
    final result = await service
        .exportBackup(accounts: [account], backupPassword: 'backup-password1');
    final file = File(result.file.path);
    final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    map['iterations'] = 1;
    await file.writeAsString(jsonEncode(map));
    await expectLater(
        service.importBackup(
            filePath: file.path, backupPassword: 'backup-password1'),
        throwsException);
    map['version'] = '99.0';
    await file.writeAsString(jsonEncode(map));
    await expectLater(
        service.importBackup(
            filePath: file.path, backupPassword: 'backup-password1'),
        throwsException);
  });

  test('invalid records are rejected instead of silently dropped', () async {
    const password = 'backup-password1';
    final salt = KeyDerivation.generateSalt();
    final key = await KeyDerivation.deriveKey(password, salt);
    final encrypted = await AesService.encryptToPayload(
        jsonEncode({
          'accounts': [account.toBackupMap(), 42]
        }),
        key,
        associatedData:
            'personal-assistant-backup:2.0:PBKDF2-SHA256:150000:$salt');
    final file = File('${directory.path}/invalid.json');
    await file.writeAsString(jsonEncode({
      'version': '2.0',
      'salt': salt,
      'iv': encrypted.iv,
      'cipherText': encrypted.cipherText,
      'encryption': 'AES-256-GCM',
      'kdf': 'PBKDF2-SHA256',
      'iterations': 150000
    }));
    await expectLater(
        service.importBackup(filePath: file.path, backupPassword: password),
        throwsException);
  });
  test('old 1.0 backups remain readable under their original vault key',
      () async {
    final vaultKey = await KeyDerivation.deriveKey(
        'old-master-password', KeyDerivation.generateSalt());
    final salt = KeyDerivation.generateSalt();
    final backupKey = await KeyDerivation.deriveKey(vaultKey, salt);
    final encrypted = await AesService.encryptToPayload(
        jsonEncode({
          'accounts': [account.toBackupMap()]
        }),
        backupKey);
    final hash = sha256
        .convert(utf8.encode('${encrypted.cipherText}:$salt:${encrypted.iv}'))
        .toString();
    final file = File('${directory.path}/old-backup.json');
    await file.writeAsString(jsonEncode({
      'version': '1.0',
      'encryption': 'AES-256-GCM',
      'salt': salt,
      'iv': encrypted.iv,
      'cipherText': encrypted.cipherText,
      'hash': hash
    }));
    final restored = await service.importBackup(
        filePath: file.path, encryptionKey: vaultKey);
    expect(restored.single.toBackupMap(), account.toBackupMap());
    await expectLater(
        service.importBackup(
            filePath: file.path, encryptionKey: 'unrelated-key'),
        throwsException);
  });
}
