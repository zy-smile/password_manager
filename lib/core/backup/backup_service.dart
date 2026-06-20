// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../domain/entities/vault_account.dart';
import '../constants/app_constants.dart';
import '../encryption/aes_service.dart';
import '../encryption/key_derivation.dart';

class BackupFileInfo {
  const BackupFileInfo({
    required this.name,
    required this.path,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final DateTime modifiedAt;
  final int sizeBytes;
}

class BackupExportResult {
  const BackupExportResult({
    required this.file,
    required this.accountCount,
  });

  final BackupFileInfo file;
  final int accountCount;
}

class BackupService {
  Future<BackupExportResult> exportBackup({
    required List<VaultAccount> accounts,
    required String encryptionKey,
  }) async {
    final exportTime = DateTime.now();
    final salt = KeyDerivation.generateSalt();
    final backupKey = await KeyDerivation.deriveKey(encryptionKey, salt);
    final payload = jsonEncode({
      'accounts': accounts.map((account) => account.toBackupMap()).toList(),
    });

    final encrypted = await AesService.encryptToPayload(payload, backupKey);
    final hash = _buildHash(
      cipherText: encrypted.cipherText,
      salt: salt,
      iv: encrypted.iv,
    );

    final backupDirectory = await _ensureBackupDirectory();
    final fileName = 'password_vault_${_timestampForFile(exportTime)}.json';
    final filePath = path.join(backupDirectory.path, fileName);
    final file = File(filePath);

    final document = const JsonEncoder.withIndent('  ').convert({
      'version': AppConstants.backupVersion,
      'exportTime': exportTime.toIso8601String(),
      'salt': salt,
      'iv': encrypted.iv,
      'cipherText': encrypted.cipherText,
      'hash': hash,
      'encryption': AppConstants.backupEncryption,
    });

    await file.writeAsString(document);
    final stat = await file.stat();

    return BackupExportResult(
      file: BackupFileInfo(
        name: fileName,
        path: filePath,
        modifiedAt: stat.modified,
        sizeBytes: stat.size,
      ),
      accountCount: accounts.length,
    );
  }

  Future<List<BackupFileInfo>> listBackups() async {
    final backupDirectory = await _ensureBackupDirectory();
    final files = backupDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();

    final backups = <BackupFileInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      backups.add(
        BackupFileInfo(
          name: path.basename(file.path),
          path: file.path,
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<String> getBackupDirectoryPath() async {
    final backupDirectory = await _ensureBackupDirectory();
    return backupDirectory.path;
  }

  Future<void> deleteAllBackups() async {
    final backupDirectory = await _ensureBackupDirectory();
    for (final entity in backupDirectory.listSync()) {
      if (entity is File) {
        await entity.delete();
      }
    }
  }

  Future<List<VaultAccount>> importBackup({
    required String filePath,
    required String encryptionKey,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('备份文件不存在');
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw Exception('备份文件格式无效');
    }

    _validateHeader(decoded);

    final salt = decoded['salt'] as String;
    final iv = decoded['iv'] as String;
    final cipherText = decoded['cipherText'] as String;
    final hash = decoded['hash'] as String;
    final expectedHash = _buildHash(
      cipherText: cipherText,
      salt: salt,
      iv: iv,
    );

    if (hash != expectedHash) {
      throw Exception('备份文件校验失败');
    }

    final backupKey = await KeyDerivation.deriveKey(encryptionKey, salt);
    final plaintext = await AesService.decryptPayload(
      iv: iv,
      cipherText: cipherText,
      key: backupKey,
    );

    final payload = jsonDecode(plaintext);
    if (payload is! Map<String, dynamic>) {
      throw Exception('备份内容无效');
    }

    final rawAccounts = payload['accounts'];
    if (rawAccounts is! List) {
      throw Exception('备份中缺少账号数据');
    }

    return rawAccounts
        .whereType<Map>()
        .map(
          (account) => VaultAccount.fromBackupMap(
            Map<String, dynamic>.from(account),
          ),
        )
        .toList();
  }

  Future<Directory> _ensureBackupDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(
      path.join(documentsDirectory.path, 'backups'),
    );

    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }

    return backupDirectory;
  }

  void _validateHeader(Map<String, dynamic> data) {
    if (data['version'] != AppConstants.backupVersion) {
      throw Exception('不支持的备份版本');
    }
    if (data['encryption'] != AppConstants.backupEncryption) {
      throw Exception('不支持的加密方式');
    }

    for (final field in const ['salt', 'iv', 'cipherText', 'hash']) {
      if (data[field] is! String || (data[field] as String).isEmpty) {
        throw Exception('备份文件缺少必要字段：$field');
      }
    }
  }

  String _buildHash({
    required String cipherText,
    required String salt,
    required String iv,
  }) {
    final input = utf8.encode('$cipherText:$salt:$iv');
    return sha256.convert(input).toString();
  }

  String _timestampForFile(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '${year}${month}${day}_$hour$minute$second';
  }
}
