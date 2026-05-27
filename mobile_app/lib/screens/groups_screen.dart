import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  List<_Group> _groups = [];
  String _query = '';

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
    final params = <String, String>{if (_query.trim().isNotEmpty) 'q': _query.trim()};
    final uri = Uri.parse('${AppApi.groups}/').replace(queryParameters: params);
    try {
      final res = await http.get(uri, headers: AppSession.authHeaders());
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _Group.fromJson(e as Map<String, dynamic>))
            .toList();
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

  Future<void> _createGroup() async {
    final titleCtl = TextEditingController();
    final subjectCtl = TextEditingController();
    final categoryCtl = TextEditingController();
    final avatarCtl = TextEditingController();
    final descCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Tạo nhóm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Tên nhóm')),
              const SizedBox(height: 8),
              TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'Môn học')),
              const SizedBox(height: 8),
              TextField(controller: categoryCtl, decoration: const InputDecoration(labelText: 'Danh mục nhóm')),
              const SizedBox(height: 8),
              TextField(
                controller: descCtl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: avatarCtl,
                      decoration: const InputDecoration(labelText: 'Ảnh bìa URL (tùy chọn)'),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Upload ảnh',
                    icon: const Icon(Icons.upload_file),
                    onPressed: () async {
                      final url = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Nhập URL ảnh bìa'),
                          content: TextField(
                            autofocus: true,
                            decoration: const InputDecoration(hintText: 'https://...'),
                            controller: TextEditingController(text: avatarCtl.text),
                            onChanged: (value) {},
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, avatarCtl.text.trim());
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      if (url != null && url.isNotEmpty) {
                        avatarCtl.text = url;
                        setStateDialog(() {});
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Xóa ảnh',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      avatarCtl.clear();
                      setStateDialog(() {});
                    },
                  ),
                ],
              ),
              if (avatarCtl.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        avatarCtl.text,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final res = await http.post(
      Uri.parse('${AppApi.groups}/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'title': titleCtl.text.trim(),
        'subject': subjectCtl.text.trim(),
        'category': categoryCtl.text.trim(),
        'avatar_url': avatarCtl.text.trim(),
        'description': descCtl.text.trim(),
      }),
    );
    if (res.statusCode == 201) _load();
  }

  Future<void> _joinGroup(_Group g) async {
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${g.id}/join/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode(const {}),
    );
    if (!mounted) return;
    if (res.statusCode == 201 || res.statusCode == 200) {
      _setGroupJoined(g.id, incrementCount: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu tham gia nhóm')),
      );
      _load();
      return;
    }

    try {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic> && data['detail'] == 'already member') {
        _setGroupJoined(g.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn đã tham gia nhóm')));
        return;
      }
    } catch (_) {
      // ignore JSON parse errors
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể tham gia nhóm')));
  }

  void _setGroupJoined(int groupId, {bool incrementCount = false}) {
    if (!mounted) return;
    setState(() {
      _groups = _groups.map((group) {
        if (group.id != groupId) return group;
        return _Group(
          id: group.id,
          title: group.title,
          subject: group.subject,
          maxMembers: group.maxMembers,
          memberCount: incrementCount ? group.memberCount + 1 : group.memberCount,
          ownerName: group.ownerName,
          description: group.description,
          category: group.category,
          avatarUrl: group.avatarUrl,
          joined: true,
          joinStatus: incrementCount ? 'pending' : group.joinStatus,
          isOwner: group.isOwner,
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('#Nhóm học tập'),
        actions: [IconButton(onPressed: _createGroup, icon: const Icon(Icons.group_add_outlined))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _query = v;
                  _load();
                });
              },
              decoration: const InputDecoration(
                hintText: 'Tìm nhóm theo tên hoặc mô tả...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _groups.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final g = _groups[i];
                      return InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _GroupDetailScreen(groupId: g.id),
                            ),
                          );
                          if (mounted) _load();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (g.avatarUrl.isNotEmpty)
                              SizedBox(
                                height: 160,
                                width: double.infinity,
                                child: Image.network(
                                  g.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 160,
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.image, color: Colors.grey, size: 48),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    g.description.isEmpty ? 'Không có mô tả' : g.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${g.memberCount} thành viên',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (g.isOwner)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Chủ nhóm',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else if (g.joinStatus == 'member')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Đã tham gia',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else if (g.joinStatus == 'pending')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Chờ xét duyệt',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: () => _joinGroup(g),
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text('Tham gia'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${g.subject} • ${g.category.isEmpty ? "Khác" : g.category}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ));
                    },
                  ),
          ),
        ],
      ),
    );
  }

}

class _Group {
  _Group({
    required this.id,
    required this.title,
    required this.subject,
    required this.maxMembers,
    required this.memberCount,
    required this.ownerName,
    required this.description,
    required this.category,
    required this.avatarUrl,
    required this.joined,
    required this.joinStatus,
    required this.isOwner,
  });

  final int id;
  final String title;
  final String subject;
  final int maxMembers;
  final int memberCount;
  final String ownerName;
  final String description;
  final String category;
  final String avatarUrl;
  final bool joined;
  final String joinStatus;
  final bool isOwner;

  factory _Group.fromJson(Map<String, dynamic> json) {
    return _Group(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      ownerName: (json['owner_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      joined: (json['joined'] as bool?) ?? false,
      joinStatus: (json['join_status'] ?? 'none').toString(),
      isOwner: (json['is_owner'] as bool?) ?? false,
    );
  }
}

class _GroupDetailScreen extends StatefulWidget {
  const _GroupDetailScreen({required this.groupId});

  final int groupId;

  @override
  State<_GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<_GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _Group? _group;
  List<_GroupMember> _members = [];
  List<_GroupPost> _posts = [];
  List<_JoinRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detailRes = await http.get(
        Uri.parse('${AppApi.groups}/${widget.groupId}/'),
        headers: AppSession.authHeaders(),
      );
      if (detailRes.statusCode == 200) {
        _group = _Group.fromJson(jsonDecode(detailRes.body) as Map<String, dynamic>);
      }

      final membersRes = await http.get(
        Uri.parse('${AppApi.groups}/${widget.groupId}/members/'),
        headers: AppSession.authHeaders(),
      );
      if (membersRes.statusCode == 200) {
        final body = jsonDecode(membersRes.body) as Map<String, dynamic>;
        _members = (body['results'] as List<dynamic>? ?? [])
            .map((e) => _GroupMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final postsRes = await http.get(
        Uri.parse('${AppApi.groups}/${widget.groupId}/posts/'),
        headers: AppSession.authHeaders(),
      );
      if (postsRes.statusCode == 200) {
        _posts = (jsonDecode(postsRes.body) as List<dynamic>)
            .map((e) => _GroupPost.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (_group?.isOwner == true) {
        final reqRes = await http.get(
          Uri.parse('${AppApi.groups}/${widget.groupId}/join-requests/'),
          headers: AppSession.authHeaders(),
        );
        if (reqRes.statusCode == 200) {
          _requests = (jsonDecode(reqRes.body) as List<dynamic>)
              .map((e) => _JoinRequest.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _join() async {
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${widget.groupId}/join/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode(const {}),
    );
    if (!mounted) return;
    if (res.statusCode == 201 || res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu tham gia nhóm')),
      );
      _load();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể tham gia nhóm')),
    );
  }

  Future<void> _decideRequest(_JoinRequest request, String action) async {
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${widget.groupId}/join-requests/${request.id}/decide/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'action': action}),
    );
    if (res.statusCode == 200 && mounted) _load();
  }

  Future<void> _inviteUser() async {
    final queryCtl = TextEditingController();
    List<String> usernames = [];
    Future<void> search(String q) async {
      final res = await http.get(
        Uri.parse('${AppApi.users}/search/').replace(
          queryParameters: {if (q.trim().isNotEmpty) 'q': q.trim()},
        ),
        headers: AppSession.authHeaders(),
      );
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      usernames = (body['results'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['username'].toString())
          .toList();
    }

    await search('');
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mời người vào nhóm'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: queryCtl,
                  decoration: const InputDecoration(hintText: 'Tìm username'),
                  onChanged: (value) async {
                    await search(value);
                    if (context.mounted) setDialogState(() {});
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    itemCount: usernames.length,
                    itemBuilder: (_, i) {
                      final u = usernames[i];
                      return ListTile(
                        title: Text(u),
                        onTap: () => Navigator.pop(context, u),
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
    if (picked == null || picked.isEmpty) return;
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${widget.groupId}/invite/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'target_username': picked}),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.statusCode == 201
              ? 'Đã mời $picked vào nhóm'
              : 'Không thể mời thành viên',
        ),
      ),
    );
    if (res.statusCode == 201) _load();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(
        title: Text(g?.title ?? 'Chi tiết nhóm'),
        actions: [
          if (g?.isOwner == true)
            IconButton(
              onPressed: _inviteUser,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Mời người',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bài viết'),
            Tab(text: 'Thành viên'),
            Tab(text: 'Yêu cầu'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? const Center(child: Text('Không tải được nhóm'))
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (g.avatarUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                g.avatarUrl,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 140,
                                  color: Colors.grey.shade200,
                                  child: const Center(child: Icon(Icons.image_not_supported)),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            g.description,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _infoChip('${g.memberCount} thành viên'),
                              const SizedBox(width: 8),
                              _infoChip('${g.subject} • ${g.category.isEmpty ? "Khác" : g.category}'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (!g.isOwner && g.joinStatus == 'none')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _join,
                                child: const Text('Tham gia nhóm'),
                              ),
                            )
                          else if (g.joinStatus == 'pending')
                            const Text(
                              'Bạn đang ở trạng thái chờ xét duyệt',
                              style: TextStyle(color: Colors.orange),
                            )
                          else if (g.joinStatus == 'member' || g.isOwner)
                            const Text(
                              'Bạn đã tham gia nhóm',
                              style: TextStyle(color: Colors.green),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _posts.isEmpty
                              ? const Center(child: Text('Chưa có bài viết theo nhóm này'))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _posts.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final p = _posts[i];
                                    return ListTile(
                                      tileColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      title: Text(
                                        p.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        p.content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  },
                                ),
                          _members.isEmpty
                              ? const Center(child: Text('Chưa có thành viên'))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _members.length,
                                  itemBuilder: (_, i) {
                                    final m = _members[i];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        child: Text(m.username.substring(0, 1).toUpperCase()),
                                      ),
                                      title: Text(m.username),
                                      trailing: m.isOwner
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.pink.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text('Chủ nhóm'),
                                            )
                                          : null,
                                    );
                                  },
                                ),
                          g.isOwner
                              ? (_requests.isEmpty
                                  ? const Center(child: Text('Không có yêu cầu chờ duyệt'))
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: _requests.length,
                                      itemBuilder: (_, i) {
                                        final r = _requests[i];
                                        return ListTile(
                                          title: Text(r.username),
                                          subtitle: const Text('Yêu cầu tham gia nhóm'),
                                          trailing: Wrap(
                                            spacing: 8,
                                            children: [
                                              OutlinedButton(
                                                onPressed: () => _decideRequest(r, 'reject'),
                                                child: const Text('Từ chối'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => _decideRequest(r, 'approve'),
                                                child: const Text('Duyệt'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ))
                              : const Center(child: Text('Chỉ chủ nhóm mới quản lý yêu cầu')),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _GroupMember {
  _GroupMember({required this.username, required this.isOwner});
  final String username;
  final bool isOwner;

  factory _GroupMember.fromJson(Map<String, dynamic> json) => _GroupMember(
        username: (json['username'] ?? '').toString(),
        isOwner: (json['is_owner'] as bool?) ?? false,
      );
}

class _GroupPost {
  _GroupPost({required this.title, required this.content});
  final String title;
  final String content;

  factory _GroupPost.fromJson(Map<String, dynamic> json) => _GroupPost(
        title: (json['title'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
      );
}

class _JoinRequest {
  _JoinRequest({required this.id, required this.username});
  final int id;
  final String username;

  factory _JoinRequest.fromJson(Map<String, dynamic> json) => _JoinRequest(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: (json['user_name'] ?? '').toString(),
      );
}

