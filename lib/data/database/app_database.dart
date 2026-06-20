import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'tables.dart';

class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _initDesktopDatabase();
    }

    final databasesPath = await getDatabasesPath();
    return openDatabase(
      join(databasesPath, 'password_vault.db'),
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<Database> _initDesktopDatabase() async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    databaseFactory = factory;
    final databasesPath = await factory.getDatabasesPath();

    return openDatabase(
      join(databasesPath, 'password_vault.db'),
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(VaultAccounts.createTable);
    await db.execute(Settings.createTable);
    await db.execute(Categories.createTable);
    await _ensureDefaultCategories(db);
    await _ensureDefaultSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        VaultAccounts.tableName,
        VaultAccounts.website,
        "TEXT DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        VaultAccounts.tableName,
        VaultAccounts.usernameEncrypted,
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        VaultAccounts.tableName,
        VaultAccounts.noteEncrypted,
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        VaultAccounts.tableName,
        VaultAccounts.encryptionVersion,
        'INTEGER DEFAULT 1',
      );
    }

    await _ensureDefaultCategories(db);
    await _ensureDefaultSettings(db);
  }

  Future<void> _onOpen(Database db) async {
    await _ensureDefaultCategories(db);
    await _ensureDefaultSettings(db);
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnName,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (!exists) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $definition',
      );
    }
  }

  Future<void> _ensureDefaultCategories(Database db) async {
    const categories = [
      {'id': '1', 'name': '社交', 'icon': 'users', 'sort_order': 0},
      {'id': '2', 'name': '工作', 'icon': 'briefcase', 'sort_order': 1},
      {'id': '3', 'name': '金融', 'icon': 'credit-card', 'sort_order': 2},
      {'id': '4', 'name': '游戏', 'icon': 'gamepad', 'sort_order': 3},
      {'id': '5', 'name': '开发', 'icon': 'code', 'sort_order': 4},
      {'id': '6', 'name': '购物', 'icon': 'shopping-cart', 'sort_order': 5},
      {'id': '7', 'name': '其他', 'icon': 'folder', 'sort_order': 6},
    ];

    for (final category in categories) {
      await db.insert(
        Categories.tableName,
        category,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _ensureDefaultSettings(Database db) async {
    await db.insert(
      Settings.tableName,
      {
        Settings.id: 1,
        Settings.biometricEnabled: 0,
        Settings.autoLockMinutes: 5,
        Settings.themeMode: 'system',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
