import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import 'package:password_manager/core/biometric/biometric_service.dart';
import 'package:password_manager/core/encryption/key_derivation.dart';
import 'package:password_manager/core/encryption/master_key_record.dart';
import 'package:password_manager/core/secure_storage/secure_storage_service.dart';
import 'package:password_manager/features/vault/data/datasource/vault_local_datasource.dart';
import 'package:password_manager/features/vault/data/repositories/vault_repository_impl.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(
      {SecureStorageService? secureStorage,
      BiometricService? biometricService,
      VaultRepositoryImpl? repository})
      : _secureStorage = secureStorage ?? SecureStorageService(),
        _biometricService = biometricService ?? BiometricService(),
        _vaultRepository =
            repository ?? VaultRepositoryImpl(VaultLocalDataSource());

  final SecureStorageService _secureStorage;
  final BiometricService _biometricService;
  final VaultRepositoryImpl _vaultRepository;

  bool _isInitialized = false;
  bool _isUnlocked = false;
  bool _isFirstLaunch = true;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLegacyStorageFormat = false;
  String? _encryptionKey;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  MasterKeyRecord? _keyRecord;
  int _sessionGeneration = 0;

  bool get isInitialized => _isInitialized;
  bool get isUnlocked => _isUnlocked;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String? get encryptionKey => _encryptionKey;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockedUntil => _lockedUntil;
  bool get isTemporarilyLocked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  Future<void> init() async {
    final state = await _secureStorage.getAuthState();
    _keyRecord = state == null ? null : MasterKeyRecord.decode(state);
    final hash = await _secureStorage.getMasterPasswordHash();
    final authVersion = await _secureStorage.getAuthVersion();

    _isFirstLaunch = _keyRecord == null && hash == null;
    _isLegacyStorageFormat =
        _keyRecord == null && !_isFirstLaunch && authVersion != '2';
    _isBiometricAvailable = await _biometricService.isBiometricAvailable();
    _isBiometricEnabled = await _secureStorage.getBiometricEnabled();
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> setupMasterPassword(String password) async {
    _validatePasswordRules(password);

    await _secureStorage.saveBiometricEnabled(false);
    await _secureStorage.deleteBiometricEncryptionKey();

    final encryptionKey = MasterKeyRecord.generateDataKey();
    final record = await MasterKeyRecord.create(password, encryptionKey);
    await _secureStorage.saveAuthState(record.encode());
    _keyRecord = record;

    _encryptionKey = encryptionKey;
    _isUnlocked = true;
    _isFirstLaunch = false;
    _isLegacyStorageFormat = false;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
    return true;
  }

  Future<bool> authenticate(String password) async {
    final generation = _sessionGeneration;
    if (isTemporarilyLocked) {
      notifyListeners();
      return false;
    }

    if (_isLegacyStorageFormat) {
      return _authenticateLegacy(password);
    }

    if (_keyRecord != null) {
      String key;
      try {
        key = await _keyRecord!.unlock(password);
      } catch (_) {
        if (generation == _sessionGeneration) _registerFailure();
        return false;
      }
      if (generation != _sessionGeneration) return false;
      if (_isBiometricEnabled) {
        await _secureStorage.saveBiometricEncryptionKey(key);
      }
      if (generation != _sessionGeneration) return false;
      _encryptionKey = key;
      _isUnlocked = true;
      _failedAttempts = 0;
      _lockedUntil = null;
      notifyListeners();
      return true;
    }

    final storedVerifier = await _secureStorage.getMasterPasswordHash();
    final salt = await _secureStorage.getMasterSalt();
    if (storedVerifier == null || salt == null) {
      return false;
    }

    final keyBytes = await KeyDerivation.deriveKeyBytes(password, salt);
    final verifier = KeyDerivation.buildPasswordVerifier(keyBytes);
    if (verifier != storedVerifier) {
      _registerFailure();
      return false;
    }

    if (generation != _sessionGeneration) return false;
    final dataKey = _toEncryptionKey(keyBytes);
    final record = await MasterKeyRecord.wrap(
      salt: salt,
      wrappingKey: dataKey,
      dataKey: dataKey,
    );
    await _secureStorage.saveAuthState(record.encode());
    _keyRecord = record;
    if (generation != _sessionGeneration) return false;
    _encryptionKey = dataKey;
    _isUnlocked = true;
    _failedAttempts = 0;
    _lockedUntil = null;

    if (_isBiometricEnabled) {
      await _secureStorage.saveBiometricEncryptionKey(_encryptionKey!);
    }

    notifyListeners();
    return true;
  }

  Future<bool> authenticateWithBiometrics({
    String reason = '请验证身份',
  }) async {
    final generation = _sessionGeneration;
    if (!_isBiometricAvailable || !_isBiometricEnabled) {
      return false;
    }

    final success = await _biometricService.authenticate(reason);
    if (!success || generation != _sessionGeneration) {
      return false;
    }

    final storedKey = await _secureStorage.getBiometricEncryptionKey();
    if (storedKey == null || storedKey.isEmpty) {
      return false;
    }

    if (_isLegacyStorageFormat) {
      final salt = await _secureStorage.getMasterSalt();
      if (salt == null) {
        return false;
      }
      final legacyPassword = storedKey;
      final keyBytes = await KeyDerivation.deriveKeyBytes(legacyPassword, salt);
      final newEncryptionKey = _toEncryptionKey(keyBytes);
      await _vaultRepository.migrateLegacyEncryption(
        legacyPassword: legacyPassword,
        newEncryptionKey: newEncryptionKey,
      );
      final record = await MasterKeyRecord.wrap(
        salt: salt,
        wrappingKey: newEncryptionKey,
        dataKey: newEncryptionKey,
      );
      await _secureStorage.saveAuthState(record.encode());
      _keyRecord = record;
      await _secureStorage.saveBiometricEncryptionKey(newEncryptionKey);
      _isLegacyStorageFormat = false;
      _encryptionKey = newEncryptionKey;
    } else {
      _encryptionKey = storedKey;
    }

    if (generation != _sessionGeneration) {
      _encryptionKey = null;
      return false;
    }
    _isUnlocked = true;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
    return true;
  }

  void lock() {
    _sessionGeneration++;
    _isUnlocked = false;
    _encryptionKey = null;
    notifyListeners();
  }

  Future<void> toggleBiometric(bool enabled) async {
    if (enabled) {
      if (!_isBiometricAvailable || _encryptionKey == null) {
        throw Exception('当前设备无法启用生物识别');
      }

      final verified = await _biometricService.authenticate('请验证身份以启用生物识别');
      if (!verified) {
        throw Exception('生物识别验证失败');
      }

      await _secureStorage.saveBiometricEncryptionKey(_encryptionKey!);
    } else {
      await _secureStorage.deleteBiometricEncryptionKey();
    }

    _isBiometricEnabled = enabled;
    await _secureStorage.saveBiometricEnabled(enabled);
    notifyListeners();
  }

  Future<void> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    _validatePasswordRules(newPassword);

    final authenticated = await authenticate(oldPassword);
    if (!authenticated || _encryptionKey == null) {
      throw Exception('原密码错误');
    }

    final generation = _sessionGeneration;
    final record = await MasterKeyRecord.create(newPassword, _encryptionKey!);
    if (generation != _sessionGeneration) throw Exception('会话已锁定，请重新解锁');
    // One secure-storage write; no database re-encryption or key/salt split writes.
    await _secureStorage.saveAuthState(record.encode());
    _keyRecord = record;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _sessionGeneration++;
    await _secureStorage.deleteAll();
    _isInitialized = true;
    _isUnlocked = false;
    _isFirstLaunch = true;
    _isBiometricEnabled = false;
    _isLegacyStorageFormat = false;
    _encryptionKey = null;
    _keyRecord = null;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
  }

  Future<bool> _authenticateLegacy(String password) async {
    final generation = _sessionGeneration;
    final storedHash = await _secureStorage.getMasterPasswordHash();
    final salt = await _secureStorage.getMasterSalt();
    if (storedHash == null || salt == null) {
      return false;
    }

    final legacyHash = await _deriveLegacyPasswordHash(password, salt);
    if (legacyHash != storedHash) {
      _registerFailure();
      return false;
    }

    final keyBytes = await KeyDerivation.deriveKeyBytes(password, salt);
    final newEncryptionKey = _toEncryptionKey(keyBytes);

    await _vaultRepository.migrateLegacyEncryption(
      legacyPassword: password,
      newEncryptionKey: newEncryptionKey,
    );
    final record = await MasterKeyRecord.wrap(
      salt: salt,
      wrappingKey: newEncryptionKey,
      dataKey: newEncryptionKey,
    );
    // Until this write succeeds, the original verifier remains usable to retry
    // migration. Already migrated rows are skipped by the repository.
    await _secureStorage.saveAuthState(record.encode());
    _keyRecord = record;

    if (_isBiometricEnabled) {
      await _secureStorage.saveBiometricEncryptionKey(newEncryptionKey);
    } else {
      await _secureStorage.deleteBiometricEncryptionKey();
    }

    if (generation != _sessionGeneration) return false;
    _encryptionKey = newEncryptionKey;
    _isUnlocked = true;
    _isLegacyStorageFormat = false;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
    return true;
  }

  static Future<String> _deriveLegacyPasswordHash(
      String password, String salt) async {
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);

    return Isolate.run(() {
      var key = List<int>.from(passwordBytes);
      for (var i = 0; i < 100000; i++) {
        key = sha256.convert([...key, ...saltBytes]).bytes;
      }
      return base64Encode(key);
    });
  }

  void _registerFailure() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _failedAttempts = 0;
    }
    notifyListeners();
  }

  void _validatePasswordRules(String password) {
    if (password.length < 8) {
      throw Exception('主密码至少需要 8 位');
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      throw Exception('主密码必须包含数字');
    }
  }

  String _toEncryptionKey(Uint8List keyBytes) {
    return base64Encode(keyBytes);
  }
}
