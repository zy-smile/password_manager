import 'package:flutter/material.dart';
import '../../core/utils/password_generator.dart';
import '../../core/utils/clipboard_helper.dart';
import '../../core/encryption/password_strength.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  String _generatedPassword = '';
  int _passwordLength = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSpecialChars = true;
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    final password = PasswordGenerator.generate(
      length: _passwordLength,
      includeUppercase: _includeUppercase,
      includeLowercase: _includeLowercase,
      includeNumbers: _includeNumbers,
      includeSpecialChars: _includeSpecialChars,
    );
    setState(() {
      _generatedPassword = password;
      _passwordStrength = PasswordStrengthChecker.check(password);
    });
  }

  Future<void> _copyToClipboard() async {
    if (_generatedPassword.isEmpty) return;
    await ClipboardHelper.copyToClipboard(_generatedPassword);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密码已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('密码生成器'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildPasswordDisplay(),
            const SizedBox(height: 32),
            _buildLengthSlider(),
            const SizedBox(height: 24),
            _buildOptions(),
            const SizedBox(height: 32),
            _buildGenerateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordDisplay() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.key, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _generatedPassword.isNotEmpty
                        ? _generatedPassword
                        : '点击生成按钮',
                    style: const TextStyle(
                      fontFamily: 'Monospace',
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyToClipboard,
                ),
              ],
            ),
            if (_generatedPassword.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text('密码强度'),
                    ),
                    Expanded(
                      flex: 5,
                      child: LinearProgressIndicator(
                        value: _passwordStrength.index / 3,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          PasswordStrengthChecker.getColor(_passwordStrength),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      PasswordStrengthChecker.getLabel(_passwordStrength),
                      style: TextStyle(
                        color:
                            PasswordStrengthChecker.getColor(_passwordStrength),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLengthSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('密码长度'),
            const Spacer(),
            Text('$_passwordLength 位'),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _passwordLength.toDouble(),
          min: 8,
          max: 32,
          divisions: 24,
          onChanged: (value) {
            setState(() => _passwordLength = value.toInt());
          },
          onChangeEnd: (_) => _generatePassword(),
        ),
      ],
    );
  }

  Widget _buildOptions() {
    return Column(
      children: [
        _buildOptionTile('包含大写字母', _includeUppercase, (value) {
          setState(() => _includeUppercase = value);
        }),
        _buildOptionTile('包含小写字母', _includeLowercase, (value) {
          setState(() => _includeLowercase = value);
        }),
        _buildOptionTile('包含数字', _includeNumbers, (value) {
          setState(() => _includeNumbers = value);
        }),
        _buildOptionTile('包含特殊字符', _includeSpecialChars, (value) {
          setState(() => _includeSpecialChars = value);
        }),
      ],
    );
  }

  Widget _buildOptionTile(
      String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (newValue) {
        onChanged(newValue);
        if (_includeUppercase ||
            _includeLowercase ||
            _includeNumbers ||
            _includeSpecialChars) {
          _generatePassword();
        }
      },
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (!_includeUppercase &&
              !_includeLowercase &&
              !_includeNumbers &&
              !_includeSpecialChars) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请至少选择一种字符类型')),
            );
            return;
          }
          _generatePassword();
        },
        child: const Text('生成密码'),
      ),
    );
  }
}
