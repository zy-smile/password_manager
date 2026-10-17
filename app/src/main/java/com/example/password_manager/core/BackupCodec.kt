package com.example.password_manager.core

import com.example.password_manager.data.Credential
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

object BackupCodec {
    const val MAX_BYTES = 32 * 1024 * 1024
    private fun aad(salt: String) = "personal-assistant-backup:2.0:PBKDF2-SHA256:150000:$salt"
    fun encode(accounts: List<Credential>, password: String): String {
        require(password.length >= 8) { "备份密码至少需要 8 位" }
        val salt = Crypto.encode(Crypto.randomBytes(16))
        val key = Crypto.derive(password, Crypto.decode(salt))
        return try {
            val payload = JSONObject().put("accounts", JSONArray(accounts.map { it.json() }))
            val encrypted = Crypto.encrypt(payload.toString(), key, aad(salt))
            JSONObject().put("version", "2.0").put("exportTime", Instant.now().toString())
                .put("encryption", "AES-256-GCM").put("kdf", "PBKDF2-SHA256")
                .put("iterations", Crypto.ITERATIONS).put("salt", salt)
                .put("iv", encrypted.getString("iv")).put("cipherText", encrypted.getString("cipherText"))
                .toString(2).also { require(it.toByteArray().size <= MAX_BYTES) { "备份文件过大" } }
        } finally { key.fill(0) }
    }
    fun decode(text: String, password: String): List<Credential> {
        require(text.toByteArray().size <= MAX_BYTES) { "备份文件过大" }
        val json = JSONObject(text)
        val version = json.getString("version")
        require(version == "2.0" && json.getString("encryption") == "AES-256-GCM") { "不支持的备份版本或算法" }
        require(json.getString("kdf") == "PBKDF2-SHA256" &&
            json.getInt("iterations") == Crypto.ITERATIONS) { "不支持的密钥派生参数" }
        val salt = json.getString("salt")
        require(Crypto.decode(salt).size == 16)
        require(password.isNotEmpty()) { "请输入备份密码" }
        val key = Crypto.derive(password, Crypto.decode(salt))
        val plain = try { Crypto.decrypt(json, key, aad(salt)) }
            catch (e: Exception) { throw IllegalArgumentException("备份密码错误或文件已损坏", e) }
            finally { key.fill(0) }
        val accounts = JSONObject(plain).getJSONArray("accounts")
        val result = (0 until accounts.length()).map { Credential.fromJson(accounts.getJSONObject(it)) }
        require(result.map { it.id }.toSet().size == result.size) { "备份中存在重复账号" }
        return result
    }
}
