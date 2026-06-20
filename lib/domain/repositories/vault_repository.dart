import '../entities/vault_account.dart';

abstract class VaultRepository {
  Future<void> addAccount(VaultAccount account);
  Future<void> updateAccount(VaultAccount account);
  Future<void> deleteAccount(String id);
  Future<List<VaultAccount>> getAllAccounts();
  Future<List<VaultAccount>> searchAccounts(String query);
  Future<List<VaultAccount>> getAccountsByCategory(String category);
  Future<List<VaultAccount>> getFavoriteAccounts();
  Future<VaultAccount?> getAccountById(String id);
  Future<void> toggleFavorite(String id, bool isFavorite);
  Future<bool?> getBiometricEnabled();
  Future<void> setBiometricEnabled(bool enabled);
  Future<int?> getAutoLockMinutes();
  Future<void> setAutoLockMinutes(int minutes);
  Future<List<String>> getAllCategories();
}
