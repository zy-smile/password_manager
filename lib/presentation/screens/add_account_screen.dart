import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/encryption/password_strength.dart';
import '../../core/utils/password_generator.dart';
import '../../domain/entities/vault_account.dart';
import '../providers/vault_provider.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key, this.account});

  final VaultAccount? account;

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _websiteController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = '其他';
  bool _isPasswordVisible = false;
  bool _isFavorite = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<VaultProvider>(context, listen: false).loadCategories();
    });

    final account = widget.account;
    if (account != null) {
      _titleController.text = account.title;
      _websiteController.text = account.website;
      _usernameController.text = account.username;
      _passwordController.text = account.password;
      _noteController.text = account.note;
      _selectedCategory = account.category;
      _isFavorite = account.isFavorite;
    }

    _passwordController.addListener(_updatePasswordStrength);
    _updatePasswordStrength();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _websiteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    setState(() {
      _passwordStrength =
          PasswordStrengthChecker.check(_passwordController.text);
    });
  }

  void _generatePassword() {
    final password = PasswordGenerator.generate();
    _passwordController.text = password;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final account = VaultAccount(
      id: widget.account?.id ?? now.microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      website: _websiteController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      note: _noteController.text.trim(),
      category: _selectedCategory,
      isFavorite: _isFavorite,
      createdAt: widget.account?.createdAt ?? now,
      updatedAt: now,
    );

    final vault = Provider.of<VaultProvider>(context, listen: false);
    if (widget.account == null) {
      await vault.addAccount(account);
    } else {
      await vault.updateAccount(account);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? '新增凭据' : '编辑凭据'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildWebsiteField(),
              const SizedBox(height: 16),
              _buildUsernameField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 16),
              _buildCategoryField(),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('加入收藏'),
                subtitle: const Text('收藏的账号会优先显示在列表顶部'),
                value: _isFavorite,
                onChanged: (value) => setState(() => _isFavorite = value),
              ),
              const SizedBox(height: 8),
              _buildNoteField(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Text(widget.account == null ? '保存凭据' : '更新凭据'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: '标题',
        hintText: '例如：GitHub 主账号',
        prefixIcon: Icon(Icons.title_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入凭据标题';
        }
        return null;
      },
    );
  }

  Widget _buildWebsiteField() {
    return TextFormField(
      controller: _websiteController,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: '网站',
        hintText: '例如：github.com',
        prefixIcon: Icon(Icons.language_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入网站地址';
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: const InputDecoration(
        labelText: '用户名 / 账号',
        hintText: '用于登录的用户名或邮箱',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入登录账号';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return Column(
      children: [
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '请输入登录密码',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                  },
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
                IconButton(
                  onPressed: _generatePassword,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入密码';
            }
            return null;
          },
        ),
        if (_passwordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _passwordStrength.index / 3,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      PasswordStrengthChecker.getColor(_passwordStrength),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  PasswordStrengthChecker.getLabel(_passwordStrength),
                  style: TextStyle(
                    color: PasswordStrengthChecker.getColor(_passwordStrength),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Consumer<VaultProvider>(
      builder: (context, vault, _) {
        final categories = vault.categories.isEmpty
            ? const ['社交', '工作', '金融', '游戏', '开发', '购物', '其他']
            : vault.categories;

        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = categories.last;
        }

        return DropdownButtonFormField<String>(
          value: _selectedCategory,
          items: categories
              .map(
                (category) => DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
          decoration: const InputDecoration(
            labelText: '分类',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
        );
      },
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      minLines: 3,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: '备注',
        hintText: '可记录补充说明、登录提示等信息',
        prefixIcon: Icon(Icons.sticky_note_2_outlined),
      ),
    );
  }
}
