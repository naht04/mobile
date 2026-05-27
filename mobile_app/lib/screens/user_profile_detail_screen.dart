import 'package:flutter/material.dart';

class UserProfileDetailScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserProfileDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final className = user['class_code'] ?? 'D22CNPM01';
    final major = user['major'] ?? 'CNTT';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      body: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(user['avatar_url'] ?? 'https://picsum.photos/200?random=99'),
          ),
          const SizedBox(height: 15),
          Text(user['name'] ?? 'Sinh viên', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("$className - Khoa $major", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(children: [Text("2", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("Nhóm tham gia")]),
              Column(children: [Text("5", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("Bài viết cộng đồng")]),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _bottomBtn("Khóa tài khoản", const Color(0xFFFF3B5C), () => _confirmLock(context)),
                const SizedBox(width: 10),
                _bottomBtn("Cảnh cáo", Colors.orange, () {}),
                const SizedBox(width: 10),
                _bottomBtn("Quay lại", Colors.grey, () => Navigator.pop(context)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _bottomBtn(String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  void _confirmLock(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bạn có chắc muốn xóa tài khoản này?", textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _showReasonDialog(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Chắc chắn", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B5C)),
            child: const Text("Hủy", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReasonDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Điền lý do", textAlign: TextAlign.center),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nhập lý do...", border: OutlineInputBorder()),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _showSuccessAndExit(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Xác nhận", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B5C)),
            child: const Text("Hủy", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessAndExit(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Text("Xóa thành công!", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context);
      Navigator.pop(context, "deleted");
    });
  }
}