import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _loading = true;
  List<_DocumentItem> _docs = [];
  List<String> _subjects = ['All'];
  List<String> _categories = ['All'];
  String _selectedSubject = 'All';
  String _selectedCategory = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
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
      final values = (body['subjects'] as List<dynamic>? ??
              body['results'] as List<dynamic>? ??
              [])
          .map((e) => e.toString())
          .toList();
      final categoryValues = (body['categories'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      setState(() {
        _subjects = ['All', ...values];
        _categories = ['All', ...categoryValues];
      });
    }
  }

  Future<void> _loadDocs() async {
    final params = <String, String>{};
    if (_selectedSubject != 'All') params['subject'] = _selectedSubject;
    if (_selectedCategory != 'All') params['category'] = _selectedCategory;
    if (_query.trim().isNotEmpty) params['q'] = _query.trim();
    final uri = Uri.parse(
      '${AppApi.host}/api/documents/',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: AppSession.authHeaders());
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _DocumentItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _docs = list);
    }
  }

  Future<void> _openDoc(_DocumentItem doc) async {
    final url = doc.fileUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _normalizeDropdownLabel(String value) {
    if (value.isEmpty) return value;
    if (value == value.toUpperCase() && value.length > 1) {
      return '${value[0]}${value.substring(1).toLowerCase()}';
    }
    return value;
  }

  Future<void> _showUploadDialog() async {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    String subject = _subjects.length > 1 ? _subjects[1] : 'Flutter';
    String category = 'INT';
    String docType = 'other';
    PlatformFile? selected;
    Uint8List? bytes;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đăng tài liệu'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề',
                      labelStyle: TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: subject,
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                    items: _subjects
                        .where((s) => s != 'All')
                        .map((s) => DropdownMenuItem(value: s, child: Text(_normalizeDropdownLabel(s), style: const TextStyle(fontWeight: FontWeight.normal))))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => subject = v ?? subject),
                    decoration: const InputDecoration(labelText: 'Môn học', labelStyle: TextStyle(fontWeight: FontWeight.normal)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(value: 'INT', child: Text('INT', style: TextStyle(fontWeight: FontWeight.normal))),
                      DropdownMenuItem(value: 'BAS', child: Text('BAS', style: TextStyle(fontWeight: FontWeight.normal))),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => category = v ?? category),
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      labelStyle: TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: docType,
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(value: 'slide', child: Text('Slide', style: TextStyle(fontWeight: FontWeight.normal))),
                      DropdownMenuItem(value: 'report', child: Text('Báo cáo', style: TextStyle(fontWeight: FontWeight.normal))),
                      DropdownMenuItem(value: 'exam', child: Text('Đề thi', style: TextStyle(fontWeight: FontWeight.normal))),
                      DropdownMenuItem(value: 'note', child: Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.normal))),
                      DropdownMenuItem(value: 'other', child: Text('Khác', style: TextStyle(fontWeight: FontWeight.normal))),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => docType = v ?? docType),
                    decoration: const InputDecoration(
                      labelText: 'Loại tài liệu',
                      labelStyle: TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtl,
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      labelStyle: TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.pickFiles(
                        withData: true,
                      );
                      if (result == null || result.files.isEmpty) return;
                      selected = result.files.first;
                      bytes = selected!.bytes;
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Chọn file'),
                  ),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        selected!.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty ||
                    bytes == null ||
                    selected == null) {
                  return;
                }
                final req = http.MultipartRequest(
                  'POST',
                  Uri.parse('${AppApi.host}/api/documents/'),
                );
                req.headers.addAll(AppSession.authHeaders());
                req.fields['username'] = AppSession.username;
                req.fields['title'] = titleCtl.text.trim();
                req.fields['subject'] = subject;
                req.fields['category'] = category;
                req.fields['document_type'] = docType;
                req.fields['description'] = descCtl.text.trim();
                req.files.add(
                  http.MultipartFile.fromBytes(
                    'file',
                    bytes!,
                    filename: selected!.name,
                  ),
                );
                final streamed = await req.send();
                if (streamed.statusCode == 201 && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Tải tài liệu'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('#Tài liệu'),
        actions: [
          IconButton(
            onPressed: _showUploadDialog,
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: TextField(
                    onChanged: (v) {
                      _query = v;
                      _loadDocs();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm tài liệu...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    children: _subjects.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s == 'All' ? '#Tất cả' : '#$s'),
                          selected: _selectedSubject == s,
                          onSelected: (_) {
                            setState(() => _selectedSubject = s);
                            _loadDocs();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    children: _categories.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s == 'All' ? '#Danh_mục' : '#$s'),
                          selected: _selectedCategory == s,
                          onSelected: (_) {
                            setState(() => _selectedCategory = s);
                            _loadDocs();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _docs.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = _docs[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.pink.shade200),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  '${d.downloadCount} lượt tải',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    d.uploaderName,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openDoc(d),
                                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                                    label: const Text('PDF'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      side: BorderSide(color: Colors.grey.shade400),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _showDetail(d),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.pink.shade800,
                                      side: BorderSide(color: Colors.pink.shade400),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    child: const Text('Xem thông tin tài liệu'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showDetail(_DocumentItem d) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(d.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Môn: ${d.subject}'),
            const SizedBox(height: 6),
            Text('Danh mục: ${d.category.isEmpty ? "Khác" : d.category}'),
            const SizedBox(height: 6),
            Text('Loại: ${d.documentType}'),
            const SizedBox(height: 6),
            Text('Người đăng: ${d.uploaderName}'),
            const SizedBox(height: 6),
            Text('Lượt tải: ${d.downloadCount}'),
            const SizedBox(height: 10),
            Text(d.description.isEmpty ? 'Không có mô tả' : d.description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          if (d.uploaderName.toLowerCase() == AppSession.username.toLowerCase())
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editDoc(d);
              },
              child: const Text('Chỉnh sửa'),
            ),
          ElevatedButton(
            onPressed: () => _openDoc(d),
            child: const Text('Mở tài liệu'),
          ),
        ],
      ),
    );
  }

  Future<void> _editDoc(_DocumentItem doc) async {
    final titleCtl = TextEditingController(text: doc.title);
    final descCtl = TextEditingController(text: doc.description);
    String subject = doc.subject;
    String category = doc.category.isEmpty ? 'INT' : doc.category;
    String docType = doc.documentType;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chỉnh sửa tài liệu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                labelStyle: TextStyle(fontWeight: FontWeight.normal),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: subject,
              style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
              items: _subjects
                  .where((s) => s != 'All')
                  .map((s) => DropdownMenuItem(value: s, child: Text(_normalizeDropdownLabel(s), style: const TextStyle(fontWeight: FontWeight.normal))))
                  .toList(),
              onChanged: (v) => subject = v ?? subject,
              decoration: const InputDecoration(labelText: 'Môn học', labelStyle: TextStyle(fontWeight: FontWeight.normal)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: category,
              style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'INT', child: Text('INT', style: TextStyle(fontWeight: FontWeight.normal))),
                DropdownMenuItem(value: 'BAS', child: Text('BAS', style: TextStyle(fontWeight: FontWeight.normal))),
              ],
              onChanged: (v) => category = v ?? category,
              decoration: const InputDecoration(
                labelText: 'Danh mục',
                labelStyle: TextStyle(fontWeight: FontWeight.normal),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: docType,
              style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'slide', child: Text('Slide', style: TextStyle(fontWeight: FontWeight.normal))),
                DropdownMenuItem(value: 'report', child: Text('Báo cáo', style: TextStyle(fontWeight: FontWeight.normal))),
                DropdownMenuItem(value: 'exam', child: Text('Đề thi', style: TextStyle(fontWeight: FontWeight.normal))),
                DropdownMenuItem(value: 'note', child: Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.normal))),
                DropdownMenuItem(value: 'other', child: Text('Khác', style: TextStyle(fontWeight: FontWeight.normal))),
              ],
              onChanged: (v) => docType = v ?? docType,
              decoration: const InputDecoration(
                labelText: 'Loại tài liệu',
                labelStyle: TextStyle(fontWeight: FontWeight.normal),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtl,
              style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                labelStyle: TextStyle(fontWeight: FontWeight.normal),
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
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final req = http.MultipartRequest(
      'PATCH',
      Uri.parse('${AppApi.documents}/${doc.id}/'),
    );
    req.headers.addAll(AppSession.authHeaders());
    req.fields['username'] = AppSession.username;
    req.fields['title'] = titleCtl.text.trim();
    req.fields['subject'] = subject;
    req.fields['category'] = category;
    req.fields['document_type'] = docType;
    req.fields['description'] = descCtl.text.trim();
    final streamed = await req.send();
    if (streamed.statusCode == 200) {
      _loadAll();
    }
  }
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
