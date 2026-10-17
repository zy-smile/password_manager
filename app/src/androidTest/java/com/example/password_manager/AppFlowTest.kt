package com.example.password_manager

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.password_manager.core.SecureStore
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppFlowTest {
    @get:Rule val compose = createEmptyComposeRule()
    @Test fun setupCreateRevealLockUnlockAndWardrobe() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        context.deleteDatabase("password_vault.db")
        SecureStore(context).clear()
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            compose.waitUntil(20_000) { compose.onAllNodesWithText("创建保险箱").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("主密码").performTextInput("NativeMaster123")
            compose.onNodeWithText("确认主密码").performTextInput("NativeMaster123")
            compose.onNodeWithText("创建保险箱").performScrollTo().performClick()
            compose.waitUntil(20_000) { compose.onAllNodesWithText("＋").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("＋").performClick()
            compose.onNodeWithText("平台名称 *").performTextInput("Native Test")
            compose.onNodeWithText("登录账号 *").performTextInput("native-user")
            compose.onNodeWithText("登录密码 *").performTextInput("secretTest123")
            compose.onNodeWithText("保存账号").performScrollTo().performClick()
            compose.waitUntil(20_000) { compose.onAllNodesWithText("Native Test").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("Native Test").performClick()
            compose.onNodeWithText("secretTest123").assertDoesNotExist()
            compose.onNodeWithText("验证并查看密码").performScrollTo().performClick()
            compose.onNodeWithText("主密码").performTextInput("NativeMaster123")
            compose.onNodeWithText("验证").performClick()
            compose.waitUntil(20_000) { compose.onAllNodesWithText("secretTest123").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("返回").performClick()
            compose.onNodeWithText("锁定").performClick()
            compose.onNodeWithText("secretTest123").assertDoesNotExist()
            compose.onNodeWithText("主密码").performTextInput("NativeMaster123")
            compose.onNodeWithText("解锁").performScrollTo().performClick()
            compose.waitUntil(20_000) { compose.onAllNodesWithText("衣橱").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("衣橱").performClick()
            compose.onNodeWithText("＋").performClick()
            compose.onNodeWithText("衣服名称 *").performScrollTo().performTextInput("蓝色外套")
            compose.onNodeWithText("保存衣服").performScrollTo().performClick()
            compose.waitUntil(20_000) { compose.onAllNodesWithText("蓝色外套").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("蓝色外套").assertExists()
            lateinit var model: AppViewModel
            scenario.onActivity { activity ->
                model = ViewModelProvider(activity)[AppViewModel::class.java]
                model.setLockMinutes(0)
            }
            compose.waitUntil(10_000) { model.state.lockMinutes == 0 }
            scenario.moveToState(Lifecycle.State.CREATED)
            scenario.moveToState(Lifecycle.State.RESUMED)
            compose.waitUntil(10_000) { compose.onAllNodesWithText("解锁").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("蓝色外套").assertDoesNotExist()
        }
    }
}
