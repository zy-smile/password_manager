package com.example.password_manager.core

import org.json.JSONObject
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

object Crypto {
    const val ITERATIONS = 150_000
    private val random = SecureRandom()
    fun randomBytes(size: Int) = ByteArray(size).also(random::nextBytes)
    fun encode(bytes: ByteArray): String = Base64.getEncoder().encodeToString(bytes)
    fun decode(value: String): ByteArray = Base64.getMimeDecoder().decode(value)
    fun sha256(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes)

    // UTF-8 password bytes match the previous Dart implementation, including Unicode.
    fun derive(password: String, salt: ByteArray, iterations: Int = ITERATIONS): ByteArray {
        require(iterations in 1..1_000_000) { "不支持的密钥派生参数" }
        val mac = Mac.getInstance("HmacSHA256")
        val passwordBytes = password.toByteArray(Charsets.UTF_8)
        mac.init(SecretKeySpec(if (passwordBytes.isEmpty()) byteArrayOf(0) else passwordBytes, "HmacSHA256"))
        var u = mac.doFinal(salt + ByteBuffer.allocate(4).putInt(1).array())
        val result = u.clone()
        repeat(iterations - 1) {
            u = mac.doFinal(u)
            for (i in result.indices) result[i] = (result[i].toInt() xor u[i].toInt()).toByte()
        }
        passwordBytes.fill(0)
        return result
    }

    fun encrypt(text: String, key: ByteArray, aad: String = "", iv: ByteArray = randomBytes(12)): JSONObject {
        require(key.size == 32 && iv.size == 12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        cipher.updateAAD(aad.toByteArray(Charsets.UTF_8))
        return JSONObject().put("version", 2).put("algorithm", "AES-256-GCM")
            .put("iv", encode(iv)).put("cipherText", encode(cipher.doFinal(text.toByteArray(Charsets.UTF_8))))
    }

    fun decrypt(payload: JSONObject, key: ByteArray, aad: String = ""): String {
        require(payload.optString("algorithm", "AES-256-GCM") == "AES-256-GCM")
        val iv = decode(payload.getString("iv"))
        require(iv.size == 12 && key.size == 32) { "加密参数无效" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        cipher.updateAAD(aad.toByteArray(Charsets.UTF_8))
        return String(cipher.doFinal(decode(payload.getString("cipherText"))), Charsets.UTF_8)
    }
    fun decrypt(payload: String, key: ByteArray) = decrypt(JSONObject(payload), key)

    fun decryptLegacy(value: String, password: String): String {
        val bytes = decode(value)
        require(bytes.size > 16)
        val key = ByteArray(32) { i -> ((password.getOrNull(i)?.code ?: 0) xor (i * 17)).toByte() }
        return try {
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(bytes.copyOfRange(0, 16)))
            String(cipher.doFinal(bytes.copyOfRange(16, bytes.size)), Charsets.UTF_8)
        } finally { key.fill(0) }
    }

    fun validatePassword(password: String) {
        require(password.length >= 8 && password.any { it in '0'..'9' }) { "主密码至少 8 位，且包含数字" }
    }
    fun wrapMaster(password: String, dataKey: ByteArray): String {
        val salt = randomBytes(16)
        val wrappingKey = derive(password, salt)
        return try {
            JSONObject().put("version", 3).put("kdf", "PBKDF2-SHA256").put("iterations", ITERATIONS)
                .put("salt", encode(salt)).put("wrappedKey", encrypt(encode(dataKey), wrappingKey,
                    "personal-assistant-master-key-v3").toString()).toString()
        } finally { wrappingKey.fill(0) }
    }
    fun unwrapMaster(password: String, record: String): ByteArray {
        val json = JSONObject(record)
        require(json.getInt("version") == 3 && json.getString("kdf") == "PBKDF2-SHA256" &&
            json.getInt("iterations") == ITERATIONS) { "不支持的主密码配置" }
        val salt = decode(json.getString("salt"))
        require(salt.size == 16)
        val wrappingKey = derive(password, salt)
        return try {
            decode(decrypt(JSONObject(json.getString("wrappedKey")), wrappingKey,
                "personal-assistant-master-key-v3")).also { require(it.size == 32) }
        } finally { wrappingKey.fill(0) }
    }

    fun generatePassword(length: Int = 20, upper: Boolean = true, lower: Boolean = true,
                         numbers: Boolean = true, symbols: Boolean = true): String {
        val pools = buildList {
            if (upper) add("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            if (lower) add("abcdefghijklmnopqrstuvwxyz")
            if (numbers) add("0123456789")
            if (symbols) add("!@#$%^&*()_+-=[]{};:,.?")
        }
        require(pools.isNotEmpty() && length in 8..64) { "请选择字符类型和有效长度" }
        val all = pools.joinToString("")
        val chars = pools.map { it[random.nextInt(it.length)] }.toMutableList()
        while (chars.size < length) chars.add(all[random.nextInt(all.length)])
        for (i in chars.lastIndex downTo 1) {
            val j = random.nextInt(i + 1)
            val c = chars[i]; chars[i] = chars[j]; chars[j] = c
        }
        return chars.joinToString("")
    }
}
