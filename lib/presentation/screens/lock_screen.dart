import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (auth.isFirstLaunch) {
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() => _errorMessage = '两次输入的主密码不一致');
          return;
        }

        await auth.setupMasterPassword(_passwordController.text);
      } else {
        final success = await auth.authenticate(_passwordController.text);
        if (!success) {
          if (auth.isTemporarilyLocked) {
            final remaining = auth.lockedUntil!
                .difference(DateTime.now())
                .inSeconds
                .clamp(1, 30);
            setState(() => _errorMessage = '尝试过多，请在 $remaining 秒后重试');
          } else {
            setState(() {
              _errorMessage = '主密码错误，还可再尝试 ${5 - auth.failedAttempts} 次';
            });
          }
        }
      }
    } catch (error) {
      setState(() =>
          _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleBiometric() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.authenticateWithBiometrics(
      reason: '请验证身份以解锁密码保险箱',
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生物识别验证未通过')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 36),
                      _buildLogo(),
                      const SizedBox(height: 28),
                      _buildTitle(auth.isFirstLaunch),
                      const SizedBox(height: 36),
                      _buildPasswordField(
                        controller: _passwordController,
                        label: '主密码',
                        hint: auth.isFirstLaunch ? '至少 8 位' : '请输入主密码',
                        visible: _isPasswordVisible,
                        onToggle: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        textInputAction: auth.isFirstLaunch
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: (_) => auth.isFirstLaunch
                            ? FocusScope.of(context).nextFocus()
                            : _handleSubmit(),
                      ),
                      if (auth.isFirstLaunch) ...[
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          label: '确认主密码',
                          hint: '请再次输入主密码',
                          visible: _isConfirmPasswordVisible,
                          onToggle: () => setState(
                            () => _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleSubmit(),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: Text(
                          _isSubmitting
                              ? '处理中...'
                              : auth.isFirstLaunch
                                  ? '创建主密码'
                                  : '解锁保险箱',
                        ),
                      ),
                      if (!auth.isFirstLaunch &&
                          auth.isBiometricEnabled &&
                          auth.isBiometricAvailable) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _handleBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('使用生物识别解锁'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        auth.isFirstLaunch
                            ? '主密码只保存在本地，用于派生加密密钥。请务必牢记。'
                            : '敏感信息将使用 AES-256-GCM 在本地加密保存。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.lock_rounded, size: 42, color: Colors.white),
      ),
    );
  }

  Widget _buildTitle(bool isFirstLaunch) {
    return Column(
      children: [
        Text(
          '密码保险箱',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          isFirstLaunch ? '首次使用，请先设置主密码' : '输入主密码继续访问',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    );
  }
}
