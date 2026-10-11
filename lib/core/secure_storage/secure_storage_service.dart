import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _keyMasterPasswordHash = 'master_password_hash';
  static const String _keyMasterSalt = 'master_salt';
  static const String _keyEncryptionKey = 'encryption_key';
  static const String _keyAuthVersion = 'auth_version';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyAutoLockMinutes = 'auto_lock_minutes';

  final FlutterSecureStorage _storage;

  /// Store wrapping salt and encrypted data key together in one record.
  Future<String?> getAuthState() => _storage.read(key: 'auth_state_v3');

  Future<void> saveAuthState(String state) =>
      _storage.write(key: 'auth_state_v3', value: state);

  SecureStorageService() : _storage = const FlutterSecureStorage();

  Future<void> saveMasterPasswordHash(String hash) async {
    await _storage.write(key: _keyMasterPasswordHash, value: hash);
  }

  Future<String?> getMasterPasswordHash() async {
    return _storage.read(key: _keyMasterPasswordHash);
  }

  Future<void> saveMasterSalt(String salt) async {
    await _storage.write(key: _keyMasterSalt, value: salt);
  }

  Future<String?> getMasterSalt() async {
    return _storage.read(key: _keyMasterSalt);
  }

  Future<void> saveBiometricEncryptionKey(String key) async {
    await _storage.write(key: _keyEncryptionKey, value: key);
  }

  Future<String?> getBiometricEncryptionKey() async {
    return _storage.read(key: _keyEncryptionKey);
  }

  Future<void> deleteBiometricEncryptionKey() async {
    await _storage.delete(key: _keyEncryptionKey);
  }

  Future<void> saveAuthVersion(String version) async {
    await _storage.write(key: _keyAuthVersion, value: version);
  }

  Future<String?> getAuthVersion() async {
    return _storage.read(key: _keyAuthVersion);
  }

  Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBiometricEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> getBiometricEnabled() async {
    final value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  Future<void> saveAutoLockMinutes(int minutes) async {
    await _storage.write(key: _keyAutoLockMinutes, value: minutes.toString());
  }

  Future<int> getAutoLockMinutes() async {
    final value = await _storage.read(key: _keyAutoLockMinutes);
    final minutes = int.tryParse(value ?? '') ?? 5;
    return [0, 1, 5, 10, 30].contains(minutes) ? minutes : 5;
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
