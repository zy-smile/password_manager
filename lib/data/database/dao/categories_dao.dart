import '../app_database.dart';
import '../tables.dart';

class CategoriesDao {
  final AppDatabase _db;

  CategoriesDao(this._db);

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await _db.database;
    return await db.query(
      Categories.tableName,
      orderBy: '${Categories.sortOrder} ASC',
    );
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await _db.database;
    return await db.insert(Categories.tableName, category);
  }

  Future<int> updateCategory(Map<String, dynamic> category) async {
    final db = await _db.database;
    return await db.update(
      Categories.tableName,
      category,
      where: '${Categories.id} = ?',
      whereArgs: [category[Categories.id]],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await _db.database;
    return await db.delete(
      Categories.tableName,
      where: '${Categories.id} = ?',
      whereArgs: [id],
    );
  }
}
