import 'package:flutter/foundation.dart';

import '../../core/secure_storage/secure_storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider() : _secureStorage = SecureStorageService();

  final SecureStorageService _secureStorage;

  int _autoLockMinutes = 5;

  int get autoLockMinutes => _autoLockMinutes;

  Future<void> loadSettings() async {
    _autoLockMinutes = await _secureStorage.getAutoLockMinutes();
    notifyListeners();
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    _autoLockMinutes = minutes;
    await _secureStorage.saveAutoLockMinutes(minutes);
    notifyListeners();
  }

  void resetState() {
    _autoLockMinutes = 5;
    notifyListeners();
  }
}
