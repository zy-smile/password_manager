import '../database/app_database.dart';
import '../database/dao/categories_dao.dart';
import '../database/dao/settings_dao.dart';
import '../database/dao/vault_dao.dart';
import '../models/category_model.dart';
import '../models/settings_model.dart';
import '../models/vault_account_model.dart';

class VaultLocalDataSource {
  VaultLocalDataSource()
      : _vaultDao = VaultDao(AppDatabase()),
        _settingsDao = SettingsDao(AppDatabase()),
        _categoriesDao = CategoriesDao(AppDatabase());

  final VaultDao _vaultDao;
  final SettingsDao _settingsDao;
  final CategoriesDao _categoriesDao;

  Future<void> insertAccount(VaultAccountModel account) async {
    await _vaultDao.insertAccount(account.toMap());
  }

  Future<void> updateAccount(VaultAccountModel account) async {
    await _vaultDao.updateAccount(account.toMap());
  }

  Future<void> deleteAccount(String id) async {
    await _vaultDao.deleteAccount(id);
  }

  Future<List<VaultAccountModel>> getAllAccounts() async {
    final maps = await _vaultDao.getAllAccounts();
    return maps.map(VaultAccountModel.fromMap).toList();
  }

  Future<List<VaultAccountModel>> getAccountsByCategory(String category) async {
    final maps = await _vaultDao.getAccountsByCategory(category);
    return maps.map(VaultAccountModel.fromMap).toList();
  }

  Future<List<VaultAccountModel>> getFavoriteAccounts() async {
    final maps = await _vaultDao.getFavoriteAccounts();
    return maps.map(VaultAccountModel.fromMap).toList();
  }

  Future<VaultAccountModel?> getAccountById(String id) async {
    final map = await _vaultDao.getAccountById(id);
    return map != null ? VaultAccountModel.fromMap(map) : null;
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    await _vaultDao.toggleFavorite(id, isFavorite);
  }

  Future<void> replaceAllAccounts(List<VaultAccountModel> accounts) async {
    await _vaultDao.replaceAllAccounts(
      accounts.map((account) => account.toMap()).toList(),
    );
  }

  Future<void> clearAllAccounts() async {
    await _vaultDao.clearAllAccounts();
  }

  Future<SettingsModel?> getSettings() async {
    final map = await _settingsDao.getSettings();
    return map != null ? SettingsModel.fromMap(map) : null;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _settingsDao.setBiometricEnabled(enabled);
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    await _settingsDao.setAutoLockMinutes(minutes);
  }

  Future<void> setThemeMode(String mode) async {
    await _settingsDao.setThemeMode(mode);
  }

  Future<List<CategoryModel>> getAllCategories() async {
    final maps = await _categoriesDao.getAllCategories();
    return maps.map(CategoryModel.fromMap).toList();
  }

  Future<void> insertCategory(CategoryModel category) async {
    await _categoriesDao.insertCategory(category.toMap());
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _categoriesDao.updateCategory(category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesDao.deleteCategory(id);
  }
}
