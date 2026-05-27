// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/core/avatar_utils.dart';
import 'package:mobile_app/screens/messages_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';

Widget _avatar(String name, {double radius = 20}) {
  return initialsAvatar(name, radius: radius);
}

/// Friend management screen for accepted friends, requests, suggestions, and search.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;

  List<_RequestItem> _requests = [];
  List<_RequestItem> _sent = [];
  List<_ProfileMini> _friends = [];
  List<_ProfileMini> _suggestions = [];

  Timer? _timer;
  Timer? _searchDebounce;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _friendSearchController = TextEditingController();

  List<_ProfileMini> _searchResults = [];
  bool _searching = false;
  final Set<String> _hiddenSuggestionUsernames = <String>{};

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _friendSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<_ApiResponse> _safeGet(String url) async {
    try {
      // External HTTP API: shared GET helper for friend endpoints.
      final res = await http
          .get(Uri.parse(url), headers: AppSession.authHeaders())
          .timeout(const Duration(seconds: 8));
      return _ApiResponse(statusCode: res.statusCode, body: res.body);
    } catch (_) {
      return const _ApiResponse(statusCode: 0, body: '');
    }
  }

  List<dynamic> _decodeList(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    // External HTTP APIs: load inbox, sent requests, friends, and suggestions together.
    final results = await Future.wait([
      _safeGet('${AppApi.users}/friends/requests/inbox/'),
      _safeGet('${AppApi.users}/friends/requests/sent/'),
      _safeGet('${AppApi.users}/friends/'),
      _safeGet('${AppApi.users}/friends/suggestions/'),
    ]);

    if (!mounted) return;

    final inboxOk = results[0].statusCode == 200;
    final sentOk = results[1].statusCode == 200;
    final friendsOk = results[2].statusCode == 200;
    final suggestionsOk = results[3].statusCode == 200;

    final requests = inboxOk
        ? _decodeList(results[0].body)
              .map(
                (e) => _RequestItem.fromJson(
                  e as Map<String, dynamic>,
                  incoming: true,
                ),
              )
              .toList()
        : _requests;

    final sent = sentOk
        ? _decodeList(results[1].body)
              .map(
                (e) => _RequestItem.fromJson(
                  e as Map<String, dynamic>,
                  incoming: false,
                ),
              )
              .toList()
        : _sent;

    final friends = friendsOk
        ? ((_decodeMap(results[2].body)['friends'] as List<dynamic>? ??
                  const [])
              .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
              .toList())
        : _friends;

    final suggestions = suggestionsOk
        ? ((_decodeMap(results[3].body)['results'] as List<dynamic>? ??
                  const [])
              .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
              .where((e) => !_hiddenSuggestionUsernames.contains(e.username))
              .toList())
        : _suggestions;

    setState(() {
      _requests = requests;
      _sent = sent;
      _friends = friends;
      _suggestions = suggestions;
      _loading = false;
    });

    if (!friendsOk && !silent) {
      _showSnack('Không thể tải danh sách bạn bè.');
    } else if ((!inboxOk || !sentOk || !suggestionsOk) && !silent) {
      _showSnack(
        'Một phần dữ liệu chưa tải được, ứng dụng đang hiển thị phần còn lại.',
      );
    }
  }

  void _openUserCard(
    _ProfileMini profile,
    String type, {
    _RequestItem? request,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatar(
                profile.fullName.isEmpty ? profile.username : profile.fullName,
                radius: 34,
              ),
              const SizedBox(height: 12),
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(profile.studentId),
              Text(profile.email),
              const SizedBox(height: 8),
              Text(
                'Lớp: ${profile.classCode} • Ngành: ${profile.major}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (type == 'friend')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessagesScreen(
                                openPeerUsername: profile.username,
                              ),
                            ),
                          );
                        },
                        child: const Text('Nhắn tin'),
                      ),
                    ),
                  if (type == 'request') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _decide(request!, 'reject');
                        },
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _decide(request!, 'accept');
                        },
                        child: const Text('Đồng ý'),
                      ),
                    ),
                  ],
                  if (type == 'suggestion') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Đóng'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _sendRequest(profile.username);
                        },
                        child: const Text('Kết bạn'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _decide(_RequestItem item, String action) async {
    // External HTTP API: POST /api/users/friends/requests/{id}/decide/.
    final res = await http.post(
      Uri.parse('${AppApi.users}/friends/requests/${item.id}/decide/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'action': action}),
    );
    if (res.statusCode >= 400) {
      _showSnack('Không thể cập nhật lời mời kết bạn.');
      return;
    }
    _load();
  }

  Future<void> _sendRequest(String username) async {
    // External HTTP API: POST /api/users/friends/requests/send/.
    final res = await http.post(
      Uri.parse('${AppApi.users}/friends/requests/send/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'to_username': username}),
    );
    if (res.statusCode >= 400) {
      _showSnack('Không gửi được lời mời kết bạn.');
      return;
    }
    _showSnack('Đã gửi lời mời kết bạn.');
    _load();
    if (_searchController.text.trim().isNotEmpty) {
      await _searchUsers(_searchController.text.trim());
    }
  }

  Future<void> _searchUsers(String rawQuery) async {
    final q = rawQuery.trim();

    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final uri = Uri.parse(
        '${AppApi.users}/search/',
      ).replace(queryParameters: {'q': q});
      // External HTTP API: GET /api/users/search/ searches people outside current lists.
      final res = await http
          .get(uri, headers: AppSession.authHeaders())
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final blockedUsernames = <String>{
          ..._friends.map((e) => e.username),
          ..._requests.map((e) => e.profile.username),
          ..._sent.map((e) => e.profile.username),
        };

        final results = (body['results'] as List<dynamic>? ?? [])
            .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
            .where((e) => !blockedUsernames.contains(e.username))
            .where((e) => !_hiddenSuggestionUsernames.contains(e.username))
            .toList();

        setState(() {
          _searchResults = results;
          _searching = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
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

  Widget _buildSectionHeader(String title, String caption) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required _ProfileMini profile,
    required String subtitle,
    required List<Widget> actions,
    required VoidCallback onTap,
    String? tag,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(
                profile.fullName.isEmpty ? profile.username : profile.fullName,
                radius: 24,
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
                            profile.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (profile.classCode.isNotEmpty ||
                        profile.major.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${profile.classCode} • ${profile.major}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(children: actions),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    final query = _friendSearchController.text.trim().toLowerCase();
    final filteredFriends = query.isEmpty
        ? _friends
        : _friends.where((f) {
            final fullName = f.fullName.toLowerCase();
            final studentId = f.studentId.toLowerCase();
            final username = f.username.toLowerCase();
            return fullName.contains(query) ||
                studentId.contains(query) ||
                username.contains(query);
          }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSectionHeader(
          'Mạng lưới bạn bè',
          'Tìm nhanh và mở chat với những kết nối đã xác nhận.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _friendSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc mã sinh viên',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _friendSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _friendSearchController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        if (filteredFriends.isEmpty)
          _buildEmptyState(
            icon: Icons.group_outlined,
            title: query.isEmpty ? 'Chưa có bạn bè' : 'Không tìm thấy kết quả',
            subtitle: query.isEmpty
                ? 'Sau khi chấp nhận lời mời, danh sách bạn bè sẽ hiện ở đây.'
                : 'Thử tìm bằng tên đầy đủ, username hoặc mã sinh viên.',
          )
        else
          ...filteredFriends.map(
            (f) => _buildProfileCard(
              profile: f,
              subtitle: '${f.studentId} • ${f.email}',
              actions: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openUserCard(f, 'friend'),
                    child: const Text('Xem hồ sơ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MessagesScreen(openPeerUsername: f.username),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: const Text('Nhắn tin'),
                  ),
                ),
              ],
              onTap: () => _openUserCard(f, 'friend'),
              tag: 'Bạn bè',
            ),
          ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSectionHeader(
          'Quản lý lời mời',
          'Phân loại lời mời đến và các yêu cầu đang chờ phản hồi.',
        ),
        if (_requests.isEmpty)
          _buildEmptyState(
            icon: Icons.mail_outline_rounded,
            title: 'Không có lời mời mới',
            subtitle:
                'Khi có sinh viên gửi lời mời kết bạn, mục này sẽ cập nhật.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Lời mời nhận được',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ..._requests.map(
            (e) => _buildProfileCard(
              profile: e.profile,
              subtitle: '${e.profile.studentId} • ${e.profile.email}',
              actions: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(e, 'reject'),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decide(e, 'accept'),
                    child: const Text('Chấp nhận'),
                  ),
                ),
              ],
              onTap: () => _openUserCard(e.profile, 'request', request: e),
              tag: 'Chờ xử lý',
            ),
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text('Đã gửi', style: Theme.of(context).textTheme.titleMedium),
        ),
        if (_sent.isEmpty)
          _buildEmptyState(
            icon: Icons.send_outlined,
            title: 'Bạn chưa gửi lời mời nào',
            subtitle: 'Sang tab Gợi ý để tìm thêm kết nối mới.',
          )
        else
          ..._sent.map(
            (e) => _buildProfileCard(
              profile: e.profile,
              subtitle: '${e.profile.studentId} • ${e.profile.email}',
              actions: const [
                Expanded(
                  child: FilledButton(
                    onPressed: null,
                    child: Text('Đang chờ phản hồi'),
                  ),
                ),
              ],
              onTap: () => _openUserCard(e.profile, 'suggestion'),
              tag: 'Đang chờ',
            ),
          ),
      ],
    );
  }

  Widget _buildAddFriendTab() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final items = hasQuery ? _searchResults : _suggestions;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSectionHeader(
          'Kết nối mới',
          'Tìm sinh viên theo tên, mã sinh viên và gửi lời mời ngay trong app.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                _searchUsers(value);
              });
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc mã sinh viên',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        _searchUsers('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          _buildEmptyState(
            icon: Icons.search_rounded,
            title: hasQuery ? 'Không tìm thấy người phù hợp' : 'Chưa có gợi ý',
            subtitle: hasQuery
                ? 'Thử đổi từ khóa tìm kiếm để mở rộng kết quả.'
                : 'Hệ thống sẽ đề xuất những sinh viên có thể bạn quen.',
          )
        else
          ...items.map(
            (s) => _buildProfileCard(
              profile: s,
              subtitle: '${s.studentId} • ${s.email}',
              actions: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _hiddenSuggestionUsernames.add(s.username);
                        _suggestions.removeWhere(
                          (e) => e.username == s.username,
                        );
                        _searchResults.removeWhere(
                          (e) => e.username == s.username,
                        );
                      });
                    },
                    child: const Text('Bỏ qua'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendRequest(s.username),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Kết bạn'),
                  ),
                ),
              ],
              onTap: () => _openUserCard(s, 'suggestion'),
              tag: hasQuery ? 'Kết quả tìm' : 'Gợi ý',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Bạn bè'),
            Tab(text: 'Lời mời'),
            Tab(text: 'Gợi ý'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0F5), Color(0xFFFFD7E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kết bạn PTIT',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Quản lý kết nối, xử lý lời mời và mở chat nhanh.',
                        style: TextStyle(
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
                            _buildStatCard(
                              label: 'Bạn bè',
                              value: '${_friends.length}',
                              icon: Icons.group_rounded,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              label: 'Lời mời mới',
                              value: '${_requests.length}',
                              icon: Icons.mail_outline_rounded,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              label: 'Gợi ý',
                              value: '${_suggestions.length}',
                              icon: Icons.search_rounded,
                            ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsTab(),
                  _buildRequestsTab(),
                  _buildAddFriendTab(),
                ],
              ),
            ),
    );
  }
}

class _ApiResponse {
  final int statusCode;
  final String body;

  const _ApiResponse({required this.statusCode, required this.body});
}

/// Client-side DTO for one incoming or outgoing friend request.
class _RequestItem {
  final int id;
  final _ProfileMini profile;

  _RequestItem({required this.id, required this.profile});

  factory _RequestItem.fromJson(
    Map<String, dynamic> json, {
    required bool incoming,
  }) {
    return _RequestItem(
      id: json['id'] ?? 0,
      profile: _ProfileMini.fromJson(
        (incoming ? json['from_profile'] : json['to_profile'])
                as Map<String, dynamic>? ??
            const {},
      ),
    );
  }
}

/// Compact profile DTO reused by friends, suggestions, and search results.
class _ProfileMini {
  final String username;
  final String fullName;
  final String studentId;
  final String email;
  final String classCode;
  final String major;
  final String avatar;

  _ProfileMini({
    required this.username,
    required this.fullName,
    required this.studentId,
    required this.email,
    required this.classCode,
    required this.major,
    required this.avatar,
  });

  factory _ProfileMini.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString();
    final fullName = (json['full_name'] ?? '').toString();
    return _ProfileMini(
      username: username,
      fullName: fullName.isEmpty ? username : fullName,
      studentId: (json['student_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      classCode: (json['class_code'] ?? '').toString(),
      major: (json['major'] ?? '').toString(),
      avatar: (json['avatar_url'] ?? json['avatar'] ?? '').toString(),
    );
  }
}
