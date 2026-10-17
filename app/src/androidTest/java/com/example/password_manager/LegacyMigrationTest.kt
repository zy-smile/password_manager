package com.example.password_manager

import android.content.ContentValues
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.password_manager.core.Crypto
import com.example.password_manager.core.SecureStore
import com.example.password_manager.data.AppDatabase
import com.example.password_manager.data.AuthRepository
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.security.KeyPairGenerator
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

@RunWith(AndroidJUnit4::class)
class LegacyMigrationTest {
    @Test fun oldFlutterPreferencesAndV3DatabaseUpgradeInPlace() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val fixture = JSONObject(instrumentation.context.assets.open("flutter-compat.json").bufferedReader().use { it.readText() })
        context.deleteDatabase("password_vault.db")
        SecureStore(context).clear()
        val alias = context.packageName + ".FlutterSecureStoragePluginKey"
        val keystore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if(keystore.containsAlias(alias)) keystore.deleteEntry(alias)
        val pair = KeyPairGenerator.getInstance("RSA", "AndroidKeyStore").apply {
            initialize(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_DECRYPT or KeyProperties.PURPOSE_ENCRYPT)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_PKCS1).setDigests(KeyProperties.DIGEST_SHA256).build())
        }.generateKeyPair()
        val aes = SecretKeySpec(Crypto.randomBytes(16), "AES")
        val rsa = Cipher.getInstance("RSA/ECB/PKCS1Padding").apply { init(Cipher.WRAP_MODE, pair.public) }
        context.getSharedPreferences("FlutterSecureKeyStorage", Context.MODE_PRIVATE).edit()
            .putString("VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK", Crypto.encode(rsa.wrap(aes))).commit()
        val iv = Crypto.randomBytes(16)
        val cbc = Cipher.getInstance("AES/CBC/PKCS7Padding").apply { init(Cipher.ENCRYPT_MODE, aes, IvParameterSpec(iv)) }
        context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE).edit()
            .putString("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_auth_state_v3",
                Crypto.encode(iv + cbc.doFinal(fixture.getString("masterRecord").toByteArray()))).commit()
        AppDatabase(context).apply {
            writableDatabase.insertOrThrow("vault_accounts", null, ContentValues().apply {
                put("id", "legacy"); put("platform_name", "旧版平台"); put("website", "")
                put("username_encrypted", fixture.getString("field")); put("password_encrypted", fixture.getString("field"))
                put("note_encrypted", fixture.getString("field")); put("encryption_version", 2)
                put("created_at", 1L); put("updated_at", 2L)
            })
            writableDatabase.version = 3
            close()
        }
        val database = AppDatabase(context)
        val store = SecureStore(context)
        try {
            val auth = AuthRepository(store, database)
            assertFalse(auth.isFirstLaunch())
            val key = auth.authenticate(fixture.getString("password"))
            assertArrayEquals(Crypto.decode(fixture.getString("dataKey")), key)
            val account = database.accounts(key).single()
            assertEquals("旧版平台", account.title)
            assertEquals("旧版账号与密码 Secret 123", account.password)
            assertEquals(4, database.readableDatabase.version)
            assertTrue(store.hasNativeRecord)
        } finally { database.close(); context.deleteDatabase("password_vault.db"); store.clear() }
    }
}
