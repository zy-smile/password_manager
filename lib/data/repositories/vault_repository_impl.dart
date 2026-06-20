import '../../core/encryption/aes_service.dart';
import '../../domain/entities/vault_account.dart';
import '../../domain/repositories/vault_repository.dart';
import '../datasource/vault_local_datasource.dart';
import '../models/vault_account_model.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl(this._dataSource);

  final VaultLocalDataSource _dataSource;
  String? _encryptionKey;

  void setEncryptionKey(String key) {
    _encryptionKey = key;
  }

  void clearEncryptionKey() {
    _encryptionKey = null;
  }

  String get currentEncryptionKey {
    if (_encryptionKey == null) {
      throw Exception('Encryption key not set');
    }
    return _encryptionKey!;
  }

  @override
  Future<void> addAccount(VaultAccount account) async {
    final key = currentEncryptionKey;
    final model = await _encryptAccount(account, key);
    await _dataSource.insertAccount(model);
  }

  @override
  Future<void> updateAccount(VaultAccount account) async {
    final key = currentEncryptionKey;
    final model = await _encryptAccount(account, key);
    await _dataSource.updateAccount(model);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _dataSource.deleteAccount(id);
  }

  @override
  Future<List<VaultAccount>> getAllAccounts() async {
    final models = await _dataSource.getAllAccounts();
    return _decryptAccounts(models, key: currentEncryptionKey);
  }

  @override
  Future<List<VaultAccount>> searchAccounts(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return getAllAccounts();
    }

    final accounts = await getAllAccounts();
    return accounts.where((account) {
      return account.title.toLowerCase().contains(normalized) ||
          account.website.toLowerCase().contains(normalized) ||
          account.username.toLowerCase().contains(normalized);
    }).toList();
  }

  @override
  Future<List<VaultAccount>> getAccountsByCategory(String category) async {
    final models = await _dataSource.getAccountsByCategory(category);
    return _decryptAccounts(models, key: currentEncryptionKey);
  }

  @override
  Future<List<VaultAccount>> getFavoriteAccounts() async {
    final models = await _dataSource.getFavoriteAccounts();
    return _decryptAccounts(models, key: currentEncryptionKey);
  }

  @override
  Future<VaultAccount?> getAccountById(String id) async {
    final model = await _dataSource.getAccountById(id);
    if (model == null) return null;
    return _decryptAccount(model, key: currentEncryptionKey);
  }

  @override
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    await _dataSource.toggleFavorite(id, isFavorite);
  }

  @override
  Future<bool?> getBiometricEnabled() async {
    final settings = await _dataSource.getSettings();
    return settings?.biometricEnabled;
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    await _dataSource.setBiometricEnabled(enabled);
  }

  @override
  Future<int?> getAutoLockMinutes() async {
    final settings = await _dataSource.getSettings();
    return settings?.autoLockMinutes;
  }

  @override
  Future<void> setAutoLockMinutes(int minutes) async {
    await _dataSource.setAutoLockMinutes(minutes);
  }

  @override
  Future<List<String>> getAllCategories() async {
    final categories = await _dataSource.getAllCategories();
    return categories.map((category) => category.name).toList();
  }

  Future<void> migrateLegacyEncryption({
    required String legacyPassword,
    required String newEncryptionKey,
  }) async {
    final models = await _dataSource.getAllAccounts();
    final migrated = <VaultAccountModel>[];

    for (final model in models) {
      if (model.encryptionVersion >= 2 &&
          (model.usernameEncrypted?.isNotEmpty ?? false)) {
        migrated.add(model);
        continue;
      }

      final password = await AesService.decryptLegacy(
        model.passwordEncrypted,
        legacyPassword,
      );
      final username = model.username ?? '';
      final note = model.note ?? '';
      final account = VaultAccount(
        id: model.id,
        title: model.title,
        website: model.website,
        username: username,
        password: password,
        note: note,
        category: model.category,
        isFavorite: model.isFavorite,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      );
      migrated.add(await _encryptAccount(account, newEncryptionKey));
    }

    await _dataSource.replaceAllAccounts(migrated);
  }

  Future<void> reencryptAllData({
    required String oldEncryptionKey,
    required String newEncryptionKey,
  }) async {
    final models = await _dataSource.getAllAccounts();
    final decrypted = await _decryptAccounts(models, key: oldEncryptionKey);
    final reencrypted = <VaultAccountModel>[];

    for (final account in decrypted) {
      reencrypted.add(await _encryptAccount(account, newEncryptionKey));
    }

    await _dataSource.replaceAllAccounts(reencrypted);
  }

  Future<void> replaceAllAccounts(List<VaultAccount> accounts) async {
    final key = currentEncryptionKey;
    final models = <VaultAccountModel>[];
    for (final account in accounts) {
      models.add(await _encryptAccount(account, key));
    }
    await _dataSource.replaceAllAccounts(models);
  }

  Future<void> clearAllData() async {
    await _dataSource.clearAllAccounts();
  }

  Future<VaultAccountModel> _encryptAccount(
    VaultAccount account,
    String key,
  ) async {
    final encryptedUsername = await AesService.encrypt(account.username, key);
    final encryptedPassword = await AesService.encrypt(account.password, key);
    final encryptedNote = account.note.isEmpty
        ? null
        : await AesService.encrypt(account.note, key);

    return VaultAccountModel(
      id: account.id,
      title: account.title,
      website: account.website,
      usernameEncrypted: encryptedUsername,
      passwordEncrypted: encryptedPassword,
      noteEncrypted: encryptedNote,
      category: account.category,
      isFavorite: account.isFavorite,
      encryptionVersion: 2,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  Future<List<VaultAccount>> _decryptAccounts(
    List<VaultAccountModel> models, {
    required String key,
  }) {
    return Future.wait(
      models.map((model) => _decryptAccount(model, key: key)),
    );
  }

  Future<VaultAccount> _decryptAccount(
    VaultAccountModel model, {
    required String key,
  }) async {
    if (model.encryptionVersion < 2) {
      throw Exception('Legacy record must be migrated before reading');
    }

    final username = model.usernameEncrypted == null
        ? (model.username ?? '')
        : await AesService.decrypt(model.usernameEncrypted!, key);
    final password = await AesService.decrypt(model.passwordEncrypted, key);
    final note = model.noteEncrypted == null || model.noteEncrypted!.isEmpty
        ? (model.note ?? '')
        : await AesService.decrypt(model.noteEncrypted!, key);

    return VaultAccount(
      id: model.id,
      title: model.title,
      website: model.website,
      username: username,
      password: password,
      note: note,
      category: model.category,
      isFavorite: model.isFavorite,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }
}
