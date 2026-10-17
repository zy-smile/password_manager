package com.example.password_manager

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import androidx.test.uiautomator.UiSelector
import com.example.password_manager.core.SecureStore
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.regex.Pattern

@RunWith(AndroidJUnit4::class)
class ExternalExportTest {
    @get:Rule val compose = createEmptyComposeRule()

    @Test fun systemSaveDialogExportsToDownloadsEvenWithImmediateLock() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        context.deleteDatabase("password_vault.db")
        SecureStore(context).clear()
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            compose.waitUntil(20_000) { compose.onAllNodesWithText("创建保险箱").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText("主密码").performTextInput("ExportMaster123")
            compose.onNodeWithText("确认主密码").performTextInput("ExportMaster123")
            compose.onNodeWithText("创建保险箱").performScrollTo().performClick()
            compose.waitUntil(20_000) { compose.onAllNodesWithText("设置").fetchSemanticsNodes().isNotEmpty() }
            lateinit var model: AppViewModel
            scenario.onActivity {
                model = ViewModelProvider(it)[AppViewModel::class.java]
                model.setLockMinutes(0)
            }
            compose.waitUntil(10_000) { model.state.lockMinutes == 0 && !model.state.busy }
            compose.onNodeWithText("设置").performClick()
            compose.onNodeWithText("导出加密备份").performScrollTo().performClick()
            compose.onNodeWithText("备份密码").performTextInput("IndependentBackup123")
            compose.onNodeWithText("确认备份密码").performTextInput("IndependentBackup123")
            compose.onNodeWithText("选择保存位置").performClick()

            val device = UiDevice.getInstance(instrumentation)
            assertTrue("System save dialog did not open", device.wait(Until.hasObject(By.pkg(Pattern.compile(".*documentsui"))), 15_000))
            device.waitForIdle()
            device.findObject(By.desc(Pattern.compile("(?i)show roots|open navigation drawer|显示根目录")))?.click()
            device.waitForIdle()
            // Target the drawer entry, not the identically titled toolbar
            // which is replaced while the navigation drawer animates.
            val downloads = device.findObject(UiSelector().resourceId("android:id/title").textMatches("(?i)Downloads|下载"))
            assertTrue(downloads.waitForExists(5_000))
            downloads.click()
            device.waitForIdle()
            val name = device.wait(Until.findObject(By.clazz("android.widget.EditText")), 10_000)
            assertNotNull("Filename input missing", name)
            name.text = "native-export-retention.json"
            val save = device.wait(Until.findObject(By.text(Pattern.compile("(?i)SAVE|保存"))), 10_000)
            assertNotNull("System save button missing", save)
            save.click()
            compose.waitUntil(20_000) { model.state.message?.contains("备份已保存到所选位置") == true }
            assertFalse("Leaving for the picker must still lock the app", model.state.unlocked)
            compose.onNodeWithText("解锁").assertExists()
        }
    }
}
