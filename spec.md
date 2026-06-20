

# Feature: Password Vault

## Overview

开发一个基于 Flutter 的个人密码管理 App。

目标是帮助个人用户安全地管理各类网站账号密码，解决账号过多、密码遗忘的问题。

所有敏感数据必须本地加密存储。

第一版本不包含云同步功能，仅支持本地数据管理与加密备份。

平台：

* Android
* iOS

技术栈：

* Flutter
* Riverpod
* Isar Database
* cryptography
* local_auth

---

# Product Goals

## Goal 1

用户能够安全保存网站账号密码。

## Goal 2

用户能够通过主密码保护所有数据。

## Goal 3

用户能够导出和导入加密备份文件。

## Goal 4

用户能够快速搜索和查看账号信息。

---

# User Stories

## US-001

作为用户

我希望添加网站账号密码

以便后续查找和使用。

### Acceptance Criteria

Given 用户进入新增页面

When 输入网站、账号和密码

Then 数据成功保存

---

## US-002

作为用户

我希望查看已保存账号列表

以便快速找到目标账号。

### Acceptance Criteria

Given 数据库存在记录

When 打开首页

Then 显示账号列表

---

## US-003

作为用户

我希望搜索账号

以便快速定位记录。

### Acceptance Criteria

Given 已存在多条记录

When 输入关键字

Then 返回匹配结果

---

## US-004

作为用户

我希望查看密码

以便登录网站。

### Acceptance Criteria

Given 已保存账号

When 点击查看密码

Then 需要验证身份

And 显示密码

---

## US-005

作为用户

我希望复制账号和密码

以便快速登录。

### Acceptance Criteria

Given 查看详情页

When 点击复制

Then 内容进入剪贴板

And 30秒后自动清空

---

## US-006

作为用户

我希望删除账号记录

以便清理无效数据。

### Acceptance Criteria

Given 存在账号记录

When 点击删除

Then 二次确认

And 删除成功

---

## US-007

作为用户

我希望导出备份

以便迁移设备。

### Acceptance Criteria

Given 数据库存在数据

When 点击导出

Then 生成加密文件

---

## US-008

作为用户

我希望导入备份

以便恢复数据。

### Acceptance Criteria

Given 选择合法备份文件

When 点击导入

Then 成功恢复数据

---

# Functional Requirements

## REQ-001 主密码

首次启动必须设置主密码。

主密码最少 8 位。

禁止保存明文主密码。

---

## REQ-002 密钥派生

使用：

Argon2id

或者

PBKDF2-SHA256

生成加密密钥。

禁止直接使用用户密码作为 AES Key。

---

## REQ-003 数据加密

所有敏感字段必须 AES-256-GCM 加密。

包括：

* username
* password
* note

---

## REQ-004 本地数据库

使用 Isar。

所有账号数据存储于本地数据库。

---

## REQ-005 生物识别

支持：

* Face ID
* Touch ID
* Android Biometrics

使用 local_auth。

---

## REQ-006 账号记录字段

每条记录包含：

```dart
class Credential {
  String id;

  String title;

  String website;

  String username;

  String password;

  String note;

  bool favorite;

  DateTime createdAt;

  DateTime updatedAt;
}
```

---

## REQ-007 搜索

支持：

* 网站名搜索
* 用户名搜索

实时过滤。

---

## REQ-008 导出备份

导出格式：

```json
{
  "version":"1.0",
  "exportTime":"",
  "salt":"",
  "iv":"",
  "cipherText":""
}
```

导出内容必须加密。

禁止导出明文数据。

---

## REQ-009 导入备份

校验：

* version
* hash
* encryption

非法文件拒绝导入。

---

## REQ-010 剪贴板保护

复制密码后：

30 秒自动清空剪贴板。

---

## REQ-011 自动锁定

应用进入后台超过：

5 分钟

自动锁定。

重新验证主密码或生物识别。

---

# Non Functional Requirements

## NFR-001

启动时间 < 2 秒

---

## NFR-002

支持 10000 条账号记录

---

## NFR-003

列表滚动保持流畅

60 FPS

---

## NFR-004

所有业务逻辑必须编写单元测试

覆盖率 ≥ 80%

---

# Architecture

采用 Clean Architecture。

目录结构：

```text
lib/
├── app/
├── core/
│   ├── crypto/
│   ├── storage/
│   ├── security/
│   └── utils/
├── features/
│   ├── auth/
│   ├── vault/
│   ├── backup/
│   └── settings/
├── shared/
└── main.dart
```

---

# Screens

## Splash

启动验证

---

## Setup Master Password

首次设置主密码

---

## Unlock

解锁页面

---

## Home

账号列表

搜索框

新增按钮

---

## Credential Detail

查看账号详情

查看密码

复制密码

编辑

删除

---

## Add Credential

新增账号

---

## Settings

生物识别

导出

导入

关于

---

# Out Of Scope

第一版不实现：

* 云同步
* WebDAV
* Google Drive
* iCloud
* 多设备同步
* TOTP 动态验证码
* 密码共享
* 团队协作
* 浏览器插件

---

# Implementation Tasks

Phase 1

* Flutter项目初始化
* 路由系统
* Riverpod配置
* Isar配置

Phase 2

* 主密码模块
* AES加密模块
* 生物识别模块

Phase 3

* Vault CRUD

Phase 4

* 搜索功能

Phase 5

* 导入导出

Phase 6

* 单元测试
* UI优化
* 发布构建

---
