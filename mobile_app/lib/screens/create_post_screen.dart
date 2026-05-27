import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> newPost)? onPostCreated;

  const CreatePostScreen({super.key, this.onPostCreated});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  bool _isPosting = false;

  // Biến lưu trữ file
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // ── HÀM CHỌN ẢNH ──
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  // ── HÀM GỬI DỮ LIỆU LÊN SERVER ──
  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung bài viết')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final title = content.length > 60 ? '${content.substring(0, 60)}...' : content;
      var request = http.MultipartRequest('POST', Uri.parse('${AppApi.community}/posts/'));
      request.headers.addAll(AppSession.authHeaders());

      // 1. Thêm các trường Text
      request.fields['username'] = AppSession.username;
      request.fields['title'] = title;
      request.fields['content'] = content;
      request.fields['topic'] = 'Community'; // Mặc định ẩn

      // 2. Xử lý đính kèm Ảnh
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: _selectedImage!.name,
        ));
      }

      var streamedResponse = await request.send();
      var res = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (res.statusCode == 201) {
        final newPost = jsonDecode(res.body) as Map<String, dynamic>;
        widget.onPostCreated?.call(newPost);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng bài thất bại: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // THAY ĐỔI Ở ĐÂY: Dùng Material làm widget gốc thay vì Container
    return Material(
      color: Colors.white, // Nền trắng
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 18, bottom: bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── HEADER ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), 
                const Text('Tạo bài viết', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── KHUNG NHẬP NỘI DUNG ──
            TextField(
              controller: _contentController,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Bạn đang nghĩ gì?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── PREVIEW ẢNH NẾU ĐƯỢC CHỌN ──
            if (_selectedImage != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: kIsWeb
                        ? Image.network(_selectedImage!.path, height: 120, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(_selectedImage!.path), height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── HÀNG NÚT ĐÍNH KÈM ──
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Ảnh'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── NÚT ĐĂNG ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isPosting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Đăng bài', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}