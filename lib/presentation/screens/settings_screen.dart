import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/clipboard_helper.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/vault_provider.dart';
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
                    oldPasswordController.text.trim(),
                    newPasswordController.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('主密码已更新')),
                  );
                } catch (error) {
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

  Future<void> _handleExportBackup() async {
    try {
      final vault = Provider.of<VaultProvider>(context, listen: false);
      final result = await vault.exportBackup();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('备份导出成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('已导出 ${result.accountCount} 条账号记录。'),
              const SizedBox(height: 12),
              Text(result.file.path),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ClipboardHelper.copyToClipboard(result.file.path);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('备份路径已复制')),
                );
              },
              child: const Text('复制路径'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
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
  }

  Future<void> _handleImportBackup() async {
    final vault = Provider.of<VaultProvider>(context, listen: false);
    await vault.loadBackups();
    if (!mounted) return;

    if (vault.backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前备份目录中还没有可导入的文件')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('选择一个备份文件'),
                subtitle: Text('导入会覆盖当前保险箱中的账号数据'),
              ),
              for (final backup in vault.backups)
                ListTile(
                  title: Text(backup.name),
                  subtitle: Text(
                    '${_formatDateTime(backup.modifiedAt)} · ${backup.sizeBytes} bytes',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认导入'),
                        content: Text('确定用 ${backup.name} 覆盖当前账号数据吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('导入'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;

                    try {
                      await vault.importBackup(backup.path);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('备份导入成功')),
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
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showClearDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有数据'),
        content: const Text('此操作会清空主密码、本地账号数据和设置项，且无法恢复。'),
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

    if (confirmed != true) return;

    await Provider.of<VaultProvider>(context, listen: false).clearAllData();
    await Provider.of<AuthProvider>(context, listen: false).clearAllData();
    Provider.of<SettingsProvider>(context, listen: false).resetState();

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
                                    if (!mounted) return;
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
              subtitle: '主密码至少 8 位，只保存在本地',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showChangePasswordDialog,
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('备份', [
            _buildTile(
              title: '导出加密备份',
              subtitle: '生成本地 JSON 备份文件，内容使用 AES-256-GCM 加密',
              trailing: const Icon(Icons.file_upload_outlined),
              onTap: _handleExportBackup,
            ),
            Consumer<VaultProvider>(
              builder: (context, vault, _) {
                return _buildTile(
                  title: '导入备份',
                  subtitle: vault.backups.isEmpty
                      ? '当前目录没有可导入的备份文件'
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
            _buildTile(title: '版本', subtitle: '1.0.0'),
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
