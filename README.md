# 个人助手 · 原生 Android

本项目已从 Flutter 重写为 **Kotlin + Jetpack Compose** 原生 Android 应用，版本 **2.0.0**。根目录可直接使用 Android Studio 打开，构建和运行均不需要 Flutter / Dart SDK。

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

使用独立备份密码导出兼容 2.0 格式的 JSON，可通过系统分享保存到应用外，使用系统文件选择器恢复。GCM 认证、版本、派生参数、记录字段和重复 ID 校验通过后，事务覆盖账号。

备份只包含密码箱，不包含衣服、照片或设置。恢复前应先备份当前数据。备份密码遗忘无法找回。旧 1.0 备份仍需原保险箱数据密钥。

### 衣橱

衣服信息和照片增删改查、收藏；分类、季节多选、颜色、品牌、购买日期、备注；相册选图和系统相机拍照；关键字/分类/季节筛选；总数、分类和季节统计。衣服数据和照片明文存储。替换照片在数据库保存成功后才删除旧照片。

## 从旧 Flutter 版升级

- 沿用包名 `com.example.password_manager`，versionCode 从 2 升至 3。
- **必须使用相同签名覆盖安装，且不要卸载旧版或清除应用数据。** 当前测试 APK 使用本机原有 Android Debug 签名。
- 保留 SQLite 文件名 `password_vault.db`，兼容旧 v1/v2/v3 表结构，升级为版本 4 并增加排序索引。
- 原生只读兼容器读取本项目原先默认的 flutter_secure_storage 9.x RSA-PKCS1 + AES-CBC/GCM 格式，使用设备原有 Keystore 密钥；成功验证主密码后写入原生加密安全存储。
- 兼容 v3 包装密钥、v2 派生数据密钥，以及更早的 CBC 账号格式。迁移失败时不重置主密码或删除旧数据。
- 原路径下的衣服照片继续读取。旧生物识别开关不自动继承，请在原生版解锁后重新开启。
- 对于其他应用、自定义安全存储算法、丢失 Keystore 密钥的安装，不能保证直接迁移。优先使用旧版导出独立密码备份，再恢复到原生版。

原 Flutter 源码及迁移前未提交的平台文件已保存在本地 `dist/flutter-source-before-native-20261017.zip`，旧版已提交源码也可通过 Git 历史恢复。该归档不参与构建。

## 工程结构

```text
app/src/main/java/com/example/password_manager/
  MainActivity.kt           生命周期、系统生物识别入口
  AppViewModel.kt           会话、状态、异步任务和业务协调
  core/                     JCA 加密、加密备份、Keystore、安全存储兼容
  data/                     实体、SQLiteOpenHelper、认证 Repository
  ui/                       Compose 页面、表单和对话框
app/src/test/               JVM 单元测试、旧 Dart 实际生成的兼容性样本
app/src/androidTest/        数据库、Keystore、旧版迁移和 Compose 操作测试
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

不包含云同步、TOTP、共享、自定义分类管理、独立手机号/邮箱字段、最近使用记录或衣橱备份。生物识别、相机与分享仍需真实设备验收。具体构建和测试结果见《验证与构建记录.md》。

技术参考：[Compose 编译插件](https://developer.android.com/develop/ui/compose/setup-compose-dependencies-and-compiler)、[BiometricPrompt 与加密操作](https://developer.android.com/identity/sign-in/biometric-auth)。
