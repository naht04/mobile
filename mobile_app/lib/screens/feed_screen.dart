import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/avatar_utils.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/feed_detail_screen.dart';
import 'package:mobile_app/screens/profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<FeedItem>> _futureItems;
  final Map<String, String?> _resolvedImageCache = {};

  @override
  void initState() {
    super.initState();
    _futureItems = _fetchFeed();
  }

  Future<List<FeedItem>> _fetchFeed() async {
    final uri = Uri.parse(
      'http://127.0.0.1:8000/api/community/auto-feed/?limit=15',
    );
    final response = await http.get(uri, headers: AppSession.authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Khong tai duoc feed');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['results'] as List<dynamic>? ?? [])
        .map((item) => FeedItem.fromJson(item as Map<String, dynamic>))
        .toList();
    _prefetchImages(list);
    return list;
  }

  void _prefetchImages(List<FeedItem> items) {
    for (final item in items.take(8)) {
      if ((item.imageUrl ?? '').isNotEmpty) {
        _resolvedImageCache[item.url] = item.imageUrl;
        continue;
      }
      if (_resolvedImageCache.containsKey(item.url)) continue;
      _resolveImageForItem(item);
    }
  }

  Future<void> _resolveImageForItem(FeedItem item) async {
    final url = item.url;
    if (_resolvedImageCache.containsKey(url)) return;
    _resolvedImageCache[url] = null;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;
      final resolved = _extractImageUrl(response.body, uri);
      if (!mounted || resolved == null || resolved.isEmpty) return;
      setState(() => _resolvedImageCache[url] = resolved);
    } catch (_) {
      // Keep text-only card when source blocks image extraction.
    }
  }

  String? _extractImageUrl(String html, Uri baseUri) {
    final patterns = <RegExp>[
      RegExp(
        r'''<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final raw = (match.group(1) ?? '').trim();
      if (raw.isEmpty) continue;
      final resolved = _resolveUrl(raw, baseUri);
      if (resolved == null) continue;
      if (resolved.toLowerCase().endsWith('.svg')) continue;
      return resolved;
    }
    return null;
  }

  String? _resolveUrl(String raw, Uri baseUri) {
    if (raw.startsWith('data:')) return null;
    if (raw.startsWith('//')) return '${baseUri.scheme}:$raw';
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed.toString();
    return baseUri.resolveUri(parsed).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PTIT Connect'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: 'Hồ sơ',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              icon: initialsAvatar(
                AppSession.username,
                radius: 16,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final next = _fetchFeed();
          setState(() => _futureItems = next);
          await next;
        },
        child: FutureBuilder<List<FeedItem>>(
          future: _futureItems,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Loi tai du lieu feed')),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Chua co bai viet')),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final item = items[index];
                final imageUrl = _resolvedImageCache[item.url] ?? item.imageUrl;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(
                          item: item,
                          initialImageUrl: imageUrl,
                        ),
                      ),
                    );
                  },
                  child: Ink(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF4CBD8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((imageUrl ?? '').isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              imageUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 140,
                                width: double.infinity,
                                alignment: Alignment.center,
                                color: const Color(0xFFFFE6EF),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.summary.isEmpty
                              ? 'Mo bai viet goc de xem chi tiet.'
                              : item.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.public,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.source,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                            const Icon(Icons.open_in_new, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class FeedItem {
  const FeedItem({
    required this.title,
    required this.url,
    required this.summary,
    required this.source,
    required this.publishedAt,
    required this.imageUrl,
  });

  final String title;
  final String url;
  final String summary;
  final String source;
  final String publishedAt;
  final String? imageUrl;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      title: (json['title'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      source: (json['source'] ?? 'ptit.edu.vn').toString(),
      publishedAt: (json['published_at'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }
}
