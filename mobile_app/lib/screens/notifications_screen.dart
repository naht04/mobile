import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/core/avatar_utils.dart';
import 'package:mobile_app/screens/community_screen.dart';
import 'package:mobile_app/screens/friends_screen.dart';
import 'package:mobile_app/screens/messages_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';

/// Notification center for messages, friend events, posts, groups, and system notices.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<_NotifyItem> _items = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final uri = Uri.parse('${AppApi.notifications}/').replace(
      queryParameters: {'username': AppSession.username},
    );

    try {
      // External HTTP API: GET /api/notifications/ returns the newest notifications.
      final res = await http
          .get(uri, headers: AppSession.authHeaders())
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _NotifyItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _items = list;
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
    if (!silent) {
      _showSnack('Không thể tải thông báo.');
    }
  }

  Future<void> _readAll() async {
    // External HTTP API: POST /api/notifications/read-all/ marks every notice read.
    await http.post(
      Uri.parse('${AppApi.notifications}/read-all/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'username': AppSession.username}),
    );
    _load(silent: true);
  }

  Future<void> _markRead(_NotifyItem item) async {
    // External HTTP API: POST /api/notifications/{id}/read/ marks one notice read.
    await http.post(
      Uri.parse('${AppApi.notifications}/${item.id}/read/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'username': AppSession.username}),
    );
    item.isRead = true;
  }

  Future<void> _deleteNotification(_NotifyItem item) async {
    // External HTTP API: DELETE /api/notifications/{id}/delete/ removes one notice.
    await http.delete(
      Uri.parse('${AppApi.notifications}/${item.id}/delete/').replace(
        queryParameters: {'username': AppSession.username},
      ),
      headers: AppSession.authHeaders(),
    );
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
  }

  Future<void> _openTarget(_NotifyItem item) async {
    // Route notification payloads to their target feature after marking them read.
    await _markRead(item);
    if (!mounted) return;

    switch (item.notificationType) {
      case 'message':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessagesScreen(
              openConversationId: item.conversationId,
              openPeerUsername: item.targetUsername,
            ),
          ),
        );
        break;
      case 'friend_request':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen(initialTab: 1)),
        );
        break;
      case 'friend_accept':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen(initialTab: 0)),
        );
        break;
      case 'post_like':
      case 'post_comment':
      case 'post_new':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityScreen(initialPostId: item.postId),
          ),
        );
        break;
      default:
        break;
    }

    setState(() {});
  }

  String _fmt(String value) {
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return '';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'friend_request':
      case 'friend_accept':
        return Icons.person_add_alt_1_rounded;
      case 'post_like':
        return Icons.favorite_rounded;
      case 'post_comment':
        return Icons.mode_comment_rounded;
      case 'post_new':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'message':
        return 'Tin nhắn';
      case 'friend_request':
        return 'Lời mời kết bạn';
      case 'friend_accept':
        return 'Kết bạn';
      case 'post_like':
        return 'Tim bài viết';
      case 'post_comment':
        return 'Bình luận';
      case 'post_new':
        return 'Bài viết mới';
      default:
        return 'Hệ thống';
    }
  }

  Color _typeTint(String type) {
    switch (type) {
      case 'message':
        return const Color(0xFFE84D8A);
      case 'friend_request':
      case 'friend_accept':
        return const Color(0xFFFF7A59);
      case 'post_like':
        return const Color(0xFFE53935);
      case 'post_comment':
        return const Color(0xFF1E88E5);
      case 'post_new':
        return const Color(0xFFD63C6C);
      default:
        return AppColors.primaryDark;
    }
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color tint,
  }) {
    return SizedBox(
      width: 168,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, 8),
              color: Color(0x12000000),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((e) => !e.isRead).length;
    final messageCount = _items.where((e) => e.notificationType == 'message').length;
    final friendCount = _items
        .where(
          (e) =>
              e.notificationType == 'friend_request' ||
              e.notificationType == 'friend_accept',
        )
        .length;
    final likeCount = _items.where((e) => e.notificationType == 'post_like').length;
    final commentCount =
        _items.where((e) => e.notificationType == 'post_comment').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          TextButton(onPressed: _readAll, child: const Text('Đọc hết')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF1F5), Color(0xFFFFD9E6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trung tâm thông báo',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Theo dõi tin nhắn mới, kết bạn, tim và bình luận bài viết ở cùng một nơi. Chưa đọc: $unreadCount',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildSummaryCard(
                                  label: 'Tin nhắn',
                                  value: '$messageCount',
                                  icon: Icons.forum_rounded,
                                  tint: _typeTint('message'),
                                ),
                                const SizedBox(width: 12),
                                _buildSummaryCard(
                                  label: 'Kết bạn',
                                  value: '$friendCount',
                                  icon: Icons.person_add_alt_1_rounded,
                                  tint: _typeTint('friend_accept'),
                                ),
                                const SizedBox(width: 12),
                                _buildSummaryCard(
                                  label: 'Tim',
                                  value: '$likeCount',
                                  icon: Icons.favorite_rounded,
                                  tint: _typeTint('post_like'),
                                ),
                                const SizedBox(width: 12),
                                _buildSummaryCard(
                                  label: 'Bình luận',
                                  value: '$commentCount',
                                  icon: Icons.mode_comment_rounded,
                                  tint: _typeTint('post_comment'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 42,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Chưa có thông báo nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Khi có tin nhắn, kết bạn, tim hoặc bình luận bài viết, mục này sẽ hiển thị tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._items.map((item) {
                      final tint = _typeTint(item.notificationType);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: item.isRead
                              ? AppColors.surface
                              : const Color(0xFFFFF5F8),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: item.isRead ? AppColors.outline : tint,
                            width: item.isRead ? 1 : 1.2,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _openTarget(item),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    initialsAvatar(
                                      item.targetUsername.isEmpty
                                          ? item.title
                                          : item.targetUsername,
                                      radius: 24,
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: tint,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          _typeIcon(item.notificationType),
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (!item.isRead)
                                            Container(
                                              width: 10,
                                              height: 10,
                                              margin: const EdgeInsets.only(left: 8),
                                              decoration: BoxDecoration(
                                                color: tint,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tint.withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _typeLabel(item.notificationType),
                                              style: TextStyle(
                                                color: tint,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _fmt(item.createdAt),
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        item.content,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Text(
                                            'Xem chi tiết',
                                            style: TextStyle(
                                              color: tint,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: tint,
                                          ),
                                          const Spacer(),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'delete') {
                                                _deleteNotification(item);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Xóa'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

/// Client-side DTO for one notification returned by /api/notifications/.
class _NotifyItem {
  _NotifyItem({
    required this.id,
    required this.title,
    required this.content,
    required this.notificationType,
    required this.targetUsername,
    required this.createdAt,
    required this.avatarUrl,
    required this.postId,
    required this.isRead,
    this.conversationId,
  });

  final int id;
  final String title;
  final String content;
  final String notificationType;
  final String targetUsername;
  final String createdAt;
  final int? conversationId;
  final int? postId;
  final String avatarUrl;
  bool isRead;

  factory _NotifyItem.fromJson(Map<String, dynamic> json) {
    return _NotifyItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      notificationType: (json['notification_type'] ?? 'system').toString(),
      targetUsername: (json['target_username'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatar'] ?? '').toString(),
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      postId: (json['post_id'] as num?)?.toInt(),
      isRead: json['is_read'] == true,
    );
  }
}
