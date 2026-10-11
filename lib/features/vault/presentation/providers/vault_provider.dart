import 'package:flutter/foundation.dart';

import 'package:password_manager/features/vault/backup/backup_service.dart';
import 'package:password_manager/features/vault/data/datasource/vault_local_datasource.dart';
import 'package:password_manager/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:password_manager/features/vault/domain/entities/vault_account.dart';
import 'auth_provider.dart';

class VaultProvider extends ChangeNotifier {
  VaultProvider({VaultRepositoryImpl? repository, BackupService? backupService})
      : _repository = repository ?? VaultRepositoryImpl(VaultLocalDataSource()),
        _backupService = backupService ?? BackupService();

  final VaultRepositoryImpl _repository;
  final BackupService _backupService;

  List<VaultAccount> _accounts = [];
  List<VaultAccount> _allAccounts = [];
  AuthProvider? _auth;
  String? _sessionKey;
  int _generation = 0;
  int _loadRequest = 0;
  bool _disposed = false;
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
    if (_auth != auth) {
      _auth?.removeListener(_authChanged);
      _auth = auth;
      _auth?.addListener(_authChanged);
    }
    _syncAuth();
  }

  void _authChanged() {
    _syncAuth();
    notifyListeners();
  }

  void _syncAuth() {
    final key = _auth?.encryptionKey;
    if (key == _sessionKey) return;
    _generation++;
    _sessionKey = key;
    _accounts = [];
    _allAccounts = [];
    _searchQuery = null;
    _selectedCategory = null;
    _errorMessage = null;
    _isLoading = false;
    if (key != null) {
      _repository.setEncryptionKey(key);
    } else {
      _repository.clearEncryptionKey();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _auth?.removeListener(_authChanged);
    _repository.clearEncryptionKey();
    _accounts = [];
    _allAccounts = [];
    super.dispose();
  }

  void _checkSession(int generation) {
    if (_disposed || generation != _generation || _sessionKey == null) {
      throw Exception('会话已锁定，请重新解锁');
    }
  }

  void _applyFilters() {
    final query = _searchQuery?.trim().toLowerCase() ?? '';
    _accounts = _allAccounts.where((account) {
      final categoryMatches = _selectedCategory == null ||
          _selectedCategory!.isEmpty ||
          account.category == _selectedCategory;
      return categoryMatches &&
          (query.isEmpty ||
              account.title.toLowerCase().contains(query) ||
              account.website.toLowerCase().contains(query) ||
              account.username.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> loadAccounts() async {
    if (_sessionKey == null || _disposed) return;
    final generation = _generation;
    final request = ++_loadRequest;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final accounts = await _repository.getAllAccounts();
      if (_disposed || generation != _generation || request != _loadRequest) {
        return;
      }
      _allAccounts = accounts;
      _applyFilters();
    } catch (error) {
      if (_disposed || generation != _generation || request != _loadRequest) {
        return;
      }
      _accounts = [];
      _allAccounts = [];
      _errorMessage = error.toString();
    } finally {
      if (!_disposed && generation == _generation && request == _loadRequest) {
        _isLoading = false;
        notifyListeners();
      }
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

  Future<BackupExportResult> exportBackup(String backupPassword) async {
    final generation = _generation;
    final accounts = await _repository.getAllAccounts();
    _checkSession(generation);
    final result = await _backupService.exportBackup(
      accounts: accounts,
      backupPassword: backupPassword,
    );
    await loadBackups();
    return result;
  }

  Future<void> importBackup(String filePath, {String? backupPassword}) async {
    final generation = _generation;
    final accounts = await _backupService.importBackup(
      filePath: filePath,
      encryptionKey: _repository.currentEncryptionKey,
      backupPassword: backupPassword,
    );
    _checkSession(generation);
    await _repository.replaceAllAccounts(accounts);
    await loadAccounts();
    await loadBackups();
  }

  Future<void> clearAllData() async {
    await _repository.clearAllData();
    await _backupService.deleteAllBackups();
    _accounts = [];
    _allAccounts = [];
    await loadBackups();
    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = null;
    _selectedCategory = null;
    _applyFilters();
    notifyListeners();
  }
}
