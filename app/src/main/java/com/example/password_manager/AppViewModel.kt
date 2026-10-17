package com.example.password_manager

import android.app.Application
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.password_manager.core.BackupCodec
import com.example.password_manager.core.SecureStore
import com.example.password_manager.data.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.atomic.AtomicLong
import javax.crypto.Cipher

data class AppState(
    val ready: Boolean = false, val firstLaunch: Boolean = false, val unlocked: Boolean = false,
    val busy: Boolean = false, val fatal: String? = null, val message: String? = null,
    val accounts: List<Credential> = emptyList(), val clothing: List<Clothing> = emptyList(),
    val lockMinutes: Int = 5, val biometricEnabled: Boolean = false,
    val verifiedAccount: String? = null, val session: Long = 0
)

class AppViewModel(application: Application) : AndroidViewModel(application) {
    private val context get() = getApplication<Application>()
    private val database = AppDatabase(application)
    val secureStore = SecureStore(application)
    private val auth = AuthRepository(secureStore, database)
    var state by mutableStateOf(AppState()); private set
    private var dataKey: ByteArray? = null
    private val epoch = AtomicLong(0)
    private val mutex = Mutex()
    private val handler = Handler(Looper.getMainLooper())
    private var backgroundAt: Long? = null
    private var lastInteraction = SystemClock.elapsedRealtime()
    private val idleLock = Runnable { if (state.unlocked) lock() }
    private var lastClipboard: String? = null
    private var clipboardClear: Runnable? = null

    init { initialize() }
    fun initialize() {
        viewModelScope.launch {
            state = state.copy(busy = true, fatal = null)
            try {
                val info = withContext(Dispatchers.IO) { Triple(auth.isFirstLaunch(), secureStore.lockMinutes, secureStore.biometricEnabled) }
                state = state.copy(ready = true, firstLaunch = info.first, lockMinutes = info.second, biometricEnabled = info.third)
            } catch (e: Exception) { state = state.copy(ready = true, fatal = e.message ?: "无法读取安全配置") }
            finally { state = state.copy(busy = false) }
        }
    }
    fun message(value: String) { state = state.copy(message = value) }
    fun dismissMessage() { state = state.copy(message = null) }
    private fun ensureSession(token: Long) { check(epoch.get() == token && dataKey != null) { "会话已锁定，请重新解锁" } }
    private fun work(protected: Boolean = true, action: suspend (Long) -> Unit) {
        if (state.busy || (protected && !state.unlocked)) return
        val token = epoch.get()
        state = state.copy(busy = true)
        viewModelScope.launch {
            try { mutex.withLock { if (protected) ensureSession(token); action(token) } }
            catch (e: Exception) { if (epoch.get() == token) message(e.message ?: "操作失败") }
            finally { if (epoch.get() == token) state = state.copy(busy = false) }
        }
    }
    fun unlock(password: String, confirmation: String = "") = work(false) { token ->
        val first = state.firstLaunch
        require(!first || password == confirmation) { "两次输入的主密码不一致" }
        val key = withContext(Dispatchers.IO) { if(first) auth.setup(password) else auth.authenticate(password) }
        if (epoch.get() != token) { key.fill(0); return@work }
        openSession(key, token)
    }
    private suspend fun openSession(key: ByteArray, token: Long) {
        try {
            val records = withContext(Dispatchers.IO) { database.accounts(key) to database.clothing() }
            if(epoch.get() != token) { key.fill(0); return }
            dataKey?.fill(0); dataKey = key
            state = state.copy(unlocked = true, firstLaunch = false, accounts = records.first, clothing = records.second,
                verifiedAccount = null, biometricEnabled = secureStore.biometricEnabled, session = token)
            touch()
        } catch (e: Exception) { key.fill(0); throw e }
    }
    fun lock() {
        epoch.incrementAndGet(); handler.removeCallbacks(idleLock)
        dataKey?.fill(0); dataKey = null
        state = state.copy(unlocked = false, busy = false, accounts = emptyList(), clothing = emptyList(),
            verifiedAccount = null, session = epoch.get())
        clearClipboardIfUnchanged()
    }
    fun touch() {
        lastInteraction = SystemClock.elapsedRealtime()
        handler.removeCallbacks(idleLock)
        if (state.unlocked && state.lockMinutes > 0 && backgroundAt == null) {
            handler.postDelayed(idleLock, state.lockMinutes * 60_000L)
        }
    }
    fun onBackground() {
        if (backgroundAt == null) backgroundAt = SystemClock.elapsedRealtime()
        handler.removeCallbacks(idleLock)
        if(state.lockMinutes == 0) lock()
    }
    fun onForeground() {
        val since = backgroundAt
        backgroundAt = null
        if (state.unlocked && since != null && SystemClock.elapsedRealtime() - since >= state.lockMinutes * 60_000L) lock()
        else if (state.unlocked && state.lockMinutes > 0 && SystemClock.elapsedRealtime() - lastInteraction >= state.lockMinutes * 60_000L) lock()
        else touch()
    }
    fun setLockMinutes(minutes: Int) = work { token ->
        withContext(Dispatchers.IO) { ensureSession(token); secureStore.lockMinutes = minutes }
        ensureSession(token); state = state.copy(lockMinutes = minutes); touch()
    }
    private suspend fun refresh(token: Long) {
        val key = requireNotNull(dataKey).clone()
        try {
            val records = withContext(Dispatchers.IO) { database.accounts(key) to database.clothing() }
            ensureSession(token); state = state.copy(accounts = records.first, clothing = records.second, verifiedAccount = null)
        } finally { key.fill(0) }
    }
    fun saveAccount(account: Credential, done: () -> Unit) = work { token ->
        require(account.title.isNotBlank() && account.username.isNotBlank() && account.password.isNotEmpty()) { "请填写平台名称、账号和密码" }
        val key = requireNotNull(dataKey).clone()
        try { withContext(Dispatchers.IO) { ensureSession(token); database.save(account.copy(updatedAt = System.currentTimeMillis()), key) { ensureSession(token) } } }
        finally { key.fill(0) }
        refresh(token); done(); message("账号已保存")
    }
    fun deleteAccount(account: Credential, done: () -> Unit) = work { token ->
        withContext(Dispatchers.IO) { ensureSession(token); database.deleteCredential(account.id) }
        refresh(token); done(); message("账号已删除")
    }
    fun favorite(account: Credential) = saveAccount(account.copy(favorite = !account.favorite)) {}
    fun verifyAccount(id: String, password: String) = work { token ->
        val key = withContext(Dispatchers.IO) { auth.authenticate(password) }
        try { ensureSession(token); state = state.copy(verifiedAccount = id) } finally { key.fill(0) }
    }
    fun verifiedBiometric(id: String) { if(state.unlocked) state = state.copy(verifiedAccount = id) }
    fun hidePassword() { state = state.copy(verifiedAccount = null) }
    fun changePassword(old: String, new: String, confirmation: String, done: () -> Unit) = work { token ->
        require(new == confirmation) { "两次输入的主密码不一致" }
        val key = requireNotNull(dataKey).clone()
        try { withContext(Dispatchers.IO) { ensureSession(token); auth.changePassword(old, new, key) { ensureSession(token) } } }
        finally { key.fill(0) }
        ensureSession(token); done(); message("主密码已更新，原有备份不受影响")
    }
    fun completeBiometric(cipher: Cipher, enable: Boolean, callbackEpoch: Long, verifiedId: String? = null) = work(!enable && state.unlocked) { token ->
        check(callbackEpoch == epoch.get()) { "验证已过期，请重试" }
        if (enable) {
            ensureSession(token)
            secureStore.saveBiometric(cipher, requireNotNull(dataKey))
            state = state.copy(biometricEnabled = true); message("生物识别已启用")
        } else {
            val key = secureStore.readBiometric(cipher)
            if (state.unlocked) {
                key.fill(0)
                if (verifiedId != null) state = state.copy(verifiedAccount = verifiedId)
            } else openSession(key, token)
        }
    }
    fun disableBiometric() = work { token ->
        withContext(Dispatchers.IO) { ensureSession(token); secureStore.disableBiometric() }
        ensureSession(token); state = state.copy(biometricEnabled = false)
    }
    fun copy(value: String) {
        if (!state.unlocked) return
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("个人助手", value).apply {
            description.extras = android.os.PersistableBundle().apply { putBoolean("android.content.extra.IS_SENSITIVE", true) }
        })
        clipboardClear?.let(handler::removeCallbacks)
        lastClipboard = value
        clipboardClear = Runnable { clearClipboardIfUnchanged() }.also { handler.postDelayed(it, 30_000) }
        message("已复制，30 秒后自动清空")
    }
    private fun clearClipboardIfUnchanged() {
        clipboardClear?.let(handler::removeCallbacks); clipboardClear = null
        val copied = lastClipboard ?: return
        lastClipboard = null
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (clipboard.primaryClip?.getItemAt(0)?.text?.toString() == copied) {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }
    private fun photoDirectory() = File(context.filesDir, "wardrobe_photos").apply { mkdirs() }
    private fun deletePhoto(path: String) {
        if (path.isBlank()) return
        val file = File(path).canonicalFile
        val roots = listOf(photoDirectory(), File(context.applicationInfo.dataDir, "app_flutter/wardrobe_photos"))
        if (roots.any { file.path.startsWith(it.canonicalPath + File.separator) }) file.delete()
    }
    fun saveClothing(item: Clothing, photo: Uri?, done: () -> Unit) = work { token ->
        require(item.name.isNotBlank()) { "请填写衣服名称" }
        withContext(Dispatchers.IO) {
            ensureSession(token)
            val newFile = if (photo != null) File(photoDirectory(), "${java.util.UUID.randomUUID()}.jpg") else null
            try {
                if(newFile != null) {
                    val bytes = context.contentResolver.openInputStream(photo!!)?.use { it.readBytesLimited(15 * 1024 * 1024) }
                        ?: error("无法读取图片")
                    newFile.writeBytes(bytes)
                }
                ensureSession(token)
                database.save(item.copy(photoPath = newFile?.path ?: item.photoPath, updatedAt = System.currentTimeMillis()))
            } catch (e: Exception) { newFile?.delete(); throw e }
            if (newFile != null) deletePhoto(item.photoPath)
        }
        refresh(token); done(); message("衣服已保存")
    }
    fun deleteClothing(item: Clothing, done: () -> Unit) = work { token ->
        withContext(Dispatchers.IO) { ensureSession(token); database.deleteClothing(item.id); deletePhoto(item.photoPath) }
        refresh(token); done(); message("衣服已删除")
    }
    fun favorite(item: Clothing) = saveClothing(item.copy(favorite = !item.favorite), null) {}
    fun exportBackup(password: String, result: (Uri) -> Unit) = work { token ->
        val accounts = state.accounts
        val file = withContext(Dispatchers.IO) {
            val text = BackupCodec.encode(accounts, password)
            ensureSession(token)
            File(context.cacheDir, "backups").apply { mkdirs() }.let { dir ->
                dir.listFiles()?.forEach { it.delete() }
                File(dir, "personal-assistant-${System.currentTimeMillis()}.json").apply { writeText(text) }
            }
        }
        ensureSession(token)
        result(androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.files", file))
    }
    fun importBackup(uri: Uri, password: String, done: () -> Unit) = work { token ->
        val key = requireNotNull(dataKey).clone()
        try {
            withContext(Dispatchers.IO) {
                val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytesLimited(BackupCodec.MAX_BYTES) }
                    ?: error("无法读取备份文件")
                val accounts = BackupCodec.decode(String(bytes, Charsets.UTF_8), password, key)
                ensureSession(token); database.replace(accounts, key) { ensureSession(token) }
            }
        } finally { key.fill(0) }
        refresh(token); done(); message("密码箱恢复成功")
    }
    fun clearAll() = work { token ->
        withContext(Dispatchers.IO) {
            ensureSession(token)
            database.clear()
            photoDirectory().listFiles()?.forEach { it.delete() }
            File(context.applicationInfo.dataDir, "app_flutter/wardrobe_photos").listFiles()?.forEach { it.delete() }
            File(context.applicationInfo.dataDir, "app_flutter/backups").listFiles()?.forEach { it.delete() }
            File(context.cacheDir, "backups").listFiles()?.forEach { it.delete() }
            secureStore.clear()
        }
        lock(); state = state.copy(firstLaunch = true, lockMinutes = 5, biometricEnabled = false)
    }
    override fun onCleared() {
        dataKey?.fill(0); handler.removeCallbacksAndMessages(null); database.close()
        super.onCleared()
    }
}

private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
    val output = java.io.ByteArrayOutputStream()
    val buffer = ByteArray(8192)
    while(true) {
        val count = read(buffer)
        if(count == -1) break
        require(output.size() + count <= limit) { "文件过大" }
        output.write(buffer, 0, count)
    }
    return output.toByteArray()
}
