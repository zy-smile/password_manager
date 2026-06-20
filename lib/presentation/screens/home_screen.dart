import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/utils/clipboard_helper.dart';
import '../../domain/entities/vault_account.dart';
import '../providers/auth_provider.dart';
import '../providers/vault_provider.dart';
import 'add_account_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vault = Provider.of<VaultProvider>(context, listen: false);
      await vault.loadCategories();
      await vault.loadAccounts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard(
    String text,
    String label, {
    bool sensitive = false,
  }) async {
    await ClipboardHelper.copyToClipboard(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sensitive ? '已复制$label，30 秒后会自动清空剪贴板' : '已复制$label',
        ),
      ),
    );
  }

  Future<bool> _verifySensitiveAction() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isBiometricEnabled && auth.isBiometricAvailable) {
      final biometricSuccess = await auth.authenticateWithBiometrics(
        reason: '请验证身份以查看或复制密码',
      );
      if (biometricSuccess) {
        return true;
      }
    }

    final controller = TextEditingController();
    var obscure = true;
    String? errorMessage;

    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('验证主密码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: '主密码',
                      errorText: errorMessage,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() => obscure = !obscure);
                        },
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final success =
                          await auth.authenticate(controller.text.trim());
                      if (!mounted) return;
                      if (success) {
                        Navigator.of(dialogContext).pop(true);
                      } else {
                        setDialogState(() => errorMessage = '主密码错误');
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final success = await auth.authenticate(
                      controller.text.trim(),
                    );
                    if (!mounted) return;
                    if (success) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setDialogState(() => errorMessage = '主密码错误');
                    }
                  },
                  child: const Text('验证'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return verified ?? false;
  }

  Future<void> _showAccountDetail(VaultAccount account) async {
    final passwordVisible = ValueNotifier<bool>(false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        Future<void> revealPassword({bool copyAfterReveal = false}) async {
          final verified = await _verifySensitiveAction();
          if (!verified) return;

          passwordVisible.value = true;
          if (copyAfterReveal) {
            await _copyToClipboard(
              account.password,
              '密码',
              sensitive: true,
            );
          }
        }

        return ValueListenableBuilder<bool>(
          valueListenable: passwordVisible,
          builder: (context, isPasswordVisible, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        account.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        account.website,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        label: '账号',
                        value: account.username,
                        onCopy: () => _copyToClipboard(account.username, '账号'),
                      ),
                      _buildDetailRow(
                        label: '密码',
                        value: isPasswordVisible
                            ? account.password
                            : '点击右侧图标验证后查看',
                        onCopy: () => revealPassword(copyAfterReveal: true),
                        trailing: IconButton(
                          onPressed: () => revealPassword(),
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      _buildDetailRow(
                        label: '分类',
                        value: account.category,
                      ),
                      if (account.note.isNotEmpty)
                        _buildDetailRow(label: '备注', value: account.note),
                      _buildDetailRow(
                        label: '创建时间',
                        value: _formatDateTime(account.createdAt),
                      ),
                      _buildDetailRow(
                        label: '更新时间',
                        value: _formatDateTime(account.updatedAt),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddAccountScreen(
                                      account: account,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('编辑'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _deleteAccount(account.id);
                              },
                              child: const Text('删除'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    passwordVisible.dispose();
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    VoidCallback? onCopy,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<void> _deleteAccount(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后将无法恢复，确定要继续吗？'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await Provider.of<VaultProvider>(context, listen: false).deleteAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('账号已删除')),
    );
  }

  Widget _buildAccountCard(VaultAccount account) {
    return Slidable(
      key: ValueKey(account.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _deleteAccount(account.id),
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '删除',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              account.title.isNotEmpty ? account.title[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          title: Text(account.title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${account.website}\n${account.username}'),
          ),
          isThreeLine: true,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                account.category,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                onPressed: () {
                  Provider.of<VaultProvider>(context, listen: false)
                      .toggleFavorite(account.id, !account.isFavorite);
                },
                icon: Icon(
                  account.isFavorite ? Icons.star_rounded : Icons.star_outline,
                  color: account.isFavorite ? const Color(0xFFF59E0B) : null,
                ),
              ),
            ],
          ),
          onTap: () => _showAccountDetail(account),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('密码保险箱'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Consumer<VaultProvider>(
        builder: (context, vault, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '实时搜索标题、网站或用户名',
                  ),
                  onChanged: (value) {
                    vault.setSearchQuery(value);
                    vault.loadAccounts();
                  },
                ),
              ),
              _buildCategoryFilter(vault),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: vault.loadAccounts,
                  child: vault.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : vault.accounts.isEmpty
                          ? ListView(
                              children: [_buildEmptyState()],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: vault.accounts.length,
                              itemBuilder: (context, index) {
                                return _buildAccountCard(vault.accounts[index]);
                              },
                            ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新增账号'),
      ),
    );
  }

  Widget _buildCategoryFilter(VaultProvider vault) {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: vault.categories.length + 1,
        itemBuilder: (context, index) {
          final category = index == 0 ? '全部' : vault.categories[index - 1];
          final isSelected = _selectedCategory == category ||
              (index == 0 && _selectedCategory == null);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = index == 0 ? null : category;
                });
                vault.setSelectedCategory(_selectedCategory);
                vault.loadAccounts();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 360,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_person_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有保存任何账号',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '可以先新增一条网站凭据，之后支持搜索、收藏、备份和恢复。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
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
