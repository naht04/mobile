import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/community_screen.dart';
import 'package:mobile_app/screens/feed_screen.dart';
import 'package:mobile_app/screens/friends_screen.dart';
import 'package:mobile_app/screens/messages_screen.dart';
import 'package:mobile_app/screens/notifications_screen.dart';

/// Root tab shell that also refreshes unread chat/notification/friend badges.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;
  int _messageBadge = 0;
  int _notificationBadge = 0;
  int _friendBadge = 0;
  Timer? _timer;

  late final List<Widget> _tabs = const [
    FeedScreen(),
    CommunityScreen(),
    MessagesScreen(),
    NotificationsScreen(),
    FriendsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadBadges();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadBadges());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    final params = {'username': AppSession.username};
    try {
      // External HTTP API: GET /api/notifications/badges/ returns compact badge counters.
      final response = await http
          .get(
            Uri.parse(
              '${AppApi.notifications}/badges/',
            ).replace(queryParameters: params),
            headers: AppSession.authHeaders(),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _messageBadge = (data['messages'] as num?)?.toInt() ?? 0;
        _notificationBadge = (data['notifications'] as num?)?.toInt() ?? 0;
        _friendBadge = (data['friends'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Widget _iconWithBadge(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Cộng đồng',
          ),
          NavigationDestination(
            icon: _iconWithBadge(Icons.chat_bubble_outline, _messageBadge),
            label: 'Tin nhắn',
          ),
          NavigationDestination(
            icon: _iconWithBadge(Icons.notifications_none, _notificationBadge),
            label: 'Thông báo',
          ),
          NavigationDestination(
            icon: _iconWithBadge(Icons.group_outlined, _friendBadge),
            label: 'Bạn bè',
          ),
        ],
      ),
    );
  }
}
