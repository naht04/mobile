import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/avatar_utils.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/login_screen.dart';

import 'package:mobile_app/core/app_api.dart';

class ProfileScreen extends StatefulWidget {
  final String? targetUsername;

  const ProfileScreen({super.key, this.targetUsername});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

Widget _buildAvatar(String name, {double radius = 34}) {
  return initialsAvatar(name, radius: radius);
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  bool _loaded = false;

  // ⭐ QUAN TRỌNG
  Map<String, dynamic>? _profileData;

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: '********');
  final _fullName = TextEditingController();
  final _classCode = TextEditingController();
  final _studentId = TextEditingController();
  final _dob = TextEditingController();
  final _major = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _gender = TextEditingController();

  bool get _isOwnProfile => widget.targetUsername == null;

  @override
  void initState() {
    super.initState();
    _loadProfile(); // ✅ FIX CHÍNH
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _classCode.dispose();
    _studentId.dispose();
    _dob.dispose();
    _major.dispose();
    _phone.dispose();
    _address.dispose();
    _gender.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final uri = Uri.parse('${AppApi.users}/profile/').replace(
        queryParameters: _isOwnProfile
            ? {'username': AppSession.username}
            : {'target_username': widget.targetUsername!},
      );

      final res = await http.get(uri, headers: AppSession.authHeaders());

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // ⭐ QUAN TRỌNG
        _profileData = data;

        _username.text = (data['username'] ?? '').toString();
        _email.text = (data['email'] ?? '').toString();
        _fullName.text = (data['full_name'] ?? '').toString();
        _classCode.text = (data['class_code'] ?? '').toString();
        _studentId.text = (data['student_id'] ?? '').toString();
        _dob.text = (data['date_of_birth'] ?? '').toString();
        _major.text = (data['major'] ?? '').toString();
        _phone.text = (data['phone'] ?? '').toString();
        _address.text = (data['address'] ?? '').toString();
        _gender.text = (data['gender'] ?? '').toString();
      } else {
        _showError('Không tải được thông tin (${res.statusCode})');
      }
    } catch (e) {
      _showError('Lỗi load profile: $e');
    } finally {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final res = await http.patch(
        Uri.parse(
          '${AppApi.users}/profile/',
        ).replace(queryParameters: {'username': AppSession.username}),
        headers: AppSession.authHeaders(
          extra: const {'Content-Type': 'application/json'},
        ),
        body: jsonEncode({
          'username': AppSession.username,
          'full_name': _fullName.text.trim(),
          'class_code': _classCode.text.trim(),
          'student_id': _studentId.text.trim(),
          'date_of_birth': _dob.text.trim(),
          'major': _major.text.trim(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
          'gender': _gender.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        setState(() => _isEditing = false);

        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Thành công'),
            content: Text('Cập nhật thành công'),
          ),
        );
      } else {
        _showError('Cập nhật thất bại');
      }
    } catch (e) {
      _showError('Lỗi update: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await AppSession.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'Thông tin tài khoản' : 'Hồ sơ'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: _buildAvatar(
                _fullName.text.isEmpty ? _username.text : _fullName.text,
                radius: 34,
              ),
            ),

            const SizedBox(height: 16),

            _field(_username, 'Username', enabled: false),
            _field(_email, 'Email', enabled: false),

            _field(_fullName, 'Họ tên'),
            _field(_classCode, 'Lớp'),
            _field(_studentId, 'Mã SV'),
            _field(_dob, 'Ngày sinh'),
            _field(_major, 'Ngành'),
            _field(_phone, 'SĐT'),
            _field(_gender, 'Giới tính'),
            _field(_address, 'Địa chỉ'),

            const SizedBox(height: 16),

            if (_isOwnProfile)
              ElevatedButton(
                onPressed: _isEditing
                    ? _saveProfile
                    : () => setState(() => _isEditing = true),
                child: Text(_isEditing ? 'Lưu' : 'Chỉnh sửa'),
              ),
            if (_isOwnProfile) const SizedBox(height: 8),
            if (_isOwnProfile)
              OutlinedButton(
                onPressed: _logout,
                child: const Text('Đăng xuất'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool enabled = true}) {
    final canEdit = _isOwnProfile && enabled && _isEditing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        enabled: canEdit,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
