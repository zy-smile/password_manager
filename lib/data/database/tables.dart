class VaultAccounts {
  static const String tableName = 'vault_accounts';
  static const String id = 'id';
  static const String title = 'platform_name';
  static const String website = 'website';
  static const String username = 'username';
  static const String usernameEncrypted = 'username_encrypted';
  static const String passwordEncrypted = 'password_encrypted';
  static const String note = 'note';
  static const String noteEncrypted = 'note_encrypted';
  static const String category = 'category';
  static const String isFavorite = 'is_favorite';
  static const String encryptionVersion = 'encryption_version';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $id TEXT PRIMARY KEY,
      $title TEXT NOT NULL,
      $website TEXT DEFAULT '',
      $username TEXT,
      $usernameEncrypted TEXT,
      $passwordEncrypted TEXT NOT NULL,
      $note TEXT,
      $noteEncrypted TEXT,
      $category TEXT DEFAULT '其他',
      $isFavorite INTEGER DEFAULT 0,
      $encryptionVersion INTEGER DEFAULT 1,
      $createdAt INTEGER NOT NULL,
      $updatedAt INTEGER NOT NULL
    )
  ''';
}

class Settings {
  static const String tableName = 'settings';
  static const String id = 'id';
  static const String biometricEnabled = 'biometric_enabled';
  static const String autoLockMinutes = 'auto_lock_minutes';
  static const String themeMode = 'theme_mode';

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $id INTEGER PRIMARY KEY,
      $biometricEnabled INTEGER DEFAULT 0,
      $autoLockMinutes INTEGER DEFAULT 5,
      $themeMode TEXT DEFAULT 'system'
    )
  ''';
}

class Categories {
  static const String tableName = 'categories';
  static const String id = 'id';
  static const String name = 'name';
  static const String icon = 'icon';
  static const String sortOrder = 'sort_order';

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $id TEXT PRIMARY KEY,
      $name TEXT NOT NULL,
      $icon TEXT DEFAULT 'folder',
      $sortOrder INTEGER DEFAULT 0
    )
  ''';
}
