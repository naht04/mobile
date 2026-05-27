import 'package:flutter/material.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  late List<Map<String, dynamic>> violatingUsers;
  late List<Map<String, dynamic>> violatingPosts;

  @override
  void initState() {
    super.initState();
    _generateMockData();
  }

  void _generateMockData() {
    final lastNames = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Vũ', 'Bùi', 'Đỗ'];
    final firstNames = ['An', 'Bình', 'Châu', 'Dũng', 'Hà', 'Khang', 'Linh', 'Minh', 'Tuấn', 'Trang'];

    violatingUsers = List.generate(30, (index) {
      final types = ['Ngôn từ thô tục', 'Spam link', 'Không phù hợp', 'Quấy rối'];
      final reasons = [
        'Chửi bậy, dùng từ ngữ xúc phạm sinh viên khác trong nhóm chat.',
        'Spam hàng loạt link quảng cáo rác trên bình luận dạo.',
        'Sử dụng ảnh đại diện phản cảm, vi phạm tiêu chuẩn cộng đồng.',
        'Nhắn tin làm phiền, có hành vi quấy rối người khác.'
      ];
      final contents = [
        'Chat: "Thằng ngu này code cái kiểu gì vậy hả..."',
        'Bình luận: "Click ngay link này để nhận 100k thẻ cào..."',
        'Hồ sơ: [Hình ảnh đại diện chứa nội dung nhạy cảm]',
        'Chat: Spam liên tục 20 tin nhắn gạ gẫm làm quen.'
      ];

      int typeIndex = index % 4;
      String name = '${lastNames[index % lastNames.length]} ${firstNames[index % firstNames.length]}';
      String svId = 'sv${(index + 10).toString().padLeft(3, '0')}';
      String gender = index % 2 == 0 ? 'men' : 'women';

      return {
        'name': '$name ($svId)',
        'reason': reasons[typeIndex],
        'violationType': types[typeIndex],
        'avatar': 'https://randomuser.me/api/portraits/$gender/${(index + 10) % 99}.jpg',
        'violatingContent': contents[typeIndex],
        'timeReported': '${(index % 23) + 1} giờ trước',
      };
    });

    violatingPosts = List.generate(30, (index) {
      final types = ['Ngôn từ thô tục', 'Spam/Quảng cáo', 'Không phù hợp', 'Nội dung rác'];
      final reasons = [
        'Tiêu đề bài viết chứa từ ngữ chửi thề, công kích.',
        'Đăng bài quảng cáo bán tài khoản game, dịch vụ ngoài.',
        'Chia sẻ hình ảnh bạo lực, bóc phốt cá nhân.',
        'Đăng bài vô nghĩa, copy-paste lặp đi lặp lại.'
      ];
      final contents = [
        'Tiêu đề: "Đm cái môn học này chán vãi..."',
        'Nội dung: "Mình chuyên nhận cày thuê rank, bán acc giá rẻ..."',
        'Nội dung: "Tránh xa cái thằng này ra nhé anh em..." (kèm ảnh mâu thuẫn)',
        'Nội dung: "test test test test test test test"'
      ];

      int typeIndex = index % 4;
      String name = '${lastNames[(index + 3) % lastNames.length]} ${firstNames[(index + 5) % firstNames.length]}';
      String svId = 'sv${(index + 50).toString().padLeft(3, '0')}';

      return {
        'author': '$name ($svId)',
        'time': '${(index % 23) + 1} giờ trước',
        'content': contents[typeIndex],
        'reason': reasons[typeIndex],
        'violationType': types[typeIndex],
        'image': 'https://picsum.photos/400/250?random=${200 + index}',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 10,
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFFF3B5C),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "Người dùng"),
              Tab(text: "Bài viết"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildViolationList(isUser: true), // Tab xử lý người dùng
            _buildViolationList(isUser: false), // Tab xử lý bài viết
          ],
        ),
      ),
    );
  }

  // Giao diện danh sách vi phạm
  Widget _buildViolationList({required bool isUser}) {
    final list = isUser ? violatingUsers : violatingPosts;
    
    if (list.isEmpty) {
      return const Center(child: Text("Hiện không có báo cáo vi phạm nào."));
    }

    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Thông tin đối tượng vi phạm
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(isUser ? item['avatar'] : 'https://picsum.photos/100?random=${index}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? item['name'] : item['author'], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                        ),
                        Text(
                          isUser ? "Bị báo cáo ${item['timeReported']}" : "Đăng lúc ${item['time']}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Nhãn loại vi phạm (Tag)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                    child: Text(
                      item['violationType'],
                      style: const TextStyle(color: Color(0xFFFF3B5C), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              // Nội dung vi phạm
              if (!isUser) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(item['content'], style: const TextStyle(fontSize: 14, color: Colors.black87, fontStyle: FontStyle.italic)),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(item['image'], height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              ] else if (item.containsKey('violatingContent')) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bằng chứng vi phạm:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "\"${item['violatingContent']}\"",
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                    children: [
                      const TextSpan(text: "Mô tả từ cộng đồng: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: item['reason']),
                    ],
                  ),
                ),
              ),

              // Nhóm nút thao tác (Pill Shape)
              Row(
                children: [
                  _pillButton("Cảnh cáo", Colors.orange, () => _handleAction("cảnh cáo", index, isUser)),
                  const SizedBox(width: 8),
                  _pillButton(
                    isUser ? "Khóa tài khoản" : "Xóa bài", 
                    const Color(0xFFFF3B5C), 
                    () => _handleAction(isUser ? "khóa" : "xóa", index, isUser)
                  ),
                  const SizedBox(width: 8),
                  _pillButton("Bỏ qua", Colors.grey, () => _handleAction("bỏ qua", index, isUser)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
            ],
          ),
        );
      },
    );
  }

  // Widget nút bấm hình viên thuốc
  Widget _pillButton(String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          text, 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Logic xử lý hành động
  void _handleAction(String action, int index, bool isUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Xác nhận $action?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          _pillButton("Chắc chắn", Colors.green, () {
            Navigator.pop(ctx);
            setState(() {
              if (isUser) {
                violatingUsers.removeAt(index);
              } else {
                violatingPosts.removeAt(index);
              }
            });
            _showAutoCloseDialog("Đã thực hiện $action thành công!");
          }),
          _pillButton("Hủy", const Color(0xFFFF3B5C), () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _showAutoCloseDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }
}