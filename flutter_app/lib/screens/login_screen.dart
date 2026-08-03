import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController(text: '');
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      _showMsg('请输入11位手机号');
      return;
    }
    setState(() => _isLoading = true);
    try {
      // 使用 AuthNotifier 发送验证码
      await ref.read(authProvider.notifier).sendCode(phone);
      setState(() {
        _codeSent = true;
        _countdown = 60;
      });
      _startCountdown();
      _showMsg('验证码已发送', isSuccess: true);
    } catch (e) {
      _showMsg('发送失败：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown = _countdown - 1);
      return _countdown > 0;
    });
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.length != 11) { _showMsg('请输入11位手机号'); return; }
    if (code.length != 6) { _showMsg('请输入6位验证码'); return; }

    setState(() => _isLoading = true);
    try {
      // 使用 AuthNotifier 验证验证码（内部自动保存token）
      await ref.read(authProvider.notifier).verifyCode(phone, code);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      _showMsg('登录失败：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? const Color(0xFF67B26F) : const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo + 标题
              Center(child: _Logo()),
              const SizedBox(height: 40),
              const Text('手机号登录', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              const Text('未注册的手机号将自动创建账号', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
              const SizedBox(height: 36),

              // 手机号输入
              _PhoneInput(controller: _phoneController, enabled: !_isLoading),
              const SizedBox(height: 16),

              // 验证码输入 + 发送按钮
              _CodeInput(
                controller: _codeController,
                countdown: _countdown,
                codeSent: _codeSent,
                isLoading: _isLoading,
                onSendCode: _sendCode,
              ),
              const SizedBox(height: 36),

              // 登录按钮
              _LoginButton(isLoading: _isLoading, onPressed: _login),
              const SizedBox(height: 24),

              // 底部说明
              const Center(
                child: Text(
                  '登录即表示同意《小牛记账用户协议》',
                  style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Logo ====================
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF6BB3F8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: const Color(0xFF4A90E2).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        const Text('小牛记账', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        const Text('数据存在自己的NAS', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
      ],
    );
  }
}

// ==================== 手机号输入 ====================
class _PhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _PhoneInput({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.phone_android, color: Color(0xFF4A90E2)),
          hintText: '请输入手机号',
          hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontWeight: FontWeight.normal),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
      ),
    );
  }
}

// ==================== 验证码输入 ====================
class _CodeInput extends StatelessWidget {
  final TextEditingController controller;
  final int countdown;
  final bool codeSent;
  final bool isLoading;
  final VoidCallback onSendCode;
  const _CodeInput({required this.controller, required this.countdown, required this.codeSent, required this.isLoading, required this.onSendCode});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 4),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '6位验证码',
                hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontWeight: FontWeight.normal, letterSpacing: 0),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: (isLoading || countdown > 0) ? null : onSendCode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (isLoading || countdown > 0) ? const Color(0xFFF5F7FA) : const Color(0xFF4A90E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              countdown > 0 ? '${countdown}s' : (codeSent ? '重新获取' : '获取验证码'),
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: (isLoading || countdown > 0) ? const Color(0xFF888888) : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 登录按钮 ====================
class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF4A90E2).withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('登录 / 注册', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
