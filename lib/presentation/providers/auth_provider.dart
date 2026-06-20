import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../../core/biometric/biometric_service.dart';
import '../../core/encryption/key_derivation.dart';
import '../../core/secure_storage/secure_storage_service.dart';
import '../../data/datasource/vault_local_datasource.dart';
import '../../data/repositories/vault_repository_impl.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider()
      : _secureStorage = SecureStorageService(),
        _biometricService = BiometricService(),
        _vaultRepository = VaultRepositoryImpl(VaultLocalDataSource());

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
    final hash = await _secureStorage.getMasterPasswordHash();
    final authVersion = await _secureStorage.getAuthVersion();

    _isFirstLaunch = hash == null;
    _isLegacyStorageFormat = !_isFirstLaunch && authVersion != '2';
    _isBiometricAvailable = await _biometricService.isBiometricAvailable();
    _isBiometricEnabled = await _secureStorage.getBiometricEnabled();
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> setupMasterPassword(String password) async {
    _validatePasswordRules(password);

    final salt = KeyDerivation.generateSalt();
    final keyBytes = await KeyDerivation.deriveKeyBytes(password, salt);
    final encryptionKey = _toEncryptionKey(keyBytes);
    final verifier = KeyDerivation.buildPasswordVerifier(keyBytes);

    await _secureStorage.saveMasterSalt(salt);
    await _secureStorage.saveMasterPasswordHash(verifier);
    await _secureStorage.saveAuthVersion('2');
    await _secureStorage.saveBiometricEnabled(false);
    await _secureStorage.deleteBiometricEncryptionKey();

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
    if (isTemporarilyLocked) {
      notifyListeners();
      return false;
    }

    if (_isLegacyStorageFormat) {
      return _authenticateLegacy(password);
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

    _encryptionKey = _toEncryptionKey(keyBytes);
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
    if (!_isBiometricAvailable || !_isBiometricEnabled) {
      return false;
    }

    final success = await _biometricService.authenticate(reason);
    if (!success) {
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
      await _secureStorage.saveMasterPasswordHash(
        KeyDerivation.buildPasswordVerifier(keyBytes),
      );
      await _secureStorage.saveAuthVersion('2');
      await _secureStorage.saveBiometricEncryptionKey(newEncryptionKey);
      _isLegacyStorageFormat = false;
      _encryptionKey = newEncryptionKey;
    } else {
      _encryptionKey = storedKey;
    }

    _isUnlocked = true;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
    return true;
  }

  void lock() {
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

    final currentKey = _encryptionKey!;
    final newSalt = KeyDerivation.generateSalt();
    final newKeyBytes =
        await KeyDerivation.deriveKeyBytes(newPassword, newSalt);
    final newEncryptionKey = _toEncryptionKey(newKeyBytes);

    await _vaultRepository.reencryptAllData(
      oldEncryptionKey: currentKey,
      newEncryptionKey: newEncryptionKey,
    );

    await _secureStorage.saveMasterSalt(newSalt);
    await _secureStorage.saveMasterPasswordHash(
      KeyDerivation.buildPasswordVerifier(newKeyBytes),
    );
    await _secureStorage.saveAuthVersion('2');

    if (_isBiometricEnabled) {
      await _secureStorage.saveBiometricEncryptionKey(newEncryptionKey);
    } else {
      await _secureStorage.deleteBiometricEncryptionKey();
    }

    _encryptionKey = newEncryptionKey;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
    _isInitialized = true;
    _isUnlocked = false;
    _isFirstLaunch = true;
    _isBiometricEnabled = false;
    _isLegacyStorageFormat = false;
    _encryptionKey = null;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
  }

  Future<bool> _authenticateLegacy(String password) async {
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
    await _secureStorage.saveMasterPasswordHash(
      KeyDerivation.buildPasswordVerifier(keyBytes),
    );
    await _secureStorage.saveAuthVersion('2');

    if (_isBiometricEnabled) {
      await _secureStorage.saveBiometricEncryptionKey(newEncryptionKey);
    } else {
      await _secureStorage.deleteBiometricEncryptionKey();
    }

    _encryptionKey = newEncryptionKey;
    _isUnlocked = true;
    _isLegacyStorageFormat = false;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
    return true;
  }

  Future<String> _deriveLegacyPasswordHash(String password, String salt) async {
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);

    var key = List<int>.from(passwordBytes);
    for (var i = 0; i < 100000; i++) {
      key = sha256.convert([...key, ...saltBytes]).bytes;
    }

    return base64Encode(key);
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
  }

  String _toEncryptionKey(Uint8List keyBytes) {
    return base64Encode(keyBytes);
  }
}
