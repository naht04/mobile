import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final int members;
  final String category;
  final List<String> memberAvatars;
  final String coverColor;
  final bool isVerified;
  final bool isNew;
  final bool isPending;
  final bool isOwner;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.category,
    required this.memberAvatars,
    required this.coverColor,
    this.isVerified = false,
    this.isNew = false,
    this.isPending = false,
    this.isOwner = false,
  });
}

class _Group {
  _Group({
    required this.id,
    required this.title,
    required this.subject,
    required this.memberCount,
    required this.description,
    required this.category,
    required this.avatarUrl,
    required this.joinStatus,
    required this.isOwner,
  });

  final int id;
  final String title;
  final String subject;
  final int memberCount;
  final String description;
  final String category;
  final String avatarUrl;
  final String joinStatus;
  final bool isOwner;

  factory _Group.fromJson(Map<String, dynamic> json) {
    return _Group(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      joinStatus: (json['join_status'] ?? 'none').toString(),
      isOwner: (json['is_owner'] as bool?) ?? false,
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
    final fullName = (json['full_name'] ?? '').toString();
    final username = (json['username'] ?? '').toString();
    return _UserMini(
      username: username,
      fullName: fullName.isEmpty ? username : fullName,
      studentId: (json['student_id'] ?? '').toString(),
    );
  }
}

final List<GroupModel> trendingGroups = [
  GroupModel(
    id: '1',
    name: 'CultFit',
    description: 'Elevate Your Fitness Goal with Cult.fit | A Space Committed to Fitness, and Personal Growth.',
    members: 895,
    category: 'Fitness',
    memberAvatars: ['A', 'B', 'C'],
    coverColor: '#E91E63',
    isVerified: true,
  ),
  GroupModel(
    id: '2',
    name: '1% Club',
    description: 'Empowering Financial Futures | Join the 1% Club for Expert Personal Finance Insights.',
    members: 1203,
    category: 'Finance',
    memberAvatars: ['D', 'E', 'F'],
    coverColor: '#C2185B',
    isVerified: true,
    isNew: true,
  ),
];

final List<GroupModel> localGroups = [
  GroupModel(
    id: '3',
    name: 'UX Mastery',
    description: 'Empowering our UX designers with expert insights and practical tips.',
    members: 826,
    category: 'Design',
    memberAvatars: ['G', 'H', 'I'],
    coverColor: '#EC407A',
    isVerified: true,
  ),
  GroupModel(
    id: '4',
    name: 'Epicrew',
    description: 'A community centered around seeking and offering help. So that we all can grow.',
    members: 819,
    category: 'Community',
    memberAvatars: ['J', 'K', 'L'],
    coverColor: '#D81B60',
  ),
];

final List<GroupModel> searchResults = [
  GroupModel(
    id: '5',
    name: 'MOBIE nhóm 14',
    description: 'Elevate Your Fitness Goal with Cult.fit | A Space Committed to Fitness, and Personal Growth. 895 members including Janvhi Parun.',
    members: 895,
    category: 'Mobile',
    memberAvatars: ['M', 'N', 'O'],
    coverColor: '#E91E63',
    isVerified: true,
  ),
  GroupModel(
    id: '6',
    name: 'MOBIE ABC',
    description: 'Empowering Financial Futures | Join the 1% Club for Expert Personal Finance Insights.',
    members: 1203,
    category: 'Mobile',
    memberAvatars: ['P', 'Q', 'R'],
    coverColor: '#AD1457',
    isNew: true,
  ),
  GroupModel(
    id: '7',
    name: 'MOBIE XYZ',
    description: 'Empowering our UX designers with expert insights and practical tips.',
    members: 826,
    category: 'Mobile',
    memberAvatars: ['S', 'T', 'U'],
    coverColor: '#FF4F87',
    isVerified: true,
  ),
  GroupModel(
    id: '8',
    name: 'MOBIE EDF',
    description: 'A community centered seeking and offering help. So that we all can grow.',
    members: 819,
    category: 'Mobile',
    memberAvatars: ['V', 'W', 'X'],
    coverColor: '#C2185B',
  ),
];

class GroupScreen extends StatefulWidget {
  final bool embedded;
  const GroupScreen({super.key, this.embedded = false});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showSuggestions = false;
  String _searchQuery = '';
  bool _loading = true;
  List<_Group> _groups = [];
  Timer? _debounce;
  final List<String> _topSearches = ['Mobie', 'C++', 'python', 'Finance'];
  static const Color _cardBg = Color(0xFFFFFBFD);
  static const Color _cardBorder = Color(0xFFF5D7E3);

  List<GroupModel> get _groupModels {
    if (_groups.isEmpty) return [];
    return _groups
        .map(
          (g) => GroupModel(
            id: g.id.toString(),
            name: g.title,
            description: g.description,
            members: g.memberCount,
            category: g.category,
            memberAvatars: const ['A', 'B', 'C'],
            coverColor: '#E91E63',
            isVerified: g.isOwner || g.joinStatus == 'member',
            isPending: g.joinStatus == 'pending',
            isOwner: g.isOwner,
          ),
        )
        .toList();
  }

  List<GroupModel> get _trendingGroups => _groupModels.take(6).toList();
  List<GroupModel> get _localGroups => _groupModels.skip(6).take(6).toList();
  List<GroupModel> get _searchResultGroups => _groupModels;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final params = <String, String>{if (_searchQuery.trim().isNotEmpty) 'q': _searchQuery.trim()};
    final uri = Uri.parse('${AppApi.groups}/').replace(queryParameters: params);
    try {
      final res = await http.get(uri, headers: AppSession.authHeaders());
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>).map((e) => _Group.fromJson(e as Map<String, dynamic>)).toList();
        if (!mounted) return;
        setState(() {
          _groups = list;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _joinGroup(GroupModel group) async {
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${group.id}/join/'),
      headers: AppSession.authHeaders(extra: const {'Content-Type': 'application/json'}),
      body: jsonEncode(const {}),
    );
    if (!mounted) return;
    if (res.statusCode == 201 || res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu tham gia nhóm')));
      _load();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể tham gia nhóm')));
  }

  Future<List<_UserMini>> _fetchFriends() async {
    final res = await http.get(
      Uri.parse('${AppApi.users}/friends/'),
      headers: AppSession.authHeaders(),
    );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['friends'] as List<dynamic>? ?? [])
        .map((e) => _UserMini.fromJson(e as Map<String, dynamic>))
        .where((u) => u.username != AppSession.username)
        .toList();
  }

  Future<Set<String>> _pickFriendsForInvite({
    Set<String>? initialSelection,
  }) async {
    final friends = await _fetchFriends();
    final selected = <String>{...(initialSelection ?? <String>{})};
    var query = '';
    List<_UserMini> visible = List<_UserMini>.from(friends);
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void applyFilter(String v) {
            query = v.trim().toLowerCase();
            visible = friends.where((f) {
              final hay = '${f.fullName} ${f.studentId} ${f.username}'.toLowerCase();
              return hay.contains(query);
            }).toList();
            setDialogState(() {});
          }

          return AlertDialog(
            title: const Text('Mời bạn bè vào nhóm'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Tìm trong danh sách bạn bè',
                    ),
                    onChanged: applyFilter,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 280,
                    child: visible.isEmpty
                        ? const Center(child: Text('Không có bạn bè phù hợp'))
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (_, i) {
                              final u = visible[i];
                              final checked = selected.contains(u.username);
                              return CheckboxListTile(
                                value: checked,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(u.fullName),
                                subtitle: Text('${u.studentId} • ${u.username}'),
                                onChanged: (v) {
                                  if (v == true) {
                                    selected.add(u.username);
                                  } else {
                                    selected.remove(u.username);
                                  }
                                  setDialogState(() {});
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, initialSelection ?? <String>{}),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: Text('Chọn (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
    return picked ?? (initialSelection ?? <String>{});
  }

  Future<void> _inviteMember(GroupModel group, String username) async {
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${group.id}/invite/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'target_username': username}),
    );
    if (!mounted) return;
    if (res.statusCode == 201 || res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lời mời tham gia nhóm')),
      );
      _load();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể mời thành viên này')),
    );
  }

  Future<void> _showInviteMemberDialog(GroupModel group) async {
    final searchController = TextEditingController();
    final allFriends = await _fetchFriends();
    List<_UserMini> users = List<_UserMini>.from(allFriends);
    if (!mounted) return;
    final picked = await showDialog<_UserMini>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mời thành viên'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Tìm trong danh sách bạn bè',
                  ),
                  onChanged: (value) {
                    final q = value.trim().toLowerCase();
                    users = allFriends.where((u) {
                      final hay = '${u.fullName} ${u.studentId} ${u.username}'
                          .toLowerCase();
                      return hay.contains(q);
                    }).toList();
                    if (ctx.mounted) {
                      setDialogState(() {});
                    }
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 260,
                  child: users.isEmpty
                      ? const Center(child: Text('Không tìm thấy tài khoản'))
                      : ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final u = users[i];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.surfaceVariant,
                                child: Text(
                                  u.fullName.isEmpty
                                      ? '?'
                                      : u.fullName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(u.fullName),
                              subtitle: Text('${u.studentId} • ${u.username}'),
                              onTap: () => Navigator.pop(ctx, u),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _inviteMember(group, picked.username);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        if (!widget.embedded) _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _isSearching
              ? (_showSuggestions ? _buildSuggestions() : _buildSearchResults())
              : _buildGroupList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.arrow_back_ios_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSearchBar(),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        if (!_isSearching) {
          setState(() {
            _isSearching = true;
            _showSuggestions = true;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 42,
        decoration: BoxDecoration(
          color: _isSearching ? Colors.white : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: _isSearching
              ? Border.all(color: const Color(0xFFE8294E), width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: _isSearching ? const Color(0xFFE8294E) : const Color(0xFF9E9E9E),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Tìm kiếm nhóm...',
                        hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) {
                        setState(() {
                          _searchQuery = v;
                          _showSuggestions = v.isEmpty;
                        });
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), _load);
                      },
                      onSubmitted: (v) {
                        setState(() {
                          _searchQuery = v;
                          _showSuggestions = false;
                        });
                        _load();
                      },
                    )
                  : const Text('Tìm kiếm nhóm...', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('Trending Now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                    SizedBox(width: 6),
                    Icon(Icons.local_fire_department_rounded, color: AppColors.primary, size: 18),
                  ],
                ),
                if (!widget.embedded)
                  GestureDetector(
                    onTap: () => _showCreateGroupModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE8294E), Color(0xFFFF6B6B)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Tạo nhóm mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {},
                    child: const Text('Xem tất cả', style: TextStyle(fontSize: 13, color: Color(0xFFE8294E), fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _trendingGroups.isEmpty ? trendingGroups.length : _trendingGroups.length,
              itemBuilder: (ctx, i) => _trendingGroups.isEmpty ? _trendingGroupCard(trendingGroups[i]) : _trendingGroupCard(_trendingGroups[i]),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              children: [
                Text('Local Vaults', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                SizedBox(width: 6),
                Icon(Icons.location_on_rounded, color: AppColors.primaryDark, size: 16),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _localGroups.isEmpty ? _localGroupCard(localGroups[i]) : _localGroupCard(_localGroups[i]),
              childCount: _localGroups.isEmpty ? localGroups.length : _localGroups.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _trendingGroupCard(GroupModel group) {
    return GestureDetector(
      onTap: () => _showGroupDetail(context, group),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.85), AppColors.primaryDark.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _groupCoverWidget(group, fontSize: 36),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis),
                      ),
                      if (group.isVerified) const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                      if (group.isNew) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                          child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(group.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.4)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text('${group.members}', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _localGroupCard(GroupModel group) {
    return GestureDetector(
      onTap: () => _showGroupDetail(context, group),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.6), AppColors.primaryDark.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _groupCoverWidget(group, fontSize: 28),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis),
                      ),
                      if (group.isVerified) const Icon(Icons.verified_rounded, size: 13, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(group.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[500], height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text('${group.members}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text('Top tìm kiếm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500])),
          ),
          ..._topSearches.asMap().entries.map((e) => _suggestionTile(e.value, e.key + 1)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nhóm gợi ý', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                GestureDetector(
                  onTap: () => _showCreateGroupModal(context),
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: Color(0xFFE8294E)),
                      SizedBox(width: 2),
                      Text('Tạo nhóm', style: TextStyle(fontSize: 12, color: Color(0xFFE8294E), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionTile(String text, int rank) {
    return GestureDetector(
      onTap: () {
        _searchController.text = text;
        setState(() {
          _searchQuery = text;
          _showSuggestions = false;
        });
        _load();
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: rank <= 3 ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: rank <= 3 ? const Color(0xFFE8294E) : Colors.grey[500]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)))),
            Icon(Icons.north_west_rounded, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_searchResultGroups.isEmpty ? searchResults.length : _searchResultGroups.length} nhóm cho "$_searchQuery"', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Icon(Icons.sort_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('Sort', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(width: 12),
                  Icon(Icons.filter_list_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('Filter', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: _searchResultGroups.isEmpty ? searchResults.length : _searchResultGroups.length,
            itemBuilder: (ctx, i) => _searchResultGroups.isEmpty ? _searchResultGroupCard(searchResults[i]) : _searchResultGroupCard(_searchResultGroups[i]),
          ),
        ),
      ],
    );
  }

  Widget _searchResultGroupCard(GroupModel group) {
    return GestureDetector(
      onTap: () => _showGroupDetail(context, group),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.85), AppColors.primaryDark.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: _groupCoverWidget(group, fontSize: 28)),
                  if (group.isVerified)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.verified_rounded, size: 12, color: AppColors.primary),
                      ),
                    ),
                  if (group.isNew)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(5)),
                        child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(group.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[500], height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text('${group.members}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Uint8List? _dataUriToBytes(String value) {
    if (!value.startsWith('data:image')) return null;
    final parts = value.split(',');
    if (parts.length < 2) return null;
    try {
      return base64Decode(parts.last);
    } catch (_) {
      return null;
    }
  }

  Widget _groupCoverWidget(GroupModel group, {double fontSize = 28}) {
    final apiGroup = _groups.where((g) => g.id.toString() == group.id).cast<_Group?>().firstWhere((e) => e != null, orElse: () => null);
    final avatar = apiGroup?.avatarUrl ?? '';
    final dataBytes = _dataUriToBytes(avatar);
    if (dataBytes != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.memory(dataBytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    }
    if (avatar.startsWith('http')) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.network(
          avatar,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Center(
            child: Text(group.name[0], style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
      );
    }
    return Center(
      child: Text(group.name[0], style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }

  void _showGroupDetail(BuildContext context, GroupModel group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary.withOpacity(0.88), AppColors.primaryDark.withOpacity(0.82)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Builder(
                              builder: (_) {
                                final apiGroup = _groups.where((g) => g.id.toString() == group.id).cast<_Group?>().firstWhere((e) => e != null, orElse: () => null);
                                final avatar = apiGroup?.avatarUrl ?? '';
                                final dataBytes = _dataUriToBytes(avatar);
                                if (dataBytes != null) {
                                  return Image.memory(dataBytes, fit: BoxFit.cover);
                                }
                                if (avatar.startsWith('http')) {
                                  return Image.network(avatar, fit: BoxFit.cover);
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(group.name[0], style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white)),
                                Text(group.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _groupStat('${group.members}', 'Thành viên', Icons.people_rounded),
                          Container(width: 1, height: 32, color: Colors.grey[200]),
                          _groupStat('48', 'Bài đăng', Icons.article_outlined),
                          Container(width: 1, height: 32, color: Colors.grey[200]),
                          _groupStat('12', 'Sự kiện', Icons.event_rounded),
                          Container(width: 1, height: 32, color: Colors.grey[200]),
                          _groupStat('99+', 'Hoạt động', Icons.trending_up_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Giới thiệu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 8),
                          Text(group.description, style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6)),
                          const SizedBox(height: 12),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFFE8294E)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nổi bật', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _featuredCard('Buổi học', Icons.school_rounded, AppColors.primary),
                              const SizedBox(width: 12),
                              _featuredCard('Workshop', Icons.workspace_premium_rounded, AppColors.primaryDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Thành viên', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _memberCard('Arvind Mishra', 'He/His · 500+ Connections\nSoftware Engineer | AI', AppColors.primary),
                              const SizedBox(width: 10),
                              _memberCard('Angela Joshi', 'She/Her · 500+ Connections\nStrategic Marketing Professional', AppColors.primaryDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: group.isOwner
                          ? Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showInviteMemberDialog(group),
                                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                    label: const Text('Mời thành viên'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.outline),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Bạn là chủ nhóm',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : group.isPending
                              ? _pendingButton()
                              : _joinButton(group),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE8294E)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1A2E))),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _featuredCard(String title, IconData icon, Color color) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(String name, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Text(name[0], style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF1A1A2E))),
                  Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[500], height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _joinButton(GroupModel group) {
    return GestureDetector(
      onTap: () => _joinGroup(group),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE8294E), Color(0xFFFF6B6B)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFE8294E).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Tham gia nhóm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8294E).withOpacity(0.3)),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty_rounded, color: Color(0xFFE8294E), size: 18),
            SizedBox(width: 8),
            Text('Chờ xét duyệt', style: TextStyle(color: Color(0xFFE8294E), fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupModal(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int selectedPrivacy = 0;
    bool isNameFilled = false;
    Uint8List? avatarBytes;
    String? avatarDataUri;
    final selectedInviteUsers = <String>{};

    final privacyOptions = [
      {'label': 'Công khai', 'icon': Icons.public_rounded, 'color': 0xFFE91E63},
      {'label': 'Riêng tư', 'icon': Icons.lock_outline_rounded, 'color': 0xFFC2185B},
      {'label': 'Bí mật', 'icon': Icons.visibility_off_rounded, 'color': 0xFFAD1457},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tạo nhóm mới', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 45,
                      maxWidth: 1280,
                      maxHeight: 720,
                    );
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    if (bytes.length > 900 * 1024) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ảnh nhóm quá lớn, vui lòng chọn ảnh nhẹ hơn'),
                        ),
                      );
                      return;
                    }
                    final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
                    setModalState(() {
                      avatarBytes = bytes;
                      avatarDataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';
                    });
                  },
                  child: Container(
                    height: 96,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: avatarBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                              SizedBox(height: 4),
                              Text('Tải ảnh nhóm', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(avatarBytes!, fit: BoxFit.cover, width: double.infinity, height: 96),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _createField('Tên nhóm', nameController, onChanged: (v) => setModalState(() => isNameFilled = v.isNotEmpty)),
                const SizedBox(height: 12),
                _createField('Mô tả', descController, maxLines: 4, hint: 'Điền mô tả...'),
                const SizedBox(height: 12),
                Text('Mời bạn bè', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickFriendsForInvite(
                      initialSelection: selectedInviteUsers,
                    );
                    setModalState(() {
                      selectedInviteUsers
                        ..clear()
                        ..addAll(picked);
                    });
                  },
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: Text(
                    selectedInviteUsers.isEmpty
                        ? 'Chọn từ danh sách bạn bè'
                        : 'Đã chọn ${selectedInviteUsers.length} bạn',
                  ),
                ),
                if (selectedInviteUsers.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedInviteUsers
                        .map(
                          (u) => Chip(
                            label: Text(u),
                            onDeleted: () => setModalState(() {
                              selectedInviteUsers.remove(u);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Trạng thái', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Row(
                  children: privacyOptions.asMap().entries.map((e) {
                    final isSelected = selectedPrivacy == e.key;
                    final color = Color(e.value['color'] as int);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedPrivacy = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withOpacity(0.12) : const Color(0xFFF7F8FC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Icon(e.value['icon'] as IconData, size: 18, color: isSelected ? color : Colors.grey[400]),
                              const SizedBox(height: 3),
                              Text(
                                e.value['label'] as String,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? color : Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    selectedPrivacy == 0 ? 'Ai cũng có thể tham gia nhóm.' : selectedPrivacy == 1 ? 'Chỉ thành viên được mời.' : 'Nhóm ẩn, chỉ thành viên mới thấy.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(child: Text('Hủy', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: isNameFilled
                            ? () async {
                                final res = await http.post(
                                  Uri.parse('${AppApi.groups}/'),
                                  headers: AppSession.authHeaders(
                                    extra: const {'Content-Type': 'application/json'},
                                  ),
                                  body: jsonEncode({
                                    'title': nameController.text.trim(),
                                    'subject': 'General',
                                    'category': 'community',
                                    'description': descController.text.trim(),
                                    if (avatarDataUri != null &&
                                        avatarDataUri!.length < 160000)
                                      'avatar_url': avatarDataUri,
                                  }),
                                );
                                if (!mounted) return;
                                if (res.statusCode == 201) {
                                  final created = jsonDecode(res.body) as Map<String, dynamic>;
                                  final groupId = (created['id'] as num?)?.toInt();
                                  final inviteUsers = selectedInviteUsers;
                                  if (groupId != null && inviteUsers.isNotEmpty) {
                                    for (final username in inviteUsers) {
                                      await http.post(
                                        Uri.parse('${AppApi.groups}/$groupId/invite/'),
                                        headers: AppSession.authHeaders(extra: const {'Content-Type': 'application/json'}),
                                        body: jsonEncode({'target_username': username}),
                                      );
                                    }
                                  }
                                  Navigator.pop(ctx);
                                  _load();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo nhóm thành công')));
                                } else {
                                  String message = 'Không thể tạo nhóm';
                                  try {
                                    final body = jsonDecode(res.body) as Map<String, dynamic>;
                                    final detail = (body['detail'] ?? '').toString();
                                    if (detail.isNotEmpty) message = detail;
                                  } catch (_) {}
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: isNameFilled ? const LinearGradient(colors: [Color(0xFFE8294E), Color(0xFFFF6B6B)]) : null,
                            color: isNameFilled ? null : Colors.grey[200],
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isNameFilled
                                ? [BoxShadow(color: const Color(0xFFE8294E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Tạo nhóm',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isNameFilled ? Colors.white : Colors.grey[400]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _createField(String label, TextEditingController ctrl, {int maxLines = 1, String? hint, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              hintText: hint ?? 'Nhập $label',
              hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

}
