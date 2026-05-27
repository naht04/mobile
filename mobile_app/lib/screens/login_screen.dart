import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/admin_dashboard_screen.dart';
import 'package:mobile_app/screens/home_shell_screen.dart';
import 'package:mobile_app/screens/microsoft_login_webview_screen.dart';
import 'package:mobile_app/services/notification_socket_service.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  Future<void> _onMicrosoftLoginPressed() async {
    final emailHint = _emailController.text.trim();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MicrosoftLoginWebViewScreen(emailHint: emailHint),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đăng nhập Outlook đang ở chế độ demo do chưa access domain.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    String username = '';
    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse('${AppApi.users}/login/'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đăng nhập thất bại. Kiểm tra lại email hoặc mật khẩu.',
            ),
          ),
        );
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final access = (body['access'] ?? '').toString();
      final refresh = (body['refresh'] ?? '').toString();
      username = (body['username'] ?? '').toString();
      if (access.isEmpty || refresh.isEmpty || username.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không nhận được token đăng nhập.')),
        );
        return;
      }

      await AppSession.saveLogin(
        usernameValue: username,
        accessTokenValue: access,
        refreshTokenValue: refresh,
      );
      await AppSession.init();
      NotificationSocketService.instance.connect();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể kết nối backend.')),
      );
      return;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;

    // LOGIC PHÂN LUỒNG:
    // Nếu email là admin@stu.ptit.edu.vn hoặc có chứa từ 'admin' ở tiền tố
    if (email == 'admin@stu.ptit.edu.vn' || username.startsWith('admin')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else {
      // Các trường hợp sinh viên thông thường
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShellScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const Text(
                      'Chào\nMừng',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icons.person_outline,
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return 'Vui lòng nhập email';
                        if (!text.contains('@')) return 'Email không hợp lệ';
                        if (!text.toLowerCase().endsWith('.edu.vn')) {
                          return 'Vui lòng dùng email edu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration(
                        hintText: 'Mật khẩu',
                        prefixIcon: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Quên mật khẩu',
                          style: TextStyle(color: Color(0xFFF6577D)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _onLoginPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF33B6D),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Đăng nhập với P-connect',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        '- Tiếp tục với -',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _onMicrosoftLoginPressed,
                            borderRadius: BorderRadius.circular(22),
                            child: Ink(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.mark_email_read_outlined,
                                color: Color(0xFF0C75D8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Đăng nhập Outlook (demo)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Chưa access domain',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0C75D8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: Colors.black54),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF33B6D)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
