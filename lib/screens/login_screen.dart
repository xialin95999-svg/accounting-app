import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLogin = true; // true=登录 false=注册
  bool _obscurePin = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty || pin.isEmpty) {
      _showError('请填写手机号和PIN');
      return;
    }
    if (phone.length != 11) {
      _showError('手机号必须是11位');
      return;
    }
    if (pin.length != 6) {
      _showError('PIN必须是6位数字');
      return;
    }

    if (_isLogin) {
      await ref.read(authProvider.notifier).login(phone, pin);
    } else {
      await ref.read(authProvider.notifier).register(phone, pin);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        _showError(next.error!);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF4A90E2),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo区域
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('🐂', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '小牛记账',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '数据存在自己的NAS',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
            ),
            const Spacer(),
            // 表单区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin ? '登录' : '注册',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // 手机号
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '手机号',
                      hintText: '请输入11位手机号',
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // PIN码
                  TextField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'PIN码',
                      hintText: '6位数字',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_isLogin)
                    Text(
                      '注册后可用此手机号+PIN登录，数据存储在你自己NAS',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 16),
                  // 提交按钮
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isLogin ? '登录' : '注册', style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  // 切换登录/注册
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? '没有账号？去注册' : '已有账号？去登录',
                      style: const TextStyle(color: Color(0xFF4A90E2)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
