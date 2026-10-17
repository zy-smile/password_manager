# 个人助手 · 原生 Android

本项目已从 Flutter 重写为 **Kotlin + Jetpack Compose** 原生 Android 应用，版本 **2.0.1**。根目录可直接使用 Android Studio 打开，构建和运行均不需要 Flutter / Dart SDK。

## 功能

### 密码箱

- 主密码首次设置、解锁、修改；至少 8 位且包含数字，保留输入空格。
- 连续 5 次验证失败后冷却 30 秒，失败次数和冷却截止时间在进程重启后保留。
- 账号新增、编辑、删除、查看、收藏；平台/网站/用户名搜索与默认分类筛选。
- 查看、复制和编辑密码前再次验证主密码或生物识别。
- 用户名、密码、备注使用 AES-256-GCM 字段加密；标题、网站、分类等元数据明文存储。
- 主密码通过 PBKDF2-HMAC-SHA256（150000 次）包装随机 256 位数据密钥；修改主密码不重写账号数据库。
- 指纹/面容使用 AndroidX BiometricPrompt + Android Keystore 的每次操作认证密钥，系统认证成功后才可解密数据密钥。
- 随机密码生成器支持 8～64 位、大小写字母/数字/符号和强度提示。
- 剪贴板敏感标记与 30 秒清理；只在内容仍相同时清空，后台行为受 Android 剪贴板权限限制。

### 全局锁定

主密码保护整个应用。支持手动锁定、前台闲置锁定和后台超时锁定；可选离开即锁/1/5/10/30 分钟。锁定时清除数据密钥和账号列表，销毁编辑、详情和密码对话框状态，丢弃过期异步结果。屏幕旋转不视为进入后台。Android 窗口启用 FLAG_SECURE。

### 加密备份

使用独立备份密码导出 2.0 格式的 JSON。点击“选择保存位置”后，在系统“另存为”窗口中选择下载、文档、SD 卡或支持的网盘目录，并修改文件名。文件直接写入用户选择的文档位置，不保存在应用缓存或应用专属目录，卸载应用或清空应用数据不会删除已成功导出的文件。恢复使用系统文件选择器。GCM 认证、版本、派生参数、记录字段和重复 ID 校验通过后，事务覆盖账号。

备份只包含密码箱，不包含衣服、照片或设置。恢复前应先备份当前数据。备份密码遗忘无法找回。仅支持当前 2.0 备份格式，不再读取旧 1.0 备份。

### 衣橱

衣服信息和照片增删改查、收藏；分类、季节多选、颜色、品牌、购买日期、备注；相册选图和系统相机拍照；关键字/分类/季节筛选；总数、分类和季节统计。衣服数据和照片明文存储。替换照片在数据库保存成功后才删除旧照片。

## 数据支持范围

本版已移除旧安全存储读取器、旧密码派生认证、CBC 解密、旧数据库迁移、旧照片路径和旧备份恢复逻辑。当前原生版的认证记录和数据库继续正常使用，不自动清空数据；不支持的旧安装需要重新设置。

保存文件时开启“离开即锁”也能正常导出：系统保存窗口期间只保留已加密内容，返回后仍保持锁定。取消保存不会提示成功；写入或关闭文件失败会提示错误并尝试删除此次不完整的导出。待保存内容 15 分钟后过期，进程退出后需重新导出。

## 工程结构

```text
app/src/main/java/com/example/password_manager/
  MainActivity.kt           生命周期、系统生物识别入口
  AppViewModel.kt           会话、状态、异步任务和业务协调
  core/                     JCA 加密、加密备份、Keystore、文档保存
  data/                     实体、SQLiteOpenHelper、认证 Repository
  ui/                       Compose 页面、表单和对话框
app/src/test/               JVM 单元测试
app/src/androidTest/        数据库、Keystore、Compose 操作和系统另存为测试
```

SQLite 使用 Android SDK 自带实现；应用中没有 Flutter 引擎、Dart 代码、WebView 套壳或跨平台运行时。Android SDK 不支持的平台已从活动工程移除。

## 构建

需要 JDK 17、Android SDK 36、Android Studio 支持 AGP 9 的版本。Gradle Wrapper 已包含在仓库中。

Windows：

```powershell
# local.properties 设置为本机 SDK 路径，例如 sdk.dir=D\:/Android/Sdk
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:assembleRelease
```

macOS/Linux：使用 `./gradlew`。首次构建需联网下载 Google Maven / Maven Central 依赖。

- 最低 Android 7.0（API 24），目标/编译 API 36。
- Release APK：`app/build/outputs/apk/release/app-release.apk`。
- Release 默认使用 debug keystore，仅供安装测试；商店发布请改用自己的正式签名，禁止将私钥提交到 Git。
- 设备测试：在**专用测试模拟器**上运行 `:app:connectedDebugAndroidTest`，测试会清空测试应用中的数据，不应在存有个人数据的手机上执行。

## 当前范围

不包含云同步、TOTP、共享、自定义分类管理、独立手机号/邮箱字段、最近使用记录或衣橱备份。生物识别、相机和不同文档提供程序仍需真实设备验收。具体构建和测试结果见《验证与构建记录.md》。

技术参考：[Compose 编译插件](https://developer.android.com/develop/ui/compose/setup-compose-dependencies-and-compiler)、[BiometricPrompt 与加密操作](https://developer.android.com/identity/sign-in/biometric-auth)。

文件保存参考：[Android Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files)。
