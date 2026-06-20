import '../app_database.dart';
import '../tables.dart';

class VaultDao {
  VaultDao(this._db);

  final AppDatabase _db;

  Future<int> insertAccount(Map<String, dynamic> account) async {
    final db = await _db.database;
    return db.insert(VaultAccounts.tableName, account);
  }

  Future<int> updateAccount(Map<String, dynamic> account) async {
    final db = await _db.database;
    return db.update(
      VaultAccounts.tableName,
      account,
      where: '${VaultAccounts.id} = ?',
      whereArgs: [account[VaultAccounts.id]],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await _db.database;
    return db.delete(
      VaultAccounts.tableName,
      where: '${VaultAccounts.id} = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final db = await _db.database;
    return db.query(
      VaultAccounts.tableName,
      orderBy:
          '${VaultAccounts.isFavorite} DESC, ${VaultAccounts.updatedAt} DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAccountsByCategory(
      String category) async {
    final db = await _db.database;
    return db.query(
      VaultAccounts.tableName,
      where: '${VaultAccounts.category} = ?',
      whereArgs: [category],
      orderBy:
          '${VaultAccounts.isFavorite} DESC, ${VaultAccounts.updatedAt} DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getFavoriteAccounts() async {
    final db = await _db.database;
    return db.query(
      VaultAccounts.tableName,
      where: '${VaultAccounts.isFavorite} = ?',
      whereArgs: [1],
      orderBy: '${VaultAccounts.updatedAt} DESC',
    );
  }

  Future<Map<String, dynamic>?> getAccountById(String id) async {
    final db = await _db.database;
    final results = await db.query(
      VaultAccounts.tableName,
      where: '${VaultAccounts.id} = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> toggleFavorite(String id, bool isFavorite) async {
    final db = await _db.database;
    return db.update(
      VaultAccounts.tableName,
      {
        VaultAccounts.isFavorite: isFavorite ? 1 : 0,
        VaultAccounts.updatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: '${VaultAccounts.id} = ?',
      whereArgs: [id],
    );
  }

  Future<void> replaceAllAccounts(List<Map<String, dynamic>> accounts) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(VaultAccounts.tableName);
      for (final account in accounts) {
        await txn.insert(VaultAccounts.tableName, account);
      }
    });
  }

  Future<void> clearAllAccounts() async {
    final db = await _db.database;
    await db.delete(VaultAccounts.tableName);
  }
}
