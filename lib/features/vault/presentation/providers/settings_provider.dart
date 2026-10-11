import 'package:flutter/foundation.dart';

import 'package:password_manager/core/secure_storage/secure_storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  final SecureStorageService _secureStorage;

  int _autoLockMinutes = 5;

  int get autoLockMinutes => _autoLockMinutes;

  Future<void> loadSettings() async {
    _autoLockMinutes = await _secureStorage.getAutoLockMinutes();
    notifyListeners();
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    if (![0, 1, 5, 10, 30].contains(minutes)) {
      throw ArgumentError('Invalid lock timeout');
    }
    await _secureStorage.saveAutoLockMinutes(minutes);
    _autoLockMinutes = minutes;
    notifyListeners();
  }

  void resetState() {
    _autoLockMinutes = 5;
    notifyListeners();
  }
}
