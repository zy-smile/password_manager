// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'package:password_manager/features/vault/domain/entities/vault_account.dart';
import 'package:password_manager/core/constants/app_constants.dart';
import 'package:password_manager/core/encryption/aes_service.dart';
import 'package:password_manager/core/encryption/key_derivation.dart';

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
  BackupService({Directory? directory}) : _directory = directory;
  final Directory? _directory;
  static const maxFileBytes = 32 * 1024 * 1024;

  Future<BackupExportResult> exportBackup({
    required List<VaultAccount> accounts,
    required String backupPassword,
  }) async {
    if (backupPassword.length < 8) throw Exception('备份密码至少需要 8 位');
    final exportTime = DateTime.now();
    final salt = KeyDerivation.generateSalt();
    final backupKey = await KeyDerivation.deriveKey(backupPassword, salt);
    final payload = jsonEncode({
      'accounts': accounts.map((account) => account.toBackupMap()).toList(),
    });

    final encrypted = await AesService.encryptToPayload(
      payload,
      backupKey,
      associatedData: _associatedData(salt),
    );

    final backupDirectory = await _ensureBackupDirectory();
    final fileName = 'password_vault_${exportTime.microsecondsSinceEpoch}.json';
    final filePath = path.join(backupDirectory.path, fileName);
    final file = File(filePath);

    final document = const JsonEncoder.withIndent('  ').convert({
      'version': AppConstants.backupVersion,
      'exportTime': exportTime.toIso8601String(),
      'salt': salt,
      'iv': encrypted.iv,
      'cipherText': encrypted.cipherText,
      'encryption': AppConstants.backupEncryption,
      'kdf': 'PBKDF2-SHA256',
      'iterations': KeyDerivation.defaultIterations,
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
    String? encryptionKey,
    String? backupPassword,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('备份文件不存在');
    }
    if (await file.length() > maxFileBytes) throw Exception('备份文件过大');

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw Exception('备份文件格式无效');
    }

    _validateHeader(decoded);

    final salt = decoded['salt'] as String;
    final iv = decoded['iv'] as String;
    final cipherText = decoded['cipherText'] as String;
    final legacy = decoded['version'] == '1.0';
    final secret = legacy ? encryptionKey : backupPassword;
    if (secret == null || secret.isEmpty) {
      throw Exception(legacy ? '旧版备份只能在原保险箱密钥下恢复' : '请输入备份密码');
    }
    if (legacy &&
        decoded['hash'] !=
            _buildHash(cipherText: cipherText, salt: salt, iv: iv)) {
      throw Exception('备份文件校验失败');
    }
    final backupKey = await KeyDerivation.deriveKey(secret, salt);
    String plaintext;
    try {
      plaintext = await AesService.decryptPayload(
        iv: iv,
        cipherText: cipherText,
        key: backupKey,
        associatedData: legacy ? null : _associatedData(salt),
      );
    } catch (_) {
      throw Exception('备份密码错误或文件已损坏');
    }

    final payload = jsonDecode(plaintext);
    if (payload is! Map<String, dynamic>) {
      throw Exception('备份内容无效');
    }

    final rawAccounts = payload['accounts'];
    if (rawAccounts is! List) {
      throw Exception('备份中缺少账号数据');
    }

    final accounts = <VaultAccount>[];
    final ids = <String>{};
    for (final raw in rawAccounts) {
      if (raw is! Map<String, dynamic>) throw Exception('备份账号格式无效');
      for (final field in [
        'id',
        'title',
        'website',
        'username',
        'password',
        'note',
        'category',
        'createdAt',
        'updatedAt'
      ]) {
        if (raw[field] is! String) throw Exception('备份账号字段无效：$field');
      }
      final account = VaultAccount.fromBackupMap(raw);
      if (account.id.isEmpty ||
          !ids.add(account.id) ||
          raw['favorite'] is! bool) {
        throw Exception('备份中存在无效或重复的账号');
      }
      accounts.add(account);
    }
    return accounts;
  }

  Future<Directory> _ensureBackupDirectory() async {
    final documentsDirectory =
        _directory == null ? await getApplicationDocumentsDirectory() : null;
    final backupDirectory = _directory ??
        Directory(
          path.join(documentsDirectory!.path, 'backups'),
        );

    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }

    return backupDirectory;
  }

  void _validateHeader(Map<String, dynamic> data) {
    if (data['version'] != AppConstants.backupVersion &&
        data['version'] != '1.0') {
      throw Exception('不支持的备份版本');
    }
    if (data['encryption'] != AppConstants.backupEncryption) {
      throw Exception('不支持的加密方式');
    }

    for (final field in const ['salt', 'iv', 'cipherText']) {
      if (data[field] is! String || (data[field] as String).isEmpty) {
        throw Exception('备份文件缺少必要字段：$field');
      }
    }
    if (data['version'] == '2.0' &&
        (data['kdf'] != 'PBKDF2-SHA256' ||
            data['iterations'] != KeyDerivation.defaultIterations)) {
      throw Exception('不支持的备份密钥派生参数');
    }
    if (data['version'] == '1.0' && data['hash'] is! String) {
      throw Exception('旧版备份缺少校验值');
    }
    if (base64Decode(data['salt'] as String).length != 16 ||
        base64Decode(data['iv'] as String).length != 12 ||
        base64Decode(data['cipherText'] as String).length < 16) {
      throw Exception('备份加密参数无效');
    }
  }

  String _associatedData(String salt) =>
      'personal-assistant-backup:2.0:PBKDF2-SHA256:150000:$salt';

  String _buildHash({
    required String cipherText,
    required String salt,
    required String iv,
  }) {
    final input = utf8.encode('$cipherText:$salt:$iv');
    return sha256.convert(input).toString();
  }
}
