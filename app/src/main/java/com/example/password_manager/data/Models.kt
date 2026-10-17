package com.example.password_manager.data

import org.json.JSONObject
import java.time.Instant
import java.util.UUID

val vaultCategories = listOf("社交", "工作", "金融", "游戏", "开发", "购物", "其他")
val clothingCategories = listOf("上衣", "裤装", "裙装", "外套", "鞋履", "配饰", "其他")
val seasons = listOf("春", "夏", "秋", "冬")

data class Credential(
    val id: String = UUID.randomUUID().toString(), val title: String = "",
    val website: String = "", val username: String = "", val password: String = "",
    val note: String = "", val category: String = "其他", val favorite: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(), val updatedAt: Long = System.currentTimeMillis()
) {
    fun json(): JSONObject = JSONObject().put("id", id).put("title", title).put("website", website)
        .put("username", username).put("password", password).put("note", note).put("category", category)
        .put("favorite", favorite).put("createdAt", Instant.ofEpochMilli(createdAt).toString())
        .put("updatedAt", Instant.ofEpochMilli(updatedAt).toString())
    companion object {
        fun fromJson(json: JSONObject): Credential {
            listOf("id", "title", "website", "username", "password", "note", "category", "createdAt", "updatedAt")
                .forEach { require(json.get(it) is String) { "备份账号字段无效：$it" } }
            require(json.get("favorite") is Boolean && json.getString("id").isNotBlank())
            fun time(value: String): Long = runCatching { Instant.parse(value).toEpochMilli() }.getOrElse {
                // Dart emits local timestamps without an offset; use the device's local zone.
                java.time.LocalDateTime.parse(value).atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
            }
            return Credential(json.getString("id"), json.getString("title"), json.getString("website"),
                json.getString("username"), json.getString("password"), json.getString("note"),
                json.getString("category"), json.getBoolean("favorite"), time(json.getString("createdAt")),
                time(json.getString("updatedAt")))
        }
    }
}

data class Clothing(
    val id: String = UUID.randomUUID().toString(), val name: String = "", val category: String = "上衣",
    val seasons: List<String> = emptyList(), val color: String = "", val brand: String = "",
    val photoPath: String = "", val note: String = "", val favorite: Boolean = false,
    val purchaseDate: Long? = null, val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)
