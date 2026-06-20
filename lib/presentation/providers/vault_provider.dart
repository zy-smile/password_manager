import 'package:flutter/foundation.dart';

import '../../core/backup/backup_service.dart';
import '../../data/datasource/vault_local_datasource.dart';
import '../../data/repositories/vault_repository_impl.dart';
import '../../domain/entities/vault_account.dart';
import 'auth_provider.dart';

class VaultProvider extends ChangeNotifier {
  VaultProvider()
      : _repository = VaultRepositoryImpl(VaultLocalDataSource()),
        _backupService = BackupService();

  final VaultRepositoryImpl _repository;
  final BackupService _backupService;

  List<VaultAccount> _accounts = [];
  List<String> _categories = [];
  List<BackupFileInfo> _backups = [];
  String? _backupDirectoryPath;
  String? _searchQuery;
  String? _selectedCategory;
  String? _errorMessage;
  bool _isLoading = false;

  List<VaultAccount> get accounts => _accounts;
  List<String> get categories => _categories;
  List<BackupFileInfo> get backups => _backups;
  String? get backupDirectoryPath => _backupDirectoryPath;
  String? get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider? auth) {
    if (auth?.encryptionKey != null) {
      _repository.setEncryptionKey(auth!.encryptionKey!);
    } else {
      _repository.clearEncryptionKey();
    }
  }

  Future<void> loadAccounts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var accounts = await _repository.getAllAccounts();

      final query = _searchQuery?.trim();
      if (query != null && query.isNotEmpty) {
        final normalized = query.toLowerCase();
        accounts = accounts.where((account) {
          return account.title.toLowerCase().contains(normalized) ||
              account.website.toLowerCase().contains(normalized) ||
              account.username.toLowerCase().contains(normalized);
        }).toList();
      }

      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        accounts = accounts
            .where((account) => account.category == _selectedCategory)
            .toList();
      }

      _accounts = accounts;
    } catch (error) {
      _accounts = [];
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _repository.getAllCategories();
    } catch (_) {
      _categories = const [];
    }
    notifyListeners();
  }

  Future<void> loadBackups() async {
    try {
      _backups = await _backupService.listBackups();
      _backupDirectoryPath = await _backupService.getBackupDirectoryPath();
    } catch (_) {
      _backups = const [];
      _backupDirectoryPath = null;
    }
    notifyListeners();
  }

  Future<void> addAccount(VaultAccount account) async {
    await _repository.addAccount(account);
    await loadAccounts();
  }

  Future<void> updateAccount(VaultAccount account) async {
    await _repository.updateAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _repository.deleteAccount(id);
    await loadAccounts();
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    await _repository.toggleFavorite(id, isFavorite);
    await loadAccounts();
  }

  Future<BackupExportResult> exportBackup() async {
    final accounts = await _repository.getAllAccounts();
    final result = await _backupService.exportBackup(
      accounts: accounts,
      encryptionKey: _repository.currentEncryptionKey,
    );
    await loadBackups();
    return result;
  }

  Future<void> importBackup(String filePath) async {
    final accounts = await _backupService.importBackup(
      filePath: filePath,
      encryptionKey: _repository.currentEncryptionKey,
    );
    await _repository.replaceAllAccounts(accounts);
    await loadAccounts();
    await loadBackups();
  }

  Future<void> clearAllData() async {
    await _repository.clearAllData();
    await _backupService.deleteAllBackups();
    _accounts = [];
    await loadBackups();
    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = null;
    _selectedCategory = null;
    notifyListeners();
  }
}
