package com.example.password_manager.core

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SecureStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("native_assistant", Context.MODE_PRIVATE)
    private val keystore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun deviceKey(): SecretKey {
        val alias = "personal_assistant_device_v1"
        return (keystore.getKey(alias, null) as? SecretKey) ?: KeyGenerator.getInstance("AES", "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build()); generateKey()
        }
    }
    fun record(): String? {
        val value = prefs.getString("master_record", null) ?: return null
        val json = JSONObject(value)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, deviceKey(), GCMParameterSpec(128, Crypto.decode(json.getString("iv"))))
        return String(cipher.doFinal(Crypto.decode(json.getString("cipherText"))), Charsets.UTF_8)
    }
    fun saveRecord(record: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, deviceKey())
        val value = JSONObject().put("iv", Crypto.encode(cipher.iv))
            .put("cipherText", Crypto.encode(cipher.doFinal(record.toByteArray(Charsets.UTF_8)))).toString()
        check(prefs.edit().putString("master_record", value).commit()) { "无法保存主密码配置" }
    }
    var lockMinutes: Int
        get() = prefs.getInt("lock_minutes", 5).takeIf { it in listOf(0,1,5,10,30) } ?: 5
        set(value) { require(value in listOf(0,1,5,10,30)); check(prefs.edit().putInt("lock_minutes", value).commit()) }
    var failures: Int
        get() = prefs.getInt("failures", 0)
        set(value) { check(prefs.edit().putInt("failures", value).commit()) }
    var lockedUntil: Long
        get() = prefs.getLong("locked_until", 0)
        set(value) { check(prefs.edit().putLong("locked_until", value).commit()) }
    val biometricEnabled get() = prefs.contains("biometric_record")

    fun prepareBiometric(encrypt: Boolean): Cipher {
        val alias = "personal_assistant_biometric_v1"
        if (encrypt) {
            if (keystore.containsAlias(alias)) keystore.deleteEntry(alias)
            val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(true).setInvalidatedByBiometricEnrollment(true).setKeySize(256)
            if (Build.VERSION.SDK_INT >= 30) spec.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            else spec.setUserAuthenticationValidityDurationSeconds(-1)
            KeyGenerator.getInstance("AES", "AndroidKeyStore").apply { init(spec.build()); generateKey() }
        }
        val key = keystore.getKey(alias, null) as? SecretKey ?: error("请使用主密码解锁并重新启用生物识别")
        return Cipher.getInstance("AES/GCM/NoPadding").apply {
            if (encrypt) init(Cipher.ENCRYPT_MODE, key) else {
                val record = JSONObject(requireNotNull(prefs.getString("biometric_record", null)))
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, Crypto.decode(record.getString("iv"))))
            }
        }
    }
    fun saveBiometric(cipher: Cipher, dataKey: ByteArray) {
        val record = JSONObject().put("iv", Crypto.encode(cipher.iv))
            .put("cipherText", Crypto.encode(cipher.doFinal(dataKey))).toString()
        check(prefs.edit().putString("biometric_record", record).commit())
    }
    fun readBiometric(cipher: Cipher): ByteArray {
        val record = JSONObject(requireNotNull(prefs.getString("biometric_record", null)))
        return cipher.doFinal(Crypto.decode(record.getString("cipherText"))).also { require(it.size == 32) }
    }
    fun disableBiometric() {
        check(prefs.edit().remove("biometric_record").commit())
        if (keystore.containsAlias("personal_assistant_biometric_v1")) keystore.deleteEntry("personal_assistant_biometric_v1")
    }
    fun clear() {
        disableBiometric()
        check(prefs.edit().clear().commit())
    }
}
