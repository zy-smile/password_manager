import 'package:password_manager/core/database/app_database.dart';
import 'package:password_manager/core/database/tables.dart';

class WardrobeDao {
  WardrobeDao(this._db);

  final AppDatabase _db;

  Future<void> insertItem(Map<String, dynamic> item) async {
    final db = await _db.database;
    await db.insert(WardrobeItems.tableName, item);
  }

  Future<void> updateItem(Map<String, dynamic> item) async {
    final db = await _db.database;
    await db.update(
      WardrobeItems.tableName,
      item,
      where: '${WardrobeItems.id} = ?',
      whereArgs: [item[WardrobeItems.id]],
    );
  }

  Future<void> deleteItem(String id) async {
    final db = await _db.database;
    await db.delete(
      WardrobeItems.tableName,
      where: '${WardrobeItems.id} = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await _db.database;
    return db.query(
      WardrobeItems.tableName,
      orderBy:
          '${WardrobeItems.isFavorite} DESC, ${WardrobeItems.updatedAt} DESC',
    );
  }

  Future<void> clearAllItems() async {
    final db = await _db.database;
    await db.delete(WardrobeItems.tableName);
  }
}
