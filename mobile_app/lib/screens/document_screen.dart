import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/screens/group_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentModel {
  final String id;
  final String title;
  final String subject;
  final String author;
  final String fileType;
  final int likes;
  final int views;
  final String coverColor;
  final String year;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.subject,
    required this.author,
    required this.fileType,
    required this.likes,
    required this.views,
    required this.coverColor,
    required this.year,
  });
}

class _DocumentItem {
  _DocumentItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.category,
    required this.documentType,
    required this.description,
    required this.uploaderName,
    required this.downloadCount,
    this.fileUrl,
  });

  final int id;
  final String title;
  final String subject;
  final String category;
  final String documentType;
  final String description;
  final String uploaderName;
  final int downloadCount;
  final String? fileUrl;

  factory _DocumentItem.fromJson(Map<String, dynamic> json) {
    return _DocumentItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      documentType: (json['document_type'] ?? 'other').toString(),
      description: (json['description'] ?? '').toString(),
      uploaderName: (json['uploader_name'] ?? '').toString(),
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      fileUrl: json['file_url']?.toString(),
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

final List<DocumentModel> sampleDocs = [
  DocumentModel(id: '1', title: 'Giáo trình môn Phát triển ứng dụng cho thiết bị di động', subject: 'Mobile', author: 'Nguyen Van A', fileType: 'PDF', likes: 5, views: 20, coverColor: '#E91E63', year: '2019'),
  DocumentModel(id: '2', title: 'Lập trình C++ nâng cao – Cấu trúc dữ liệu & Giải thuật', subject: 'C++', author: 'Tran Thi B', fileType: 'PDF', likes: 12, views: 45, coverColor: '#C2185B', year: '2020'),
  DocumentModel(id: '3', title: 'Python cho khoa học dữ liệu và trí tuệ nhân tạo', subject: 'Python', author: 'Le Van C', fileType: 'PDF', likes: 28, views: 102, coverColor: '#FF4F87', year: '2021'),
  DocumentModel(id: '4', title: 'Tài chính doanh nghiệp – Phân tích và ra quyết định', subject: 'Tài chính', author: 'Pham Thi D', fileType: 'PDF', likes: 7, views: 33, coverColor: '#D81B60', year: '2022'),
  DocumentModel(id: '5', title: 'Vật lý 1 – Cơ học, Nhiệt học, và Điện từ học', subject: 'Vật lý', author: 'Hoang Van E', fileType: 'PDF', likes: 15, views: 67, coverColor: '#EC407A', year: '2020'),
  DocumentModel(id: '6', title: 'Kiến trúc phần mềm – Design Patterns & SOLID', subject: 'Kỹ thuật', author: 'Do Thi F', fileType: 'PDF', likes: 22, views: 88, coverColor: '#AD1457', year: '2023'),
];

final List<Map<String, dynamic>> categories = [
  {'label': 'Tất cả', 'icon': Icons.grid_view_rounded, 'color': 0xFFE8294E},
  {'label': 'Tin học', 'icon': Icons.computer_rounded, 'color': 0xFFE91E63},
  {'label': 'C++', 'icon': Icons.code_rounded, 'color': 0xFFD81B60},
  {'label': 'Vật lý', 'icon': Icons.science_rounded, 'color': 0xFFEC407A},
  {'label': 'Tài chính', 'icon': Icons.attach_money_rounded, 'color': 0xFFAD1457},
  {'label': 'Python', 'icon': Icons.terminal_rounded, 'color': 0xFFC2185B},
  {'label': 'Mobile', 'icon': Icons.phone_android_rounded, 'color': 0xFFFF4F87},
  {'label': 'Lịch sử', 'icon': Icons.history_edu_rounded, 'color': 0xFFE91E63},
];

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showSuggestions = false;
  String _searchQuery = '';
  int _selectedCategory = 0;
  bool _loading = true;
  String? _errorMessage;
  List<_DocumentItem> _docs = [];
  List<String> _subjects = ['All'];
  List<String> _categories = ['All'];
  String _selectedSubject = 'All';
  final Map<int, Uint8List?> _pdfPreviewCache = {};
  final Map<int, Future<Uint8List?>> _pdfPreviewTasks = {};

  final List<String> _topSearches = ['Mobie', 'C++', 'python', 'Finance'];
  static const Color _cardBg = Color(0xFFFFFBFD);
  static const Color _cardBorder = Color(0xFFF5D7E3);
  String get _searchHint => _tabController.index == 1
      ? 'Tìm kiếm nhóm...'
      : 'Tìm kiếm tài liệu...';

  @override
  void initState() {
    super.initState();
    final initialIndex = (widget.initialTab >= 0 && widget.initialTab <= 1)
        ? widget.initialTab
        : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentModel> get _filteredDocs {
    return _docs
        .where((d) => d.title.toLowerCase().contains(_searchQuery.toLowerCase()) || d.subject.toLowerCase().contains(_searchQuery.toLowerCase()))
        .map(
          (d) => DocumentModel(
            id: d.id.toString(),
            title: d.title,
            subject: d.subject,
            author: d.uploaderName,
            fileType: d.documentType.toUpperCase(),
            likes: 0,
            views: d.downloadCount,
            coverColor: '#E91E63',
            year: '',
          ),
        )
        .toList();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    await Future.wait([_loadSubjects(), _loadDocs()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSubjects() async {
    final res = await http.get(
      Uri.parse('${AppApi.host}/api/documents/subjects/'),
      headers: AppSession.authHeaders(),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final values = (body['subjects'] as List<dynamic>? ?? body['results'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      final categoryValues = (body['categories'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      if (!mounted) return;
      setState(() {
        _subjects = ['All', ...values];
        _categories = ['All', ...categoryValues];
      });
    }
  }

  Future<void> _loadDocs() async {
    final params = <String, String>{};
    if (_selectedSubject != 'All') params['subject'] = _selectedSubject;
    if (_searchQuery.trim().isNotEmpty) params['q'] = _searchQuery.trim();
    final uri = Uri.parse('${AppApi.host}/api/documents/').replace(queryParameters: params.isEmpty ? null : params);
    try {
      final res = await http.get(uri, headers: AppSession.authHeaders());
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>).map((e) => _DocumentItem.fromJson(e as Map<String, dynamic>)).toList();
        if (!mounted) return;
        setState(() {
          _docs = list;
          _errorMessage = null;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _docs = [];
        _errorMessage = 'Không tải được dữ liệu tài liệu (${res.statusCode})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _docs = [];
        _errorMessage = 'Lỗi kết nối tới máy chủ tài liệu';
      });
    }
  }

  Future<void> _openDoc(DocumentModel doc) async {
    final hit = _docs.where((d) => d.id.toString() == doc.id).cast<_DocumentItem?>().firstWhere((e) => e != null, orElse: () => null);
    final url = hit?.fileUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  _DocumentItem? _findDocItem(DocumentModel doc) {
    return _docs.where((d) => d.id.toString() == doc.id).cast<_DocumentItem?>().firstWhere((e) => e != null, orElse: () => null);
  }

  Future<void> _showEditModal(BuildContext context, DocumentModel doc) async {
    final item = _findDocItem(doc);
    if (item == null) return;
    final titleController = TextEditingController(text: item.title);
    final descController = TextEditingController(text: item.description);
    String subject = item.subject.isEmpty ? _selectedSubject : item.subject;
    String category = item.category.isEmpty ? (_categories.length > 1 ? _categories[1] : 'Giáo trình') : item.category;
    String docType = item.documentType.isEmpty ? 'other' : item.documentType;

    await showModalBottomSheet(
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
                    const Text('Chỉnh sửa tài liệu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                _uploadField('Tên tài liệu', 'Nhập tên tài liệu', titleController),
                const SizedBox(height: 12),
                _uploadField('Mô tả', 'Viết mô tả tài liệu', descController, maxLines: 3),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _subjects.contains(subject) ? subject : (_subjects.length > 1 ? _subjects[1] : 'Flutter'),
                        items: _subjects.where((s) => s != 'All').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setModalState(() => subject = v ?? subject),
                        decoration: const InputDecoration(labelText: 'Môn học'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _categories.contains(category) ? category : (_categories.length > 1 ? _categories[1] : 'Giáo trình'),
                        items: _categories.where((s) => s != 'All').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setModalState(() => category = v ?? category),
                        decoration: const InputDecoration(labelText: 'Danh mục'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: const ['slide', 'report', 'exam', 'note', 'other'].contains(docType) ? docType : 'other',
                  items: const [
                    DropdownMenuItem(value: 'slide', child: Text('Slide')),
                    DropdownMenuItem(value: 'report', child: Text('Báo cáo')),
                    DropdownMenuItem(value: 'exam', child: Text('Đề thi')),
                    DropdownMenuItem(value: 'note', child: Text('Ghi chú')),
                    DropdownMenuItem(value: 'other', child: Text('Khác')),
                  ],
                  onChanged: (v) => setModalState(() => docType = v ?? docType),
                  decoration: const InputDecoration(labelText: 'Loại tài liệu'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final res = await http.patch(
                        Uri.parse('${AppApi.host}/api/documents/${item.id}/'),
                        headers: AppSession.authHeaders(extra: const {'Content-Type': 'application/json'}),
                        body: jsonEncode({
                          'title': title,
                          'description': descController.text.trim(),
                          'subject': subject,
                          'category': category,
                          'document_type': docType,
                        }),
                      );
                      if (!mounted) return;
                      if (res.statusCode == 200) {
                        Navigator.pop(ctx);
                        await _loadAll();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật tài liệu')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể chỉnh sửa tài liệu')));
                      }
                    },
                    child: const Text('Lưu thay đổi'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_isSearching) _buildTabBar(),
            Expanded(
              child: _isSearching
                  ? (_showSuggestions ? _buildSuggestions() : _buildSearchResults())
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_tabController.index == 0 && _errorMessage != null)
                      ? _buildErrorState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDocumentsTab(),
                        const GroupScreen(embedded: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (_isSearching)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearching = false;
                      _showSuggestions = false;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: Color(0xFF1A1A2E)),
                  ),
                ),
              Expanded(
                child: GestureDetector(
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
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSearching ? Colors.white : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: _isSearching ? Border.all(color: const Color(0xFFE8294E), width: 1.5) : Border.all(color: Colors.transparent),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: _isSearching ? const Color(0xFFE8294E) : const Color(0xFF9E9E9E), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isSearching
                              ? TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: _searchHint,
                                    hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      _searchQuery = v;
                                      _showSuggestions = v.isEmpty;
                                    });
                                    _loadDocs();
                                  },
                                  onSubmitted: (v) {
                                    setState(() {
                                      _searchQuery = v;
                                      _showSuggestions = false;
                                    });
                                    _loadDocs();
                                  },
                                )
                              : Text(_searchHint, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 15)),
                        ),
                        if (_isSearching && _searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _showSuggestions = true;
                              });
                              _loadDocs();
                            },
                            child: const Icon(Icons.close_rounded, color: Color(0xFF9E9E9E), size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_isSearching) ...[
                const SizedBox(width: 12),
                _buildUploadButton(),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    final isGroupTab = _tabController.index == 1;
    return GestureDetector(
      onTap: () {
        if (isGroupTab) {
          _showCreateGroupModal(context);
        } else {
          _showUploadModal(context);
        }
      },
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8294E), Color(0xFFFF6B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8294E).withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          isGroupTab ? Icons.group_add_rounded : Icons.add_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFFE8294E),
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: const Color(0xFFE8294E),
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: 'Tài liệu'),
          Tab(text: 'Nhóm'),
        ],
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
        _loadDocs();
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3 ? AppColors.primary : Colors.grey[500],
                  ),
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
    final results = _filteredDocs;
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Không có tài liệu phù hợp',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('${results.length} kết quả cho "$_searchQuery"', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (ctx, i) => _documentCard(results[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    final docs = _filteredDocs;
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có tài liệu cho môn học này',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCategoryBar()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tài liệu phổ biến', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                Text('Xem tất cả', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _documentCard(docs[i]),
              childCount: docs.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildCategoryBar() {
    final dynamicCategories = _subjects
        .map((s) => <String, dynamic>{
              'label': s == 'All' ? 'Tất cả' : s,
              'icon': s == 'All' ? Icons.grid_view_rounded : Icons.menu_book_rounded,
              'color': 0xFFE91E63,
            })
        .toList();
    final renderCategories = dynamicCategories.isNotEmpty ? dynamicCategories : categories;
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: renderCategories.length,
        itemBuilder: (ctx, i) {
          final cat = renderCategories[i];
          final isSelected = _selectedCategory == i;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = i;
                _selectedSubject = i < _subjects.length ? _subjects[i] : 'All';
              });
              _loadDocs();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.outline),
              ),
              child: Row(
                children: [
                  Icon(cat['icon'] as IconData, color: isSelected ? Colors.white : AppColors.primaryDark, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _documentCard(DocumentModel doc) {
    return GestureDetector(
      onTap: () => _showDocumentDetail(context, doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 68,
                decoration: BoxDecoration(
                  color: _hexToColor(doc.coverColor).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: _hexToColor(doc.coverColor), size: 28),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: _hexToColor(doc.coverColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _statChip(Icons.favorite_border_rounded, '${doc.likes}', const Color(0xFFE8294E)),
                        const SizedBox(width: 8),
                        _statChip(Icons.visibility_outlined, '${doc.views}', AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _actionBtn(Icons.visibility_outlined, AppColors.primaryDark, onTap: () => _showDocumentDetail(context, doc)),
                  const SizedBox(height: 8),
                  _actionBtn(Icons.edit_outlined, AppColors.primary, onTap: () => _showEditModal(context, doc)),
                  const SizedBox(height: 8),
                  _actionBtn(Icons.download_outlined, AppColors.primaryDark, onTap: () => _openDoc(doc)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.outline.withOpacity(0.8)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(count, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          border: Border.all(color: AppColors.outline.withOpacity(0.8)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Future<Uint8List?> _renderPdfFirstPage(String fileUrl) async {
    try {
      final res = await http.get(
        Uri.parse(fileUrl),
        headers: AppSession.authHeaders(),
      );
      if (res.statusCode != 200) return null;
      final document = await PdfDocument.openData(res.bodyBytes);
      final page = await document.getPage(1);
      final image = await page.render(
        width: page.width * 1.3,
        height: page.height * 1.3,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );
      final bytes = image?.bytes;
      await page.close();
      await document.close();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _getPdfPreview(int id, String fileUrl) {
    if (_pdfPreviewTasks.containsKey(id)) return _pdfPreviewTasks[id]!;
    final task = _renderPdfFirstPage(fileUrl).then((bytes) {
      _pdfPreviewCache[id] = bytes;
      return bytes;
    });
    _pdfPreviewTasks[id] = task;
    return task;
  }

  Widget _buildFallbackCover(DocumentModel doc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.picture_as_pdf_rounded, size: 60, color: _hexToColor(doc.coverColor)),
        const SizedBox(height: 8),
        Text(doc.subject, style: TextStyle(fontWeight: FontWeight.w700, color: _hexToColor(doc.coverColor), fontSize: 16)),
        const SizedBox(height: 4),
        Text(doc.year, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ],
    );
  }

  Widget _buildDocumentPreview(DocumentModel doc) {
    final item = _findDocItem(doc);
    final url = item?.fileUrl;
    if (item == null || url == null || url.isEmpty) return _buildFallbackCover(doc);
    final lowerUrl = url.toLowerCase();
    final isImage = RegExp(r'\.(png|jpe?g|webp|gif)(\?|$)').hasMatch(lowerUrl);
    final isPdf = lowerUrl.contains('.pdf');

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _buildFallbackCover(doc),
        ),
      );
    }

    if (!isPdf) return _buildFallbackCover(doc);
    final cached = _pdfPreviewCache[item.id];
    if (cached != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          cached,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _getPdfPreview(item.id, url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final bytes = snapshot.data;
        if (bytes == null) return _buildFallbackCover(doc);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }

  void _showDocumentDetail(BuildContext context, DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(doc.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E), height: 1.3)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF1A1A2E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statChip(Icons.favorite_border_rounded, '${doc.likes} lượt thích', const Color(0xFFE8294E)),
                        const SizedBox(width: 8),
                        _statChip(Icons.visibility_outlined, '${doc.views} lượt xem', AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _hexToColor(doc.coverColor).withOpacity(0.2),
                            _hexToColor(doc.coverColor).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _hexToColor(doc.coverColor).withOpacity(0.2)),
                      ),
                      child: _buildDocumentPreview(doc),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _hexToColor(doc.coverColor).withOpacity(0.2),
                            child: Text(doc.author[0], style: TextStyle(fontWeight: FontWeight.w700, color: _hexToColor(doc.coverColor))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc.author, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E))),
                                Text('Tác giả · ${doc.year}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8294E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Theo dõi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE8294E))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditModal(context, doc);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Chỉnh sửa'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openDoc(doc),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFE8294E), Color(0xFFFF6B6B)]),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: const Color(0xFFE8294E).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Tải xuống', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.bookmark_border_rounded, color: Color(0xFFC2185B), size: 22),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.share_outlined, color: Color(0xFFC2185B), size: 22),
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
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? 'Đã có lỗi xảy ra',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadAll,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
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
    List<_UserMini> visible = List<_UserMini>.from(friends);
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                  onChanged: (v) {
                    final q = v.trim().toLowerCase();
                    visible = friends.where((f) {
                      final hay = '${f.fullName} ${f.studentId} ${f.username}'
                          .toLowerCase();
                      return hay.contains(q);
                    }).toList();
                    setDialogState(() {});
                  },
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
        ),
      ),
    );
    return picked ?? (initialSelection ?? <String>{});
  }

  void _showUploadModal(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String subject = _subjects.length > 1 ? _subjects[1] : 'Flutter';
    String category = _categories.length > 1 ? _categories[1] : 'INT';
    String docType = 'other';
    PlatformFile? selected;
    Uint8List? bytes;
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
                    const Text('Tải tài liệu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
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
                    final result = await FilePicker.pickFiles(withData: true);
                    if (result == null || result.files.isEmpty) return;
                    selected = result.files.first;
                    bytes = selected!.bytes;
                    setModalState(() {});
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE8294E), size: 32),
                        const SizedBox(height: 6),
                        const Text('Nhấn để chọn file', style: TextStyle(color: Color(0xFFE8294E), fontWeight: FontWeight.w600)),
                        Text(selected?.name ?? 'PDF, DOCX, PPTX...', style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _uploadField('Tên tài liệu', 'Nhập tên tài liệu', titleController),
                const SizedBox(height: 12),
                _uploadField('Mô tả', 'Viết mô tả tài liệu', descController, maxLines: 3),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: subject,
                        items: _subjects.where((s) => s != 'All').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => subject = v ?? subject,
                        decoration: const InputDecoration(labelText: 'Môn học'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        items: _categories.where((s) => s != 'All').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => category = v ?? category,
                        decoration: const InputDecoration(labelText: 'Danh mục'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: docType,
                  items: const [
                    DropdownMenuItem(value: 'slide', child: Text('Slide')),
                    DropdownMenuItem(value: 'report', child: Text('Báo cáo')),
                    DropdownMenuItem(value: 'exam', child: Text('Đề thi')),
                    DropdownMenuItem(value: 'note', child: Text('Ghi chú')),
                    DropdownMenuItem(value: 'other', child: Text('Khác')),
                  ],
                  onChanged: (v) => docType = v ?? docType,
                  decoration: const InputDecoration(labelText: 'Loại tài liệu'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          if (titleController.text.trim().isEmpty || selected == null || bytes == null) return;
                          final req = http.MultipartRequest('POST', Uri.parse('${AppApi.host}/api/documents/'));
                          req.headers.addAll(AppSession.authHeaders());
                          req.fields['username'] = AppSession.username;
                          req.fields['title'] = titleController.text.trim();
                          req.fields['subject'] = subject;
                          req.fields['category'] = category;
                          req.fields['document_type'] = docType;
                          req.fields['description'] = descController.text.trim();
                          req.files.add(http.MultipartFile.fromBytes('file', bytes!, filename: selected!.name));
                          final streamed = await req.send();
                          if (!mounted) return;
                          if (streamed.statusCode == 201) {
                            Navigator.pop(ctx);
                            _loadAll();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng tài liệu thành công')));
                          }
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFE8294E), Color(0xFFFF6B6B)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: const Color(0xFFE8294E).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Center(
                            child: Text('Đăng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
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

  void _showCreateGroupModal(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    int selectedPrivacy = 0;
    final selectedInviteUsers = <String>{};
    Uint8List? avatarBytes;
    String? avatarDataUri;
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
        builder: (ctx, setModalState) {
          return Padding(
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
                      const Text(
                        'Tạo nhóm mới',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                      final ext =
                          picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
                      setModalState(() {
                        avatarBytes = bytes;
                        avatarDataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';
                      });
                    },
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.outline, width: 1.2),
                      ),
                      child: avatarBytes == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded, color: Color(0xFFE8294E)),
                                SizedBox(height: 6),
                                Text(
                                  'Tải ảnh đại diện nhóm',
                                  style: TextStyle(
                                    color: Color(0xFFE8294E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                avatarBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 100,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _uploadField('Tên nhóm', 'Nhập tên nhóm', titleController),
                  const SizedBox(height: 12),
                  _uploadField('Mô tả', 'Mô tả nhóm học tập', descController, maxLines: 3),
                  const SizedBox(height: 12),
                  Text(
                    'Mời bạn bè',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
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
                  const SizedBox(height: 12),
                  const Text(
                    'Chế độ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: privacyOptions.asMap().entries.map((e) {
                      final isSelected = selectedPrivacy == e.key;
                      final color = Color(e.value['color'] as int);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedPrivacy = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.12)
                                  : const Color(0xFFF7F8FC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  e.value['icon'] as IconData,
                                  size: 18,
                                  color: isSelected ? color : Colors.grey[400],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  e.value['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? color : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      selectedPrivacy == 0
                          ? 'Ai cũng có thể tìm và tham gia nhóm.'
                          : selectedPrivacy == 1
                              ? 'Chỉ thành viên được mời mới tham gia.'
                              : 'Nhóm ẩn khỏi tìm kiếm công khai.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập tên nhóm')),
                          );
                          return;
                        }
                        final res = await http.post(
                          Uri.parse('${AppApi.groups}/'),
                          headers: AppSession.authHeaders(
                            extra: const {'Content-Type': 'application/json'},
                          ),
                          body: jsonEncode({
                            'title': titleController.text.trim(),
                            'subject': _selectedSubject == 'All' ? 'General' : _selectedSubject,
                            'category': selectedPrivacy == 0
                                ? 'public'
                                : selectedPrivacy == 1
                                    ? 'private'
                                    : 'secret',
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
                          if (groupId != null && selectedInviteUsers.isNotEmpty) {
                            for (final username in selectedInviteUsers) {
                              await http.post(
                                Uri.parse('${AppApi.groups}/$groupId/invite/'),
                                headers: AppSession.authHeaders(
                                  extra: const {'Content-Type': 'application/json'},
                                ),
                                body: jsonEncode({'target_username': username}),
                              );
                            }
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tạo nhóm thành công')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Không thể tạo nhóm')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Tạo nhóm'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _uploadField(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC2185B))),
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
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              hintText: hint,
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
