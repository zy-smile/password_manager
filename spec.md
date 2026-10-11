# Personal Assistant implementation specification

当前需求以《产品设计文档.md》为准，技术结构以《项目架构设计.md》和 README.md 为准。

## Release 1.0.1

- Flutter + Provider/ChangeNotifier + sqflite，移动端 local_auth，flutter_secure_storage。
- 两个业务模块：vault（敏感字段加密）和 wardrobe（明文记录、独立图片目录）。
- 全局会话：主密码、生物识别、手动锁定、闲置计时、后台计时；锁定销毁导航和敏感缓存。
- 主密码：PBKDF2-SHA256 150000 次派生包装密钥，随机数据密钥 AES-256-GCM 加密业务字段。修改主密码仅替换一条完整的包装记录。
- 备份 2.0：独立密码、随机盐/IV、GCM 认证、严格记录校验、事务覆盖恢复、外部文件选择和分享。
- 旧认证与备份兼容范围按 README 说明执行。

## Verification commands

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

测试需要覆盖密码修改失败恢复、旧格式认证升级、备份跨设备/错误密码/篡改、前后台锁定、导航销毁、迟到请求丢弃、10000 条缓存搜索。平台插件和设备性能需另外做真机验收。当前没有证据证明覆盖率达到 80%。
