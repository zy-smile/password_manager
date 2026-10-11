import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:password_manager/core/constants/app_constants.dart';
import 'package:password_manager/core/utils/clipboard_helper.dart';
import 'package:password_manager/features/wardrobe/presentation/wardrobe_provider.dart';
import 'package:password_manager/features/vault/presentation/providers/auth_provider.dart';
import 'package:password_manager/features/vault/presentation/providers/settings_provider.dart';
import 'package:password_manager/features/vault/presentation/providers/vault_provider.dart';
import 'password_generator_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<SettingsProvider>(context, listen: false)
          .loadSettings();
      if (!mounted) return;
      await Provider.of<VaultProvider>(context, listen: false).loadBackups();
    });
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('修改主密码'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '原主密码'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '新主密码'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '确认新主密码'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('两次输入的主密码不一致')),
                  );
                  return;
                }

                try {
                  await Provider.of<AuthProvider>(context, listen: false)
                      .changeMasterPassword(
                    oldPasswordController.text,
                    newPasswordController.text,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('主密码已更新')),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<String?> _askBackupPassword({required bool exporting}) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(exporting ? '设置备份密码' : '输入备份密码'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(exporting
                  ? '请保存好此密码。换设备或修改主密码后，仍可使用它恢复备份。备份仅包含密码箱账号。'
                  : '请输入导出时设置的独立备份密码。旧版 1.0 备份可留空，仅支持原保险箱恢复。'),
              const SizedBox(height: 12),
              TextField(
                  controller: password,
                  obscureText: true,
                  decoration:
                      InputDecoration(labelText: '备份密码', errorText: error)),
              if (exporting)
                TextField(
                    controller: confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '确认备份密码')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消')),
            FilledButton(
                onPressed: () {
                  if (exporting && password.text.length < 8) {
                    setDialogState(() => error = '备份密码至少需要 8 位');
                    return;
                  }
                  if (exporting && password.text != confirmation.text) {
                    setDialogState(() => error = '两次输入的密码不一致');
                    return;
                  }
                  Navigator.pop(dialogContext, password.text);
                },
                child: const Text('确认')),
          ],
        ),
      ),
    );
    password.dispose();
    confirmation.dispose();
    return result;
  }

  Future<void> _handleExportBackup() async {
    final vault = context.read<VaultProvider>();
    final password = await _askBackupPassword(exporting: true);
    if (!mounted || password == null) return;
    try {
      final result = await vault.exportBackup(password);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('备份导出成功'),
          content: Text(
              '已导出 ${result.accountCount} 条账号。请分享或另存到应用以外的位置。衣服和照片不在此备份中。'),
          actions: [
            TextButton(
                onPressed: () async {
                  final box = dialogContext.findRenderObject() as RenderBox?;
                  final origin = box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size;
                  try {
                    await SharePlus.instance.share(ShareParams(
                      files: [XFile(result.file.path)],
                      subject: '个人助手加密备份',
                      sharePositionOrigin: origin,
                    ));
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('分享失败：$error')));
                  }
                },
                child: const Text('分享备份')),
            TextButton(
                onPressed: () async {
                  await ClipboardHelper.copyToClipboard(result.file.path);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                },
                child: const Text('复制路径')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('完成')),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  Future<void> _handleImportBackup() async {
    final vault = context.read<VaultProvider>();
    try {
      await vault.loadBackups();
      if (!mounted) return;
      var filePath = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('从设备选择备份文件'),
                onTap: () => Navigator.pop(sheetContext, '__external__')),
            for (final backup in vault.backups)
              ListTile(
                title: Text(backup.name),
                subtitle: Text(
                    '${_formatDateTime(backup.modifiedAt)} · ${backup.sizeBytes} bytes'),
                onTap: () => Navigator.pop(sheetContext, backup.path),
              ),
          ]),
        ),
      );
      if (!mounted || filePath == null) return;
      if (filePath == '__external__') {
        final selection = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          allowMultiple: false,
        );
        if (!mounted || selection == null) return;
        filePath = selection.files.single.path;
      }
      if (filePath == null) throw Exception('无法读取所选文件');
      final password = await _askBackupPassword(exporting: false);
      if (!mounted || password == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认恢复备份'),
          content: const Text('恢复会覆盖当前密码箱中的全部账号。建议先导出当前数据。衣服数据不受影响。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('覆盖恢复')),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await vault.importBackup(filePath, backupPassword: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('备份恢复成功')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  Future<void> _showClearDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有数据'),
        content: const Text('此操作会清空主密码、本地账号、衣服数据和设置项，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    final vault = context.read<VaultProvider>();
    final wardrobe = context.read<WardrobeProvider>();
    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();
    await vault.clearAllData();
    await wardrobe.clearAllItems();
    await auth.clearAllData();
    settings.resetState();

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildTile({
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildSection('安全', [
            _buildTile(
                title: '立即锁定',
                trailing: const Icon(Icons.lock_outline),
                onTap: () => context.read<AuthProvider>().lock()),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return SwitchListTile(
                  title: const Text('启用生物识别'),
                  subtitle:
                      const Text('支持 Face ID、Touch ID 或 Android Biometrics'),
                  value: auth.isBiometricEnabled,
                  onChanged: (value) async {
                    if (value && !auth.isBiometricAvailable) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('当前设备不支持生物识别')),
                      );
                      return;
                    }

                    try {
                      await auth.toggleBiometric(value);
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return _buildTile(
                  title: '自动锁定',
                  subtitle:
                      AppConstants.autoLockLabels[settings.autoLockMinutes],
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final minutes
                                  in AppConstants.autoLockOptions)
                                ListTile(
                                  title: Text(
                                    AppConstants.autoLockLabels[minutes]!,
                                  ),
                                  trailing: minutes == settings.autoLockMinutes
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () async {
                                    await settings.setAutoLockMinutes(minutes);
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            _buildTile(
              title: '修改主密码',
              subtitle: '至少 8 位且包含数字；修改后已有备份仍可使用',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showChangePasswordDialog,
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('备份', [
            _buildTile(
              title: '导出加密备份',
              subtitle: '使用独立备份密码加密，支持分享和换设备恢复',
              trailing: const Icon(Icons.file_upload_outlined),
              onTap: _handleExportBackup,
            ),
            Consumer<VaultProvider>(
              builder: (context, vault, _) {
                return _buildTile(
                  title: '导入备份',
                  subtitle: vault.backups.isEmpty
                      ? '从设备选择加密备份文件'
                      : '已发现 ${vault.backups.length} 个备份文件',
                  trailing: const Icon(Icons.file_download_outlined),
                  onTap: _handleImportBackup,
                );
              },
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('工具', [
            _buildTile(
              title: '密码生成器',
              subtitle: '快速生成高强度随机密码',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PasswordGeneratorScreen(),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('关于', [
            _buildTile(title: '应用名称', subtitle: AppConstants.appName),
            _buildTile(
              title: '备份目录',
              subtitle: context.watch<VaultProvider>().backupDirectoryPath ??
                  '加载中...',
            ),
            _buildTile(title: '版本', subtitle: '1.0.1'),
          ]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: _showClearDataDialog,
              child: const Text('清空所有本地数据'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
