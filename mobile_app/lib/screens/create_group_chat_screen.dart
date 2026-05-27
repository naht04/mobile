import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/core/avatar_utils.dart';

class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  bool _loading = true;
  bool _creating = false;

  List<_UserMini> _friends = [];
  List<_UserMini> _filteredFriends = [];
  final Set<String> _selectedUsernames = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFriends);
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final res = await http
          .get(
            Uri.parse('${AppApi.friends}/'),
            headers: AppSession.authHeaders(),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);

        final list = (data is List
            ? data
            : (data['friends'] as List<dynamic>? ??
                  data['results'] as List<dynamic>? ??
                  <dynamic>[]));

        final users = list
            .map((e) => e as Map<String, dynamic>)
            .map((item) {
              if (item['username'] != null) {
                return _UserMini.fromJson(item);
              }

              final nestedUser =
                  (item['user'] as Map<String, dynamic>? ??
                  <String, dynamic>{});
              return _UserMini.fromJson(nestedUser);
            })
            .where((u) => u.username.isNotEmpty)
            .toList();

        setState(() {
          _friends = users;
          _filteredFriends = List<_UserMini>.from(users);
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không tải được danh sách bạn bè')),
    );
  }

  void _filterFriends() {
    final q = _searchController.text.trim().toLowerCase();

    setState(() {
      if (q.isEmpty) {
        _filteredFriends = List<_UserMini>.from(_friends);
      } else {
        _filteredFriends = _friends.where((u) {
          return u.fullName.toLowerCase().contains(q) ||
              u.studentId.toLowerCase().contains(q) ||
              u.username.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _toggleUser(String username) {
    setState(() {
      if (_selectedUsernames.contains(username)) {
        _selectedUsernames.remove(username);
      } else {
        _selectedUsernames.add(username);
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedUsernames.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhóm chat phải có ít nhất 2 thành viên')),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      final res = await http.post(
        Uri.parse('${AppApi.chat}/create-group/'),
        headers: AppSession.authHeaders(
          extra: const {'Content-Type': 'application/json'},
        ),
        body: jsonEncode({
          'title': _groupNameController.text.trim(),
          'usernames': _selectedUsernames.toList(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        Navigator.pop(context, body);
        return;
      }

      String message = 'Không thể tạo nhóm chat';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final detail = (body['detail'] ?? '').toString();
        if (detail.isNotEmpty) {
          message = detail;
        }
      } catch (_) {}

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi kết nối khi tạo nhóm chat')),
        );
      }
    }

    if (mounted) {
      setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selectedUsernames.length >= 2 && !_creating;

    return Scaffold(
      appBar: AppBar(title: const Text('Nhóm mới')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: 'Tên nhóm',
                    hintText: 'Nhập tên nhóm (không bắt buộc)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm bạn bè theo tên, mã SV, username',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Đã chọn ${_selectedUsernames.length} người',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                ? const Center(child: Text('Không có bạn bè phù hợp'))
                : ListView.separated(
                    itemCount: _filteredFriends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final user = _filteredFriends[index];
                      final selected = _selectedUsernames.contains(
                        user.username,
                      );

                      return ListTile(
                        leading: initialsAvatar(
                          user.fullName,
                          radius: 22,
                          fontSize: 12,
                        ),
                        title: Text(user.fullName),
                        subtitle: Text(
                          user.studentId.isEmpty
                              ? user.username
                              : '${user.studentId} • ${user.username}',
                        ),
                        trailing: Checkbox(
                          value: selected,
                          onChanged: (_) => _toggleUser(user.username),
                        ),
                        onTap: () => _toggleUser(user.username),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  child: _creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tiếp'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMini {
  _UserMini({
    required this.username,
    required this.fullName,
    required this.studentId,
  });

  final String username;
  final String fullName;
  final String studentId;

  factory _UserMini.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString();
    final fullName = (json['full_name'] ?? '').toString();

    return _UserMini(
      username: username,
      fullName: fullName.isEmpty ? username : fullName,
      studentId: (json['student_id'] ?? '').toString(),
    );
  }
}
