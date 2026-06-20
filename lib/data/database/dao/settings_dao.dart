import '../app_database.dart';
import '../tables.dart';

class SettingsDao {
  final AppDatabase _db;

  SettingsDao(this._db);

  Future<Map<String, dynamic>?> getSettings() async {
    final db = await _db.database;
    final results = await db.query(Settings.tableName);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await _db.database;
    return await db.update(
      Settings.tableName,
      settings,
      where: '${Settings.id} = ?',
      whereArgs: [1],
    );
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await updateSettings({Settings.biometricEnabled: enabled ? 1 : 0});
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    await updateSettings({Settings.autoLockMinutes: minutes});
  }

  Future<void> setThemeMode(String mode) async {
    await updateSettings({Settings.themeMode: mode});
  }
}
