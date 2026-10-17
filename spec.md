# Native Android specification

项目现为 Kotlin + Jetpack Compose 原生 Android 工程。需求见《产品设计文档.md》，实现见《项目架构设计.md》。

- App version 2.0.0 / versionCode 3；applicationId com.example.password_manager。
- minSdk 24，compileSdk/targetSdk 36；JDK 17；AGP 9.0.1；Gradle 9.1。
- 主密码、密码箱、衣橱、系统生物识别、锁定、随机密码、加密备份。
- 旧 SQLite 和默认安全存储兼容；旧主密码与两代加密备份跨语言回归测试。
- 活动源码只维护原生 Android；旧平台壳、源码归档、旧安装包和 IDE 配置均已清理。

```sh
./gradlew :app:testDebugUnitTest :app:lintDebug :app:assembleRelease
# 专用模拟器：
./gradlew :app:connectedDebugAndroidTest
```

设备测试会清理测试应用的数据。禁止把 connectedDebugAndroidTest 用在存有个人数据的设备上。
