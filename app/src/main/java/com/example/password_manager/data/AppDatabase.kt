package com.example.password_manager.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.example.password_manager.core.Crypto

class AppDatabase(context: Context) : SQLiteOpenHelper(context, "password_vault.db", null, 4) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""CREATE TABLE vault_accounts(id TEXT PRIMARY KEY, platform_name TEXT NOT NULL,
            website TEXT DEFAULT '', username TEXT, username_encrypted TEXT, password_encrypted TEXT NOT NULL,
            note TEXT, note_encrypted TEXT, category TEXT DEFAULT '其他', is_favorite INTEGER DEFAULT 0,
            encryption_version INTEGER DEFAULT 2, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)""")
        createWardrobe(db)
        db.execSQL("CREATE TABLE categories(id TEXT PRIMARY KEY, name TEXT NOT NULL, icon TEXT DEFAULT 'folder', sort_order INTEGER DEFAULT 0)")
        vaultCategories.forEachIndexed { i, name ->
            db.execSQL("INSERT INTO categories(id,name,sort_order) VALUES(?,?,?)", arrayOf<Any>((i + 1).toString(), name, i))
        }
        db.execSQL("CREATE TABLE settings(id INTEGER PRIMARY KEY, biometric_enabled INTEGER DEFAULT 0, auto_lock_minutes INTEGER DEFAULT 5, theme_mode TEXT DEFAULT 'system')")
        indexes(db)
    }
    private fun createWardrobe(db: SQLiteDatabase) {
        db.execSQL("""CREATE TABLE IF NOT EXISTS wardrobe_items(id TEXT PRIMARY KEY, name TEXT NOT NULL,
            category TEXT DEFAULT '上衣', seasons TEXT DEFAULT '', color TEXT DEFAULT '', brand TEXT DEFAULT '',
            photo_path TEXT DEFAULT '', note TEXT DEFAULT '', is_favorite INTEGER DEFAULT 0,
            purchase_date INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)""")
    }
    private fun indexes(db: SQLiteDatabase) {
        db.execSQL("CREATE INDEX IF NOT EXISTS vault_sort ON vault_accounts(is_favorite DESC,updated_at DESC)")
        db.execSQL("CREATE INDEX IF NOT EXISTS wardrobe_sort ON wardrobe_items(is_favorite DESC,updated_at DESC)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        check(oldVersion >= 4) { "不支持旧数据库，请清除应用数据后重新设置" }
        indexes(db)
    }
    fun accountCount(): Long = readableDatabase.rawQuery("SELECT COUNT(*) FROM vault_accounts", null)
        .use { it.moveToFirst(); it.getLong(0) }
    private fun Cursor.text(name: String) = getString(getColumnIndexOrThrow(name)) ?: ""
    private fun Cursor.long(name: String) = getLong(getColumnIndexOrThrow(name))
    private fun Cursor.credential(key: ByteArray): Credential {
        check(getInt(getColumnIndexOrThrow("encryption_version")) == 2) { "不支持的账号加密格式" }
        return Credential(text("id"), text("platform_name"), text("website"),
            Crypto.decrypt(text("username_encrypted"), key), Crypto.decrypt(text("password_encrypted"), key),
            Crypto.decrypt(text("note_encrypted"), key), text("category"),
            long("is_favorite") == 1L, long("created_at"), long("updated_at"))
    }
    fun accounts(key: ByteArray): List<Credential> = readableDatabase.query("vault_accounts", null,
        null, null, null, null, "is_favorite DESC, updated_at DESC").use { c ->
        buildList { while (c.moveToNext()) add(c.credential(key)) }
    }
    private fun credentialValues(account: Credential, key: ByteArray) = ContentValues().apply {
        put("id", account.id); put("platform_name", account.title); put("website", account.website)
        put("username", ""); put("note", "")
        put("username_encrypted", Crypto.encrypt(account.username, key).toString())
        put("password_encrypted", Crypto.encrypt(account.password, key).toString())
        put("note_encrypted", Crypto.encrypt(account.note, key).toString())
        put("category", account.category); put("is_favorite", if (account.favorite) 1 else 0)
        put("encryption_version", 2); put("created_at", account.createdAt); put("updated_at", account.updatedAt)
    }
    fun save(account: Credential, key: ByteArray, beforeWrite: () -> Unit = {}) {
        val values = credentialValues(account, key)
        beforeWrite()
        writableDatabase.insertWithOnConflict("vault_accounts", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            .also { check(it != -1L) { "保存账号失败" } }
    }
    fun deleteCredential(id: String) { writableDatabase.delete("vault_accounts", "id=?", arrayOf(id)) }
    fun replace(accounts: List<Credential>, key: ByteArray, beforeWrite: () -> Unit = {}) {
        val values = accounts.map { credentialValues(it, key) }
        beforeWrite()
        writableDatabase.beginTransaction()
        try {
            writableDatabase.delete("vault_accounts", null, null)
            values.forEach { writableDatabase.insertOrThrow("vault_accounts", null, it) }
            writableDatabase.setTransactionSuccessful()
        } finally { writableDatabase.endTransaction() }
    }
    fun clothing(): List<Clothing> = readableDatabase.query("wardrobe_items", null, null, null, null, null,
        "is_favorite DESC, updated_at DESC").use { c ->
        buildList { while(c.moveToNext()) add(Clothing(c.text("id"), c.text("name"), c.text("category"),
            c.text("seasons").split(';').filter { it.isNotEmpty() }, c.text("color"), c.text("brand"),
            c.text("photo_path"), c.text("note"), c.long("is_favorite") == 1L,
            if (c.isNull(c.getColumnIndexOrThrow("purchase_date"))) null else c.long("purchase_date"),
            c.long("created_at"), c.long("updated_at"))) }
    }
    fun save(item: Clothing) {
        val values = ContentValues().apply {
            put("id", item.id); put("name", item.name); put("category", item.category)
            put("seasons", item.seasons.joinToString(";")); put("color", item.color); put("brand", item.brand)
            put("photo_path", item.photoPath); put("note", item.note); put("is_favorite", if(item.favorite) 1 else 0)
            put("purchase_date", item.purchaseDate); put("created_at", item.createdAt); put("updated_at", item.updatedAt)
        }
        writableDatabase.insertWithOnConflict("wardrobe_items", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            .also { check(it != -1L) { "保存衣服失败" } }
    }
    fun deleteClothing(id: String) { writableDatabase.delete("wardrobe_items", "id=?", arrayOf(id)) }
    fun clear() {
        writableDatabase.beginTransaction()
        try {
            writableDatabase.delete("vault_accounts", null, null)
            writableDatabase.delete("wardrobe_items", null, null)
            writableDatabase.delete("settings", null, null)
            writableDatabase.setTransactionSuccessful()
        } finally { writableDatabase.endTransaction() }
    }
}
