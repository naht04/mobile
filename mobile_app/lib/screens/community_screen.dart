import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/core/avatar_utils.dart';
import 'package:mobile_app/screens/create_post_screen.dart';
import 'package:mobile_app/screens/document_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.initialPostId});

  final int? initialPostId;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _loading = true;
  String? _errorMessage;
  final String _apiBase = AppApi.community;
  final _searchController = TextEditingController();
  String _selectedTopic = 'all';
  List<_Post> _posts = [];
  bool _openedInitialPost = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts({String query = ''}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final uri = Uri.parse('$_apiBase/posts/').replace(
        queryParameters: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'username': AppSession.username,
        },
      );
      final res = await http.get(uri, headers: AppSession.authHeaders());
      if (res.statusCode != 200) throw Exception('status ${res.statusCode}');

      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _Post.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _posts = list;
        _loading = false;
      });

      final initialId = widget.initialPostId;
      if (!_openedInitialPost && initialId != null) {
        final match = _posts.where((p) => p.id == initialId).cast<_Post?>().firstWhere(
              (p) => p != null,
              orElse: () => null,
            );
        if (match != null && mounted) {
          _openedInitialPost = true;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _PostDetailScreen(
                post: match,
                username: AppSession.username,
                apiBase: _apiBase,
              ),
            ),
          );
          if (mounted) {
            _loadPosts();
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
        _posts = [];
      });
    }
  }

  // ── Mở CreatePostScreen dưới dạng bottom sheet ──
  Future<void> _openCreatePost() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CreatePostScreen(
        onPostCreated: (newPostJson) {
          setState(() {
            _posts.insert(0, _Post.fromJson(newPostJson));
          });
        },
      ),
    ),
  );
}

  Future<void> _toggleLike(_Post post) async {
    final res = await http.post(
      Uri.parse('$_apiBase/posts/${post.id}/react/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'username': AppSession.username}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        post.isLiked = body['liked'] == true;
        post.likes = (body['like_count'] ?? post.likes) as int;
      });
    }
  }

  Future<void> _toggleSave(_Post post) async {
    final res = await http.post(
      Uri.parse('$_apiBase/posts/${post.id}/save/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'username': AppSession.username}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        post.isSaved = body['saved'] == true;
      });
    }
  }

  Widget _buildPostMedia(_Post post) {
    final hasImage = post.image != null && post.image!.isNotEmpty;
    final hasFile = post.file != null && post.file!.isNotEmpty;
    if (!hasImage && !hasFile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.network(
                    post.image!,
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Ảnh đính kèm',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hasFile)
            Padding(
              padding: EdgeInsets.only(top: hasImage ? 10 : 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openFileUrl(post.file!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF6C7D9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        color: Color(0xFFF33B6D),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.fileName ?? 'Tệp đính kèm',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: Color(0xFFF33B6D),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFileUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở tệp đính kèm.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cộng đồng')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePost,
        backgroundColor: const Color(0xFFF33B6D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Không tải được dữ liệu cộng đồng',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadPosts, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _filteredPosts.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildFilters();
                      final post = _filteredPosts[index - 1];

                      return Card(
                        elevation: 0,
                        color: const Color(0xFFFFFBFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFF5D7E3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _PostDetailScreen(
                                  post: post,
                                  username: AppSession.username,
                                  apiBase: _apiBase,
                                ),
                              ),
                            );
                            _loadPosts();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    initialsAvatar(post.author, radius: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.author,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          if (post.topic.isNotEmpty)
                                            Text(
                                              '#${post.topic}',
                                              style: const TextStyle(
                                                color: Color(0xFFF33B6D),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (post.createdAt != null && post.createdAt!.isNotEmpty)
                                      Text(
                                        _formatRelativeTime(post.createdAt!),
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  post.content,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(height: 1.35),
                                ),
                                _buildPostMedia(post),

                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _toggleLike(post),
                                      icon: Icon(
                                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: post.isLiked ? Colors.red : null,
                                      ),
                                    ),
                                    Text('${post.likes}'),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.mode_comment_outlined, size: 20),
                                    const SizedBox(width: 6),
                                    Text('${_countAllComments(post.comments)} bình luận'),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () => _toggleSave(post),
                                      icon: Icon(
                                        post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  List<_Post> get _filteredPosts {
    final q = _searchController.text.trim().toLowerCase();
    return _posts.where((p) {
      final topicOk = _selectedTopic == 'all' || p.topic.toLowerCase() == _selectedTopic.toLowerCase();
      final queryOk = q.isEmpty ||
          p.content.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.topic.toLowerCase().contains(q);
      return topicOk && queryOk;
    }).toList();
  }

  String _formatRelativeTime(String createdAt) {
    final created = DateTime.tryParse(createdAt);
    if (created == null) return '';
    final diff = DateTime.now().difference(created.toLocal());
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} tiếng trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}';
  }

  int _countAllComments(List<_Comment> comments) {
    int total = comments.length;
    for (final comment in comments) {
      total += _countAllComments(comment.replies);
    }
    return total;
  }

  Widget _buildFilters() {
    final topics = <String>{'all', ..._posts.map((e) => e.topic).where((e) => e.isNotEmpty)};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm bài viết, tác giả, category...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...topics.map((topic) {
                final selected = topic == _selectedTopic;
                final label = topic == 'all' ? '#Tất_cả' : '#$topic';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedTopic = topic),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('#Tài liệu'),
                  selected: false,
                  onSelected: (_) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DocumentScreen(initialTab: 0),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('#Nhóm'),
                  selected: false,
                  onSelected: (_) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DocumentScreen(initialTab: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Các class hỗ trợ (giữ nguyên + bổ sung file)
// ─────────────────────────────────────────────────────────────
class _Post {
  _Post({
    required this.id,
    required this.author,
    required this.content,
    required this.likes,
    required this.topic,
    required this.comments,
    this.image,
    this.file,
    this.fileName,
    this.createdAt,
  });

  final int id;
  final String author;
  String content;
  String topic;
  int likes;
  bool isLiked = false;
  bool isSaved = false;
  final List<_Comment> comments;

  String? image;
  String? file;
  String? fileName;
  final String? createdAt;

  factory _Post.fromJson(Map<String, dynamic> json) {
    final likeCount = (json['like_count'] as num?)?.toInt() ?? 0;
    final postId = (json['id'] as num?)?.toInt() ?? 0;

    // Xử lý link media (ảnh + file)
    String? imageUrl = json['image'];
    if (imageUrl != null && imageUrl.startsWith('/')) {
      imageUrl = '${AppApi.host}$imageUrl';
    }

    String? fileUrl = json['file'];
    if (fileUrl != null && fileUrl.startsWith('/')) {
      fileUrl = '${AppApi.host}$fileUrl';
    }

    final post = _Post(
      id: postId,
      author: (json['author_name'] ?? json['username'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      likes: likeCount,
      topic: (json['topic'] ?? '').toString(),
      image: imageUrl,
      file: fileUrl,
      fileName: (json['file_name'] ?? _guessFileName(fileUrl))?.toString(),
      createdAt: json['created_at'],
      comments: (json['comments'] as List<dynamic>? ?? [])
          .map((e) => _Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    
    // Set like/save state from backend
    post.isLiked = json['is_liked'] == true;
    post.isSaved = json['is_saved'] == true;
    
    return post;
  }
}

String? _guessFileName(String? fileUrl) {
  if (fileUrl == null || fileUrl.isEmpty) return null;
  final uri = Uri.tryParse(fileUrl);
  if (uri == null || uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.last;
}

class _Comment {
  _Comment({
    required this.id,
    required this.author,
    required this.content,
    this.createdAt,
    List<_Comment>? replies,
  }) : replies = replies ?? [];
  final int id;
  final String author;
  final String content;
  final String? createdAt;
  final List<_Comment> replies;

  factory _Comment.fromJson(Map<String, dynamic> json) {
    return _Comment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      author: (json['author_name'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      replies: (json['replies'] as List<dynamic>? ?? [])
          .map((e) => _Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class _PostDetailScreen extends StatefulWidget {
  const _PostDetailScreen({
    required this.post,
    required this.apiBase,
    required this.username,
  });

  final _Post post;
  final String apiBase;
  final String username;

  @override
  State<_PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<_PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(String createdAt) {
    final created = DateTime.tryParse(createdAt);
    if (created == null) return '';
    final diff = DateTime.now().difference(created.toLocal());
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} tiếng trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bài viết'),
        actions: [
          if (widget.post.author.toLowerCase() == widget.username.toLowerCase())
            IconButton(onPressed: _editPost, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    initialsAvatar(widget.post.author, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.post.author,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.post.topic.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8F1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#${widget.post.topic}',
                          style: const TextStyle(
                            color: Color(0xFFF33B6D),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.post.content),

                // ── HIỂN THỊ ẢNH TRONG DETAIL ──
                if (widget.post.image != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: () => _showImageDialog(widget.post.image!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Image.network(
                              widget.post.image!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Xem ảnh',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── HIỂN THỊ FILE TRONG DETAIL ──
                if (widget.post.file != null && widget.post.fileName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: InkWell(
                      onTap: () => _openUrl(widget.post.file!),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.post.fileName!,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 18, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.post.comments.length,
              itemBuilder: (_, index) => _buildCommentThread(
                widget.post.comments[index],
                level: 0,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập bình luận...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      final text = _commentController.text.trim();
                      if (text.isEmpty) return;
                      final res = await http.post(
                        Uri.parse('${widget.apiBase}/posts/${widget.post.id}/comments/'),
                        headers: AppSession.authHeaders(
                          extra: const {'Content-Type': 'application/json'},
                        ),
                        body: jsonEncode({
                          'username': widget.username,
                          'content': text,
                        }),
                      );
                      if (res.statusCode == 201) {
                        final body = jsonDecode(res.body) as Map<String, dynamic>;
                        setState(() {
                          widget.post.comments.add(
                            _Comment.fromJson(body),
                          );
                          _commentController.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImageDialog(String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: double.infinity,
                  height: 240,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Không thể tải ảnh.', textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở file.')),
      );
    }
  }

  Widget _buildCommentThread(_Comment comment, {int level = 0}) {
    final indent = 16.0 * level;
    final timeStr = comment.createdAt != null && comment.createdAt!.isNotEmpty
        ? _formatRelativeTime(comment.createdAt!)
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: initialsAvatar(comment.author, radius: 16),
          title: Row(
            children: [
              Expanded(
                child: Text(comment.author),
              ),
              if (timeStr.isNotEmpty)
                Text(
                  ' | $timeStr',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(comment.content),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _showReplyDialog(comment),
                child: const Text(
                  'Trả lời',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          contentPadding: EdgeInsets.fromLTRB(indent + 12, 0, 12, 0),
          minLeadingWidth: 32,
          horizontalTitleGap: 8,
          dense: true,
        ),
        // Replies
        ...comment.replies.map((reply) => _buildCommentThread(reply, level: level + 1)),
      ],
    );
  }

  Future<void> _showReplyDialog(_Comment parentComment) async {
    final replyCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Trả lời bình luận'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Trả lời ${parentComment.author}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
            TextField(
              controller: replyCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Nhập trả lời...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final text = replyCtl.text.trim();
    if (text.isEmpty) return;
    final res = await http.post(
      Uri.parse('${widget.apiBase}/posts/${widget.post.id}/comments/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'username': widget.username,
        'content': text,
        'parent_id': parentComment.id,
      }),
    );
    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        parentComment.replies.add(
          _Comment.fromJson(body),
        );
      });
    }
  }

  // ... (phần _editPost giữ nguyên như cũ)
  Future<void> _editPost() async {
    final ctl = TextEditingController(text: widget.post.content);
    final topicCtl = TextEditingController(text: widget.post.topic);
    XFile? selectedImage;
    bool removeImage = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Chỉnh sửa bài viết'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Nội dung'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: topicCtl,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                if (selectedImage != null || (widget.post.image != null && !removeImage)) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: selectedImage != null
                          ? (kIsWeb
                              ? Image.network(selectedImage!.path, fit: BoxFit.cover)
                              : Image.file(File(selectedImage!.path), fit: BoxFit.cover))
                          : Image.network(widget.post.image!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (removeImage && selectedImage == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Ảnh hiện tại sẽ bị xóa.', style: TextStyle(color: Colors.redAccent)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setStateDialog(() {
                              selectedImage = image;
                              removeImage = false;
                            });
                          }
                        },
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Chọn ảnh'),
                      ),
                    ),
                    if ((widget.post.image != null && !removeImage) || selectedImage != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          setStateDialog(() {
                            selectedImage = null;
                            removeImage = true;
                          });
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Xóa ảnh'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final content = ctl.text.trim();
    final topic = topicCtl.text.trim();
    final title = content.length > 60 ? '${content.substring(0, 60)}...' : content;

    if (selectedImage != null || removeImage) {
      final request = http.MultipartRequest('PATCH', Uri.parse('${widget.apiBase}/posts/${widget.post.id}/'))
        ..fields['username'] = widget.username
        ..fields['title'] = title
        ..fields['content'] = content
        ..fields['topic'] = topic;
      request.headers.addAll(AppSession.authHeaders());

      if (selectedImage != null) {
        final bytes = await selectedImage!.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: selectedImage!.name,
        ));
      }
      if (removeImage && selectedImage == null) {
        request.fields['remove_image'] = '1';
      }

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        String? imageUrl = body['image'] as String?;
        if (imageUrl != null && imageUrl.startsWith('/')) {
          imageUrl = 'http://127.0.0.1:8000$imageUrl';
        }
        setState(() {
          widget.post.content = content;
          widget.post.topic = topic;
          widget.post.image = imageUrl;
        });
      }
    } else {
      final res = await http.patch(
        Uri.parse('${widget.apiBase}/posts/${widget.post.id}/'),
        headers: AppSession.authHeaders(
          extra: const {'Content-Type': 'application/json'},
        ),
        body: jsonEncode({
          'username': widget.username,
          'title': title,
          'content': content,
          'topic': topic,
        }),
      );
      if (res.statusCode == 200) {
        setState(() {
          widget.post.content = content;
          widget.post.topic = topic;
        });
      }
    }
  }
}
