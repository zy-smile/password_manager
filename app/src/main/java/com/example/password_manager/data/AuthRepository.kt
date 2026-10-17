package com.example.password_manager.data

import com.example.password_manager.core.Crypto
import com.example.password_manager.core.SecureStore
import java.security.MessageDigest

class AuthRepository(val store: SecureStore, private val database: AppDatabase) {
    fun isFirstLaunch(): Boolean {
        val hasAuth = store.record() != null
        check(hasAuth || database.accountCount() == 0L) { "认证信息缺失，请清除应用数据后重新设置" }
        return !hasAuth
    }
    fun setup(password: String): ByteArray {
        check(isFirstLaunch()) { "已设置主密码" }
        Crypto.validatePassword(password)
        val key = Crypto.randomBytes(32)
        try { store.saveRecord(Crypto.wrapMaster(password, key)); return key }
        catch (e: Exception) { key.fill(0); throw e }
    }
    fun authenticate(password: String): ByteArray {
        require(System.currentTimeMillis() >= store.lockedUntil) { "尝试过多，请在 30 秒冷却后重试" }
        val record = requireNotNull(store.record()) { "请先设置主密码" }
        val key = try { Crypto.unwrapMaster(password, record) }
            catch (e: Exception) { fail(); throw IllegalArgumentException("主密码错误或认证配置损坏", e) }
        store.failures = 0; store.lockedUntil = 0
        return key
    }
    private fun fail() {
        val count = store.failures + 1
        if (count >= 5) { store.lockedUntil = System.currentTimeMillis() + 30_000; store.failures = 0 }
        else store.failures = count
    }
    fun changePassword(old: String, new: String, expectedKey: ByteArray, beforeWrite: () -> Unit = {}) {
        Crypto.validatePassword(new)
        val key = authenticate(old)
        try {
            check(MessageDigest.isEqual(key, expectedKey)) { "会话已过期" }
            val record = Crypto.wrapMaster(new, key)
            beforeWrite()
            store.saveRecord(record)
        } finally { key.fill(0) }
    }
}
