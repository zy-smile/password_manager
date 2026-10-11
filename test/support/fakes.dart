import 'package:password_manager/core/biometric/biometric_service.dart';
import 'package:password_manager/core/secure_storage/secure_storage_service.dart';
import 'package:password_manager/features/vault/data/datasource/vault_local_datasource.dart';
import 'package:password_manager/features/vault/data/models/vault_account_model.dart';
import 'package:password_manager/features/vault/presentation/providers/auth_provider.dart';

class MemorySecureStorage extends SecureStorageService {
  String? state, salt, hash, version, biometricKey;
  bool biometric = false;
  bool failNextStateWrite = false;
  int lockMinutes = 5;

  @override
  Future<String?> getAuthState() async => state;
  @override
  Future<void> saveAuthState(String value) async {
    if (failNextStateWrite) {
      failNextStateWrite = false;
      throw StateError('Injected storage failure');
    }
    state = value;
  }

  @override
  Future<String?> getMasterSalt() async => salt;
  @override
  Future<void> saveMasterSalt(String value) async {
    salt = value;
  }

  @override
  Future<String?> getMasterPasswordHash() async => hash;
  @override
  Future<void> saveMasterPasswordHash(String value) async {
    hash = value;
  }

  @override
  Future<String?> getAuthVersion() async => version;
  @override
  Future<void> saveAuthVersion(String value) async {
    version = value;
  }

  @override
  Future<bool> getBiometricEnabled() async => biometric;
  @override
  Future<void> saveBiometricEnabled(bool value) async {
    biometric = value;
  }

  @override
  Future<String?> getBiometricEncryptionKey() async => biometricKey;
  @override
  Future<void> saveBiometricEncryptionKey(String value) async {
    biometricKey = value;
  }

  @override
  Future<void> deleteBiometricEncryptionKey() async {
    biometricKey = null;
  }

  @override
  Future<int> getAutoLockMinutes() async => lockMinutes;
  @override
  Future<void> saveAutoLockMinutes(int value) async {
    lockMinutes = value;
  }

  @override
  Future<void> deleteAll() async {
    state = salt = hash = version = biometricKey = null;
    biometric = false;
  }
}

class FakeBiometricService extends BiometricService {
  @override
  Future<bool> isBiometricAvailable() async => false;
  @override
  Future<bool> authenticate(String reason) async => false;
}

class MemoryVaultDataSource extends VaultLocalDataSource {
  List<VaultAccountModel> records = [];
  int reads = 0;
  @override
  Future<List<VaultAccountModel>> getAllAccounts() async {
    reads++;
    return List.of(records);
  }

  @override
  Future<void> insertAccount(VaultAccountModel account) async {
    records.add(account);
  }

  @override
  Future<void> replaceAllAccounts(List<VaultAccountModel> accounts) async {
    records = List.of(accounts);
  }

  @override
  Future<void> clearAllAccounts() async {
    records = [];
  }
}

class SessionTestAuth extends AuthProvider {
  SessionTestAuth()
      : super(
            secureStorage: MemorySecureStorage(),
            biometricService: FakeBiometricService());
  bool unlocked = true;
  String? key = 'test-key';
  @override
  bool get isInitialized => true;
  @override
  bool get isFirstLaunch => false;
  @override
  bool get isUnlocked => unlocked;
  @override
  String? get encryptionKey => key;
  @override
  void lock() {
    unlocked = false;
    key = null;
    notifyListeners();
  }

  void unlock(String value) {
    unlocked = true;
    key = value;
    notifyListeners();
  }
}
