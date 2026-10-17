package com.example.password_manager

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.example.password_manager.ui.AssistantApp

class MainActivity : FragmentActivity() {
    private val model: AppViewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        enableEdgeToEdge()
        setContent { AssistantApp(model, ::authenticateBiometric) }
    }
    override fun onStart() { super.onStart(); model.onForeground() }
    override fun onStop() { if(!isChangingConfigurations) model.onBackground(); super.onStop() }
    override fun onUserInteraction() { super.onUserInteraction(); model.touch() }
    private fun authenticateBiometric(enable: Boolean, accountId: String?) {
        if (BiometricManager.from(this).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) != BiometricManager.BIOMETRIC_SUCCESS) {
            model.message("请先在系统设置中录入安全级别足够的指纹或面容"); return
        }
        val token = model.state.session
        try {
            val cipher = model.secureStore.prepareBiometric(enable)
            val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    result.cryptoObject?.cipher?.let { model.completeBiometric(it, enable, token, accountId) }
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (errorCode !in listOf(BiometricPrompt.ERROR_NEGATIVE_BUTTON, BiometricPrompt.ERROR_USER_CANCELED, BiometricPrompt.ERROR_CANCELED)) {
                        model.message(errString.toString())
                    }
                }
            })
            val info = BiometricPrompt.PromptInfo.Builder()
                .setTitle(if(enable) "启用生物识别" else if(accountId == null) "解锁个人助手" else "验证身份以查看密码")
                .setSubtitle("密钥由 Android Keystore 保护")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("使用主密码").build()
            prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
        } catch (e: Exception) { model.message(e.message ?: "生物识别不可用，请使用主密码") }
    }
}
