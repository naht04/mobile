import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile_app/screens/feed_screen.dart';

class FeedDetailScreen extends StatefulWidget {
  const FeedDetailScreen({
    super.key,
    required this.item,
    this.initialImageUrl,
  });

  final FeedItem item;
  final String? initialImageUrl;

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  late String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _resolvedImageUrl = widget.initialImageUrl ?? widget.item.imageUrl;
  }

  Future<void> _openOriginal(BuildContext context) async {
    final uri = Uri.parse(widget.item.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong mo duoc bai viet goc')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết bài viết')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 180,
              color: const Color(0xFFFFE6EF),
              child: _resolvedImageUrl != null && _resolvedImageUrl!.isNotEmpty
                  ? Image.network(
                      _resolvedImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.newspaper_outlined,
                        size: 60,
                        color: Colors.black54,
                      ),
                    )
                  : const Icon(
                      Icons.newspaper_outlined,
                      size: 60,
                      color: Colors.black54,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.item.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.public, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.item.source,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              if (widget.item.publishedAt.isNotEmpty)
                Text(
                  widget.item.publishedAt,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.item.summary.isEmpty
                ? 'Bài viết không có mô tả ngắn. Nhấn nút bên dưới để đọc bản gốc từ website trường.'
                : widget.item.summary,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openOriginal(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Mở bài gốc từ website PTIT'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFFF33B6D),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
