package com.example.password_manager

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.password_manager.core.Crypto
import com.example.password_manager.core.SecureStore
import com.example.password_manager.data.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DatabaseTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    @Test fun encryptedDatabaseCrudAndBackupReplacement() {
        // Instrumentation runs on a disposable emulator, never a user's device.
        context.deleteDatabase("password_vault.db")
        val db = AppDatabase(context)
        val key = Crypto.randomBytes(32)
        val original = Credential(title="测试平台", username="private-user", password="private-secret", note="private-note")
        try {
            db.save(original, key)
            assertEquals(original, db.accounts(key).single())
            db.readableDatabase.rawQuery("SELECT username,password_encrypted,note FROM vault_accounts", null).use {
                it.moveToFirst(); assertEquals("", it.getString(0)); assertFalse(it.getString(1).contains("private-secret")); assertEquals("", it.getString(2))
            }
            db.replace(listOf(original.copy(title="恢复平台")), key)
            assertEquals("恢复平台", db.accounts(key).single().title)
            db.deleteCredential(original.id)
            assertEquals(0L, db.accountCount())
        } finally { db.close(); context.deleteDatabase("password_vault.db") }
    }
    @Test fun wardrobeCrudAndSecureMasterRecord() {
        context.deleteDatabase("password_vault.db")
        val db = AppDatabase(context)
        try {
            val clothing = Clothing(name="蓝色外套", seasons=listOf("春", "秋"), favorite=true)
            db.save(clothing)
            assertEquals(clothing, db.clothing().single())
            db.deleteClothing(clothing.id); assertTrue(db.clothing().isEmpty())
            val store = SecureStore(context)
            val key = Crypto.randomBytes(32)
            val record = Crypto.wrapMaster("master123", key)
            store.saveRecord(record)
            assertEquals(record, store.record())
            val raw = context.getSharedPreferences("native_assistant", Context.MODE_PRIVATE).getString("master_record", "")!!
            assertFalse(raw.contains("wrappedKey"))
            store.clear()
        } finally { db.close(); context.deleteDatabase("password_vault.db") }
    }
}
