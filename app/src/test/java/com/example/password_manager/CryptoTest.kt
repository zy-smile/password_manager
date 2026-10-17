package com.example.password_manager

import com.example.password_manager.core.Crypto
import com.example.password_manager.core.BackupCodec
import com.example.password_manager.data.Credential
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class CryptoTest {
    @Test fun pbkdf2MatchesPublishedVector() {
        val key = Crypto.derive("password", "salt".toByteArray(), 1)
        assertEquals("120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b", key.joinToString("") { "%02x".format(it) })
    }
    @Test fun aesMatchesNistGcmVector() {
        // AES-256-GCM NIST test: zero key, zero nonce, 16 zero plaintext bytes.
        val payload = Crypto.encrypt("\u0000".repeat(16), ByteArray(32), iv = ByteArray(12))
        assertEquals("cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919",
            Crypto.decode(payload.getString("cipherText")).joinToString("") { "%02x".format(it) })
    }
    @Test fun passwordChangePreservesDataKeyAndRejectsOldPassword() {
        val key = Crypto.randomBytes(32)
        val old = Crypto.wrapMaster("master123", key)
        val new = Crypto.wrapMaster("newMaster456", Crypto.unwrapMaster("master123", old))
        assertArrayEquals(key, Crypto.unwrapMaster("newMaster456", new))
        assertThrows(Exception::class.java) { Crypto.unwrapMaster("master123", new) }
    }
    @Test fun backupRoundTripDoesNotDependOnDeviceKey() {
        val records = listOf(Credential(title = "Example", username = "user", password = "secret", note = "note"))
        val encoded = BackupCodec.encode(records, "backup123")
        assertFalse(encoded.contains("secret"))
        assertEquals(records, BackupCodec.decode(encoded, "backup123"))
    }
    @Test fun tamperedBackupAndWrongPasswordAreRejected() {
        val json = JSONObject(BackupCodec.encode(listOf(Credential(title="Example")), "backup123"))
        assertThrows(Exception::class.java) { BackupCodec.decode(json.toString(), "wrong") }
        val bytes = Crypto.decode(json.getString("cipherText"))
        bytes[0] = (bytes[0].toInt() xor 1).toByte()
        json.put("cipherText", Crypto.encode(bytes))
        assertThrows(Exception::class.java) { BackupCodec.decode(json.toString(), "backup123") }
    }
    @Test fun invalidVersionsAndKdfAreRejected() {
        val json = JSONObject(BackupCodec.encode(emptyList(), "backup123"))
        json.put("version", "1.0")
        assertThrows(Exception::class.java) { BackupCodec.decode(json.toString(), "backup123") }
        json.put("version", "2.0")
        json.put("iterations", 1)
        assertThrows(Exception::class.java) { BackupCodec.decode(json.toString(), "backup123") }
        json.put("version", "99.0")
        assertThrows(Exception::class.java) { BackupCodec.decode(json.toString(), "backup123") }
    }
    @Test fun generatorIncludesAllSelectedGroups() {
        repeat(50) {
            val password = Crypto.generatePassword(24)
            assertEquals(24, password.length)
            assertTrue(password.any(Char::isUpperCase)); assertTrue(password.any(Char::isLowerCase))
            assertTrue(password.any(Char::isDigit)); assertTrue(password.any { !it.isLetterOrDigit() })
        }
        assertThrows(IllegalArgumentException::class.java) { Crypto.generatePassword(20, false, false, false, false) }
    }
    @Test fun passwordRulesRequireLengthAndNumbersWithoutTrimming() {
        assertThrows(IllegalArgumentException::class.java) { Crypto.validatePassword("short1") }
        assertThrows(IllegalArgumentException::class.java) { Crypto.validatePassword("abcdefgh") }
        Crypto.validatePassword(" password1 ")
    }
    @Test fun invalidBackupRecordsAreRejected() {
        assertThrows(Exception::class.java) { Credential.fromJson(JSONObject().put("id", "bad")) }
    }
}
