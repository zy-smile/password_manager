@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.example.password_manager.ui

import android.app.DatePickerDialog
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.example.password_manager.AppViewModel
import com.example.password_manager.BuildConfig
import com.example.password_manager.core.Crypto
import com.example.password_manager.data.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

private val LocalInteraction = staticCompositionLocalOf<() -> Unit> { {} }

@Composable
fun AssistantApp(vm: AppViewModel, biometric: (Boolean, String?) -> Unit) {
    val state = vm.state
    val snackbar = remember { SnackbarHostState() }
    val colors = if (isSystemInDarkTheme()) darkColorScheme(primary = Color(0xFFB7C4FF))
        else lightColorScheme(primary = Color(0xFF5265BD), secondary = Color(0xFF576280), background = Color(0xFFF7F8FC), surface = Color(0xFFF7F8FC))
    MaterialTheme(colorScheme = colors) {
        CompositionLocalProvider(LocalInteraction provides vm::touch) {
        LaunchedEffect(state.message) {
            state.message?.let { message -> snackbar.showSnackbar(message); if(vm.state.message == message) vm.dismissMessage() }
        }
        Scaffold(snackbarHost = { SnackbarHost(snackbar) }) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                when {
                    !state.ready -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                    state.fatal != null -> Column(Modifier.align(Alignment.Center).padding(28.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text("无法读取安全配置", style = MaterialTheme.typography.headlineSmall)
                        Text(state.fatal)
                        Button(onClick = vm::initialize, enabled = !state.busy) { Text("重试") }
                    }
                    !state.unlocked -> key(state.session) { LockScreen(vm, biometric) }
                    else -> key(state.session) { Home(vm, biometric) }
                }
                if(state.busy) LinearProgressIndicator(Modifier.fillMaxWidth().align(Alignment.TopCenter))
            }
        }
        }
    }
}

@Composable
private fun LockScreen(vm: AppViewModel, biometric: (Boolean, String?) -> Unit) {
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    val state = vm.state
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(28.dp),
        verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.primaryContainer) {
            Text("锁", Modifier.padding(26.dp), fontSize = 38.sp, color = MaterialTheme.colorScheme.primary)
        }
        Spacer(Modifier.height(24.dp))
        Text("个人助手", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Text(if(state.firstLaunch) "设置主密码，开启你的私人空间" else "欢迎回来，请解锁你的私人空间",
            Modifier.padding(vertical = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        SecretField("主密码", password, { password = it }, enabled = !state.busy)
        if(state.firstLaunch) {
            SecretField("确认主密码", confirmation, { confirmation = it }, enabled = !state.busy)
            Text("至少 8 位且包含数字。请牢记主密码。", Modifier.padding(8.dp), style = MaterialTheme.typography.bodySmall)
        }
        Button(onClick = { vm.unlock(password, confirmation) }, enabled = !state.busy && password.isNotEmpty(),
            modifier = Modifier.fillMaxWidth().padding(top = 20.dp).height(52.dp)) {
            Text(if(state.firstLaunch) "创建保险箱" else "解锁")
        }
        if(!state.firstLaunch && state.biometricEnabled) TextButton(onClick = { biometric(false, null) }, enabled = !state.busy) { Text("使用指纹 / 面容解锁") }
        Text("本地存储 · 原生 Android · 隐私保护", Modifier.padding(top = 24.dp),
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun Home(vm: AppViewModel, biometric: (Boolean, String?) -> Unit) {
    var tab by remember { mutableIntStateOf(0) }
    var editingAccount by remember { mutableStateOf<Credential?>(null) }
    var editingClothing by remember { mutableStateOf<Clothing?>(null) }
    var detail by remember { mutableStateOf<Credential?>(null) }
    when {
        editingAccount != null -> AccountEditor(editingAccount!!, vm) { editingAccount = null }
        editingClothing != null -> ClothingEditor(editingClothing!!, vm) { editingClothing = null }
        detail != null -> AccountDetail(detail!!, vm, biometric, onEdit = { editingAccount = it; detail = null },
            onBack = { detail = null; vm.hidePassword() })
        else -> Scaffold(
            topBar = { TopAppBar(title = { Text(listOf("密码箱", "我的衣橱", "设置")[tab], fontWeight = FontWeight.Bold) },
                actions = { TextButton(onClick = vm::lock) { Text("锁定") } }) },
            bottomBar = { NavigationBar {
                listOf("密码箱" to "锁", "衣橱" to "衣", "设置" to "设").forEachIndexed { index, item ->
                    NavigationBarItem(selected = tab == index, onClick = { tab = index },
                        icon = { Text(item.second, fontWeight = FontWeight.Bold) }, label = { Text(item.first) })
                }
            } },
            floatingActionButton = {
                if(tab < 2) FloatingActionButton(onClick = {
                    if(tab == 0) editingAccount = Credential() else editingClothing = Clothing()
                }) { Text("＋", fontSize = 30.sp) }
            }
        ) { padding ->
            Box(Modifier.padding(padding)) {
                when(tab) {
                    0 -> VaultList(vm, { detail = it }, vm::favorite)
                    1 -> WardrobeList(vm, { editingClothing = it })
                    else -> Settings(vm, biometric)
                }
            }
        }
    }
}

@Composable
private fun VaultList(vm: AppViewModel, open: (Credential) -> Unit, favorite: (Credential) -> Unit) {
    var query by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("全部") }
    val accounts = remember(vm.state.accounts, query, category) {
        vm.state.accounts.filter { (category == "全部" || it.category == category) &&
            (query.isBlank() || listOf(it.title, it.website, it.username).any { value -> value.contains(query, true) }) }
    }
    Column {
        OutlinedTextField(query, { vm.touch(); query = it }, label = { Text("搜索平台、网站或用户名") }, singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp))
        Chips(listOf("全部") + vaultCategories, category) { category = it }
        Text("${accounts.size} 个账号 · 数据仅保存在本机", Modifier.padding(16.dp), style = MaterialTheme.typography.labelLarge)
        if(accounts.isEmpty()) Empty("还没有找到账号", "点击右下角 ＋ 添加第一条账号")
        else LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 90.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(accounts, key = { it.id }) { account ->
                Card(onClick = { open(account) }, modifier = Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.primaryContainer) {
                            Text(account.title.take(1), Modifier.padding(15.dp), fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        }
                        Column(Modifier.weight(1f).padding(start = 14.dp)) {
                            Text(account.title, fontWeight = FontWeight.Bold)
                            Text(account.username, maxLines = 1, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(account.category, style = MaterialTheme.typography.labelSmall)
                        }
                        TextButton(onClick = { favorite(account) }, enabled = !vm.state.busy) { Text(if(account.favorite) "★" else "☆", fontSize = 23.sp) }
                    }
                }
            }
        }
    }
}

@Composable
private fun AccountEditor(initial: Credential, vm: AppViewModel, back: () -> Unit) {
    var title by remember { mutableStateOf(initial.title) }
    var website by remember { mutableStateOf(initial.website) }
    var username by remember { mutableStateOf(initial.username) }
    var password by remember { mutableStateOf(initial.password) }
    var note by remember { mutableStateOf(initial.note) }
    var category by remember { mutableStateOf(initial.category) }
    var favorite by remember { mutableStateOf(initial.favorite) }
    val existing = vm.state.accounts.any { it.id == initial.id }
    BackHandler(onBack = back)
    Scaffold(topBar = { EditorBar(if(existing) "编辑账号" else "新增账号", back) }) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Field("平台名称 *", title) { title = it }
            Field("网站地址", website) { website = it }
            Field("登录账号 *", username) { username = it }
            SecretField("登录密码 *", password, { password = it })
            TextButton(onClick = { password = Crypto.generatePassword() }) { Text("生成安全随机密码") }
            PasswordStrength(password)
            Text("分类", fontWeight = FontWeight.Bold)
            Chips(vaultCategories, category) { category = it }
            Field("备注", note, singleLine = false) { note = it }
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(favorite, { favorite = it }); Text("收藏账号") }
            Button(onClick = { vm.saveAccount(initial.copy(title = title.trim(), website = website.trim(), username = username,
                password = password, note = note, category = category, favorite = favorite), back) },
                enabled = !vm.state.busy, modifier = Modifier.fillMaxWidth()) { Text("保存账号") }
        }
    }
}

@Composable
private fun AccountDetail(account: Credential, vm: AppViewModel, biometric: (Boolean, String?) -> Unit,
                          onEdit: (Credential) -> Unit, onBack: () -> Unit) {
    var verify by remember { mutableStateOf(false) }
    var delete by remember { mutableStateOf(false) }
    val visible = vm.state.verifiedAccount == account.id
    BackHandler(onBack = onBack)
    LaunchedEffect(visible) { if(visible) verify = false }
    Scaffold(topBar = { EditorBar(account.title, onBack) }) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Info("账号", account.username) { vm.copy(account.username) }
            Info("密码", if(visible) account.password else "••••••••••••") {
                if(visible) vm.copy(account.password) else verify = true
            }
            TextButton(onClick = { if(visible) vm.hidePassword() else verify = true }) { Text(if(visible) "隐藏密码" else "验证并查看密码") }
            if(account.website.isNotEmpty()) Info("网站", account.website)
            Info("分类", account.category)
            if(account.note.isNotEmpty()) Info("备注", account.note)
            Info("更新时间", date(account.updatedAt))
            Button(onClick = {
                if(visible) onEdit(account) else { vm.message("请先验证主密码，再编辑敏感信息"); verify = true }
            }, modifier = Modifier.fillMaxWidth()) { Text("编辑账号") }
            OutlinedButton(onClick = { delete = true }, enabled = !vm.state.busy, modifier = Modifier.fillMaxWidth()) { Text("删除账号") }
        }
    }
    if(verify) PasswordDialog("验证主密码", "查看、复制或编辑密码前需要验证身份。", !vm.state.busy,
        onDismiss = { verify = false }, onConfirm = { vm.verifyAccount(account.id, it) },
        biometric = if(vm.state.biometricEnabled) ({ biometric(false, account.id) }) else null)
    if(delete) ConfirmDialog("删除账号", "删除后无法恢复，是否删除 ${account.title}？", { delete = false }) {
        vm.deleteAccount(account) { delete = false; onBack() }
    }
}

@Composable
private fun WardrobeList(vm: AppViewModel, edit: (Clothing) -> Unit) {
    var query by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("全部") }
    var season by remember { mutableStateOf("全部") }
    var statistics by remember { mutableStateOf(false) }
    Column {
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(!statistics, { statistics = false }, label = { Text("衣服") })
            FilterChip(statistics, { statistics = true }, label = { Text("统计") })
        }
        if(statistics) {
            LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item { Text("${vm.state.clothing.size} 件衣服", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold) }
                item { Text("按分类", style = MaterialTheme.typography.titleMedium) }
                items(clothingCategories) { name -> StatRow(name, vm.state.clothing.count { it.category == name }, vm.state.clothing.size) }
                item { Text("按季节（可重复计数）", style = MaterialTheme.typography.titleMedium) }
                items(seasons) { name -> StatRow(name, vm.state.clothing.count { name in it.seasons }, vm.state.clothing.size) }
                item { Spacer(Modifier.height(70.dp)) }
            }
        } else {
            OutlinedTextField(query, { vm.touch(); query = it }, label = { Text("搜索名称、颜色、品牌或备注") }, singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp))
            Chips(listOf("全部") + clothingCategories, category) { category = it }
            Chips(listOf("全部") + seasons, season) { season = it }
            val items = remember(vm.state.clothing, query, category, season) {
                vm.state.clothing.filter { (category == "全部" || it.category == category) && (season == "全部" || season in it.seasons) &&
                    (query.isBlank() || listOf(it.name, it.color, it.brand, it.note).any { field -> field.contains(query, true) }) }
            }
            if(items.isEmpty()) Empty("衣橱还是空的", "记录衣服、照片和季节，整理你的日常穿搭")
            else LazyColumn(contentPadding = PaddingValues(16.dp, 12.dp, 16.dp, 90.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(items, key = { it.id }) { item ->
                    Card(onClick = { edit(item) }) {
                        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Photo(item.photoPath, Modifier.size(72.dp))
                            Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
                                Text(item.name, fontWeight = FontWeight.Bold)
                                Text(listOf(item.category, item.brand, item.color).filter { it.isNotBlank() }.joinToString(" · "))
                                Text(item.seasons.joinToString(" / "), style = MaterialTheme.typography.labelSmall)
                            }
                            TextButton(onClick = { vm.favorite(item) }, enabled = !vm.state.busy) { Text(if(item.favorite) "★" else "☆", fontSize = 23.sp) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ClothingEditor(initial: Clothing, vm: AppViewModel, back: () -> Unit) {
    val context = LocalContext.current
    var name by remember { mutableStateOf(initial.name) }
    var category by remember { mutableStateOf(initial.category) }
    var selectedSeasons by remember { mutableStateOf(initial.seasons) }
    var color by remember { mutableStateOf(initial.color) }
    var brand by remember { mutableStateOf(initial.brand) }
    var note by remember { mutableStateOf(initial.note) }
    var favorite by remember { mutableStateOf(initial.favorite) }
    var purchase by remember { mutableStateOf(initial.purchaseDate) }
    var photo by remember { mutableStateOf<Uri?>(null) }
    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    var delete by remember { mutableStateOf(false) }
    val existing = vm.state.clothing.any { it.id == initial.id }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { photo = it ?: photo }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success -> if(success) photo = cameraUri }
    BackHandler(onBack = back)
    Scaffold(topBar = { EditorBar(if(existing) "编辑衣服" else "新增衣服", back) }) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Photo(photo?.toString() ?: initial.photoPath, Modifier.fillMaxWidth().height(180.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(onClick = { picker.launch("image/*") }) { Text("相册选图") }
                OutlinedButton(onClick = {
                    try {
                        val dir = File(context.cacheDir, "camera").apply { mkdirs() }
                        dir.listFiles()?.forEach { it.delete() }
                        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", File(dir, "${System.currentTimeMillis()}.jpg"))
                        cameraUri = uri; camera.launch(uri)
                    } catch (e: Exception) { vm.message("相机不可用：${e.message}") }
                }) { Text("拍照") }
            }
            Field("衣服名称 *", name) { name = it }
            Text("分类"); Chips(clothingCategories, category) { category = it }
            Text("季节（多选）")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                seasons.forEach { s -> FilterChip(s in selectedSeasons, {
                    selectedSeasons = if(s in selectedSeasons) selectedSeasons - s else selectedSeasons + s
                }, label = { Text(s) }) }
            }
            Field("颜色", color) { color = it }; Field("品牌", brand) { brand = it }
            OutlinedButton(onClick = {
                val cal = Calendar.getInstance().apply { if(purchase != null) timeInMillis = purchase!! }
                DatePickerDialog(context, { _, year, month, day ->
                    purchase = Calendar.getInstance().apply { set(year, month, day, 0, 0, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
                }, cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH)).apply {
                    datePicker.maxDate = System.currentTimeMillis(); show()
                }
            }) { Text(purchase?.let(::date) ?: "选择购买日期") }
            if(purchase != null) TextButton(onClick = { purchase = null }) { Text("清除日期") }
            Field("备注", note, singleLine = false) { note = it }
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(favorite, { favorite = it }); Text("收藏") }
            Button(onClick = { vm.saveClothing(initial.copy(name = name.trim(), category = category, seasons = selectedSeasons,
                color = color, brand = brand, note = note, favorite = favorite, purchaseDate = purchase), photo, back) },
                modifier = Modifier.fillMaxWidth(), enabled = !vm.state.busy) { Text("保存衣服") }
            if(existing) OutlinedButton(onClick = { delete = true }, modifier = Modifier.fillMaxWidth(), enabled = !vm.state.busy) { Text("删除衣服") }
        }
    }
    if(delete) ConfirmDialog("删除衣服", "同时删除关联照片，是否继续？", { delete = false }) { vm.deleteClothing(initial, back) }
}

@Composable
private fun Settings(vm: AppViewModel, biometric: (Boolean, String?) -> Unit) {
    val context = LocalContext.current
    var changePassword by remember { mutableStateOf(false) }
    var backupMode by remember { mutableStateOf<String?>(null) }
    var importUri by remember { mutableStateOf<Uri?>(null) }
    var generator by remember { mutableStateOf(false) }
    var clear by remember { mutableStateOf(false) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) {
        if(it != null) { importUri = it; backupMode = "import" }
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Section("安全")
        Card {
            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { Text("生物识别解锁", fontWeight = FontWeight.Bold); Text("指纹 / 面容 · Android Keystore", style = MaterialTheme.typography.bodySmall) }
                Switch(vm.state.biometricEnabled, { if(it) biometric(true, null) else vm.disableBiometric() }, enabled = !vm.state.busy)
            }
        }
        Text("自动锁定", fontWeight = FontWeight.Bold)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(0,1,5,10,30).forEach { minutes -> FilterChip(vm.state.lockMinutes == minutes,
                { vm.setLockMinutes(minutes) }, label = { Text(if(minutes == 0) "离开即锁" else "$minutes 分钟") }) }
        }
        SettingButton("修改主密码", "已有账号和独立密码备份不受影响") { changePassword = true }
        SettingButton("立即锁定", "清除会话中的敏感信息", vm::lock)
        Section("加密备份")
        Text("使用独立备份密码，可在其他设备恢复。仅包含密码箱账号，不包含衣服和照片。", style = MaterialTheme.typography.bodySmall)
        SettingButton("导出并分享备份", "请将文件保存到应用以外的位置") { backupMode = "export" }
        SettingButton("从文件恢复备份", "校验成功后覆盖密码箱账号") { picker.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }
        Section("工具")
        SettingButton("密码生成器", "自定义长度和字符类型") { generator = true }
        Section("关于")
        Text("个人助手 ${BuildConfig.VERSION_NAME}\nKotlin · Jetpack Compose · 本地离线")
        Text("主密码无法找回，请妥善保存备份密码。", style = MaterialTheme.typography.bodySmall)
        OutlinedButton(onClick = { clear = true }, modifier = Modifier.fillMaxWidth()) { Text("清空所有本地数据", color = MaterialTheme.colorScheme.error) }
    }
    if(changePassword) ChangePasswordDialog(vm) { changePassword = false }
    if(backupMode != null) BackupDialog(backupMode == "export", vm.state.busy, { backupMode = null }) { password ->
        if(backupMode == "export") vm.exportBackup(password) { uri ->
            backupMode = null
            try { context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                type = "application/json"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = android.content.ClipData.newUri(context.contentResolver, "加密备份", uri)
            }, "保存或分享加密备份")) } catch (e: Exception) { vm.message("分享失败：${e.message}") }
        } else importUri?.let { vm.importBackup(it, password) { backupMode = null; importUri = null } }
    }
    if(generator) GeneratorDialog(vm) { generator = false }
    if(clear) ConfirmDialog("清空所有数据", "将删除主密码、账号、衣服和照片。此操作不可恢复。应用外的备份不会删除。", { clear = false }) { vm.clearAll() }
}

@Composable
private fun ChangePasswordDialog(vm: AppViewModel, close: () -> Unit) {
    var old by remember { mutableStateOf("") }; var new by remember { mutableStateOf("") }; var confirm by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = close, title = { Text("修改主密码") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            SecretField("原主密码", old, { old = it }); SecretField("新主密码", new, { new = it }); SecretField("确认新主密码", confirm, { confirm = it })
        }
    }, confirmButton = { TextButton(onClick = { vm.changePassword(old, new, confirm, close) }, enabled = !vm.state.busy) { Text("确认修改") } },
        dismissButton = { TextButton(onClick = close) { Text("取消") } })
}

@Composable
private fun BackupDialog(exporting: Boolean, busy: Boolean, close: () -> Unit, submit: (String) -> Unit) {
    var password by remember { mutableStateOf("") }; var confirm by remember { mutableStateOf("") }; var error by remember { mutableStateOf<String?>(null) }
    AlertDialog(onDismissRequest = close, title = { Text(if(exporting) "导出加密备份" else "覆盖恢复密码箱") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            Text(if(exporting) "设置独立备份密码（至少 8 位）。请牢记此密码，换设备恢复时需要使用。"
                else "恢复将覆盖当前密码箱中的全部账号，建议先导出当前数据。输入备份密码；旧版 1.0 备份可留空，仅支持原密钥恢复。")
            SecretField("备份密码", password, { password = it })
            if(exporting) SecretField("确认备份密码", confirm, { confirm = it })
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }, confirmButton = { TextButton(onClick = {
        if(exporting && password.length < 8) error = "备份密码至少 8 位"
        else if(exporting && password != confirm) error = "两次输入不一致"
        else submit(password)
    }, enabled = !busy) { Text(if(exporting) "导出并分享" else "确认覆盖恢复") } }, dismissButton = { TextButton(onClick = close) { Text("取消") } })
}

@Composable
private fun GeneratorDialog(vm: AppViewModel, close: () -> Unit) {
    var length by remember { mutableFloatStateOf(20f) }
    var upper by remember { mutableStateOf(true) }; var lower by remember { mutableStateOf(true) }
    var numbers by remember { mutableStateOf(true) }; var symbols by remember { mutableStateOf(true) }
    var password by remember { mutableStateOf(Crypto.generatePassword()) }
    AlertDialog(onDismissRequest = close, title = { Text("密码生成器") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            Text(password, style = MaterialTheme.typography.titleMedium)
            PasswordStrength(password)
            Text("长度：${length.toInt()}"); Slider(length, { length = it }, valueRange = 8f..64f, steps = 55)
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(upper, { upper = it }); Text("大写字母") }
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(lower, { lower = it }); Text("小写字母") }
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(numbers, { numbers = it }); Text("数字") }
            Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(symbols, { symbols = it }); Text("特殊字符") }
            Button(onClick = { password = Crypto.generatePassword(length.toInt(), upper, lower, numbers, symbols) }, enabled = upper || lower || numbers || symbols) { Text("重新生成") }
        }
    }, confirmButton = { TextButton(onClick = { vm.copy(password) }) { Text("复制密码") } }, dismissButton = { TextButton(onClick = close) { Text("关闭") } })
}

@Composable
private fun SecretField(label: String, value: String, change: (String) -> Unit, enabled: Boolean = true) {
    val touch = LocalInteraction.current
    var visible by remember { mutableStateOf(false) }
    OutlinedTextField(value, { touch(); change(it) }, enabled = enabled, label = { Text(label) }, singleLine = true,
        visualTransformation = if(visible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        trailingIcon = { TextButton(onClick = { visible = !visible }) { Text(if(visible) "隐藏" else "显示") } },
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp))
}
@Composable
private fun Field(label: String, value: String, singleLine: Boolean = true, change: (String) -> Unit) {
    val touch = LocalInteraction.current
    OutlinedTextField(value, { touch(); change(it) }, label = { Text(label) }, singleLine = singleLine, minLines = if(singleLine) 1 else 3, modifier = Modifier.fillMaxWidth())
}
@Composable
private fun Chips(options: List<String>, selected: String, change: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { FilterChip(it == selected, { change(it) }, label = { Text(it) }) }
    }
}
@Composable
private fun EditorBar(title: String, back: () -> Unit) {
    TopAppBar(title = { Text(title, fontWeight = FontWeight.Bold) }, navigationIcon = { TextButton(onClick = back) { Text("返回") } })
}
@Composable
private fun Empty(title: String, subtitle: String) {
    Column(Modifier.fillMaxWidth().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(title, style = MaterialTheme.typography.titleLarge); Text(subtitle, Modifier.padding(top = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
@Composable
private fun Info(label: String, value: String, copy: (() -> Unit)? = null) {
    Card(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(label, style = MaterialTheme.typography.labelMedium); Text(value, Modifier.padding(top = 6.dp)) }
            if(copy != null) TextButton(onClick = copy) { Text("复制") }
        }
    }
}
@Composable
private fun PasswordDialog(title: String, description: String, enabled: Boolean, onDismiss: () -> Unit,
                           onConfirm: (String) -> Unit, biometric: (() -> Unit)? = null) {
    var password by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(title) }, text = { Column {
        Text(description); SecretField("主密码", password, { password = it }, enabled)
        if(biometric != null) TextButton(onClick = biometric, enabled = enabled) { Text("使用指纹 / 面容验证") }
    } }, confirmButton = { TextButton(onClick = { onConfirm(password) }, enabled = enabled) { Text("验证") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } })
}
@Composable
private fun ConfirmDialog(title: String, message: String, dismiss: () -> Unit, confirm: () -> Unit) {
    AlertDialog(onDismissRequest = dismiss, title = { Text(title) }, text = { Text(message) },
        confirmButton = { TextButton(onClick = confirm) { Text("确认") } }, dismissButton = { TextButton(onClick = dismiss) { Text("取消") } })
}
@Composable
private fun SettingButton(title: String, description: String, action: () -> Unit) {
    Card(onClick = action, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) { Text(title, fontWeight = FontWeight.Bold); Text(description, style = MaterialTheme.typography.bodySmall) }
    }
}
@Composable
private fun Section(title: String) { Text(title, Modifier.padding(top = 8.dp), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary) }
@Composable
private fun PasswordStrength(password: String) {
    val groups = listOf(password.any(Char::isUpperCase), password.any(Char::isLowerCase), password.any(Char::isDigit), password.any { !it.isLetterOrDigit() }).count { it }
    val score = if(password.length >= 16 && groups >= 3) 3 else if(password.length >= 10 && groups >= 2) 2 else 1
    Text("密码强度：${listOf("弱", "中", "强")[score - 1]}", style = MaterialTheme.typography.bodySmall,
        color = if(score == 1) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)
}
@Composable
private fun Photo(path: String, modifier: Modifier) {
    val context = LocalContext.current
    val bitmap by produceState<android.graphics.Bitmap?>(null, path) {
        value = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            runCatching {
                fun stream() = if(path.startsWith("content:")) context.contentResolver.openInputStream(Uri.parse(path)) else File(path).takeIf { it.isFile }?.inputStream()
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                stream()?.use { BitmapFactory.decodeStream(it, null, options) }
                var sample = 1
                while(options.outWidth / sample > 1024 || options.outHeight / sample > 1024) sample *= 2
                options.inJustDecodeBounds = false; options.inSampleSize = sample
                stream()?.use { BitmapFactory.decodeStream(it, null, options) }
            }.getOrNull()
        }
    }
    Surface(modifier, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.secondaryContainer) {
        if(bitmap != null) Image(bitmap!!.asImageBitmap(), contentDescription = "衣服照片", contentScale = androidx.compose.ui.layout.ContentScale.Crop)
        else Box(contentAlignment = Alignment.Center) { Text("衣", fontSize = 30.sp, color = MaterialTheme.colorScheme.secondary) }
    }
}
@Composable
private fun StatRow(name: String, count: Int, total: Int) {
    Column { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text(name); Text("$count 件") }
        LinearProgressIndicator(progress = { if(total == 0) 0f else count.toFloat() / total }, modifier = Modifier.fillMaxWidth().padding(top = 6.dp)) }
}
private fun date(time: Long): String = SimpleDateFormat("yyyy-MM-dd", Locale.CHINA).format(Date(time))
