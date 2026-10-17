package com.example.password_manager.core

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract

/** Writes only to a document explicitly created by the system save dialog. */
class DocumentBackupWriter(private val context: Context) {
    fun write(uri: Uri, encryptedBytes: ByteArray) {
        require(uri.scheme == "content" && DocumentsContract.isDocumentUri(context, uri)) {
            "请选择系统文件管理器中的保存位置"
        }
        require(uri.authority != "${context.packageName}.files") { "请选择应用以外的保存位置" }
        require(encryptedBytes.isNotEmpty() && encryptedBytes.size <= BackupCodec.MAX_BYTES)
        try {
            val stream = context.contentResolver.openOutputStream(uri, "wt") ?: error("无法打开所选文件")
            stream.use { it.write(encryptedBytes); it.flush() }
        } catch (e: Exception) {
            // ACTION_CREATE_DOCUMENT creates a new document, never an existing file.
            // Remove a partial export if the provider supports deletion.
            runCatching { DocumentsContract.deleteDocument(context.contentResolver, uri) }
            throw IllegalStateException("备份保存失败，请检查目录权限或剩余空间后重试", e)
        }
    }
}
