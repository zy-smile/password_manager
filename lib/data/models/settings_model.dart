class SettingsModel {
  final bool biometricEnabled;
  final int autoLockMinutes;
  final String themeMode;

  SettingsModel({
    required this.biometricEnabled,
    required this.autoLockMinutes,
    required this.themeMode,
  });

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      biometricEnabled: map['biometric_enabled'] == 1,
      autoLockMinutes: map['auto_lock_minutes'] ?? 5,
      themeMode: map['theme_mode'] ?? 'system',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'auto_lock_minutes': autoLockMinutes,
      'theme_mode': themeMode,
    };
  }
}
