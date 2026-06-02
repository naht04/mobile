# PTIT Connect App

Hệ sinh thái kết nối và truyền thông nội bộ đa nền tảng dành cho cộng đồng sinh viên Học viện Công nghệ Bưu chính Viễn thông (PTIT). Hệ thống được thiết kế theo kiến trúc Client-Server toàn diện, hỗ trợ tương tác và liên lạc thời gian thực hiệu năng cao.

## 🚀 Tính năng nổi bật

### 1. Giao tiếp & Liên lạc Real-time (Hạt nhân công nghệ)
* **Cuộc gọi Video/Voice (WebRTC):** Hỗ trợ thiết lập cuộc gọi chất lượng cao, độ trễ thấp thông qua kết nối ngang hàng (Peer-to-Peer). Quản lý vòng đời cuộc gọi chặt chẽ và tích hợp giao diện phủ (Call Overlay) mượt mà.
* **Nhắn tin tức thời:** Trò chuyện thời gian thực (Chat 1-1 và Chat Group), tự động đồng bộ trạng thái tin nhắn.
* **Thông báo thông minh:** Hệ thống Push Notification thời gian thực đẩy cảnh báo tương tác, tin nhắn, cuộc gọi đến ngay lập tức.

### 2. Mạng xã hội & Không gian cộng đồng
* **Bảng tin tự động (Auto-feed):** Tự động crawl và cập nhật tin tức mới nhất từ cổng thông tin website chính thức của PTIT.
* **Tương tác chia sẻ:** Tạo bài viết, tìm kiếm và lọc nội dung thông minh theo `#category`.
* **Phản hồi cộng đồng:** Hỗ trợ bình luận (Comment), tương tác (React) và lưu trữ bài viết (Save).

### 3. Quản lý Tài liệu Học tập
* **Kho lưu trữ tập trung:** Quản lý và phân loại tài liệu theo danh mục, hội nhóm hoặc lớp học.
* **Đọc trực tuyến tích hợp:** Trình đọc file PDF trực tiếp ngay trong ứng dụng mà không cần thông qua ứng dụng bên thứ ba.

### 4. Phân hệ Quản trị & Xác thực Bảo mật
* **Hồ sơ sinh viên (Social Identity):** Quản lý thông tin cá nhân, avatar, danh sách bạn bè và hội nhóm đang tham gia.
* **Xác thực Đa phương thức:** Hỗ trợ cơ chế Đăng nhập Mock-mode phục vụ phát triển nhanh và Đăng nhập bảo mật đồng bộ tài khoản tổ chức qua **Microsoft OAuth2 Webview**.
* **Admin Dashboard & Moderation:** Giao diện quản trị chuyên dụng cho Admin để theo dõi số liệu hệ thống và kiểm duyệt nội dung, xử lý báo cáo vi phạm cộng đồng.

---

## 🏗️ Cấu trúc dự án

```txt
PTITCONNECT_APP/
 ├── mobile_app/      # Flutter Client (Hỗ trợ đa nền tảng: Mobile, Web, Desktop)
 ├── backend/         # Django REST API + WebSocket Server
 ├── docker-compose.yml # Cấu hình container hóa toàn bộ dịch vụ
 ├── .gitignore
 └── readme.md
🛠️ Công nghệ sử dụng
Frontend (Multi-platform Client)
Framework: Flutter (Dart)

Quản lý trạng thái & Kết nối: http, shared_preferences, url_launcher

Real-time & Tài liệu: flutter_webrtc, pdfx, file_picker

Xác thực: webview_flutter

Backend (API & Real-time Server)
Core Framework: Django & Django REST Framework

Real-time Engine: Django Channels / WebSocket & Socket.io

Xác thực & Bảo mật: djangorestframework-simplejwt, django-cors-headers

Database & Khác: PostgreSQL, BeautifulSoup4 (Crawl Engine), Pillow

💻 Yêu cầu môi trường
Flutter stable (hỗ trợ SDK mới nhất)

Python 3.11+

PostgreSQL 14+ hoặc Docker Engine

📦 Hướng dẫn cài đặt và Triển khai nhanh
Cách 1: Triển khai nhanh bằng Docker Compose (Khuyến nghị)
Hệ thống hỗ trợ đóng gói container hóa toàn bộ các dịch vụ (Database, Backend, Các Microservices bổ trợ nếu có) thông qua Docker:

Bash
# Khởi chạy toàn bộ hệ thống Backend và Database trong 1 câu lệnh
docker-compose up -d --build
Cách 2: Triển khai thủ công (Manual Setup)
1) Phân hệ Backend
Bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install django djangorestframework django-cors-headers djangorestframework-simplejwt pillow psycopg[binary] python-dotenv requests beautifulsoup4
Tạo file .env tại thư mục gốc của backend (tham khảo cấu hình mẫu):

Code snippet
USE_POSTGRES=true
POSTGRES_DB=ptit_connect_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=123456
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
Khởi tạo cơ sở dữ liệu và chạy Server:

Bash
python manage.py migrate
python manage.py runserver
2) Phân hệ Mobile App (Flutter Client)
Bash
cd mobile_app
flutter pub get
# Chạy ứng dụng trên môi trường Web Chrome
flutter run -d chrome
# Hoặc chạy trên thiết bị di động / giả lập Android/iOS
flutter run
📊 Seed dữ liệu mẫu (Community Testing)
Để tạo nhanh dữ liệu kiểm thử hệ thống cộng đồng (khoảng 30-50 bài viết mẫu):

Bash
cd backend
source venv/bin/activate
python manage.py seed_community --count 40
🗺️ Hệ thống API Endpoints chính
👤 Định danh & Người dùng (Users & Identity)
POST /api/users/register/ - Đăng ký tài khoản

POST /api/users/login/ - Đăng nhập hệ thống (Cấp mã JWT)

GET/PATCH /api/users/profile/ - Xem/Cập nhật thông tin hồ sơ

GET /api/users/search/ - Tìm kiếm sinh viên trong hệ thống

📝 Cộng đồng & Tin tức (Community & Feed)
GET /api/community/auto-feed/ - Lấy danh sách tin tức tự động crawl từ website PTIT

GET/POST /api/community/posts/ - Danh sách bài viết / Tạo bài viết mới

GET /api/community/posts/<id>/ - Chi tiết bài viết cụ thể

POST /api/community/posts/<id>/comments/ - Gửi bình luận vào bài viết

POST /api/community/posts/<id>/react/ - Tương tác cảm xúc bài viết

POST /api/community/posts/<id>/save/ - Lưu trữ bài viết về bộ sưu tập cá nhân

💬 Trò chuyện & Kết nối Real-time (Chat & Signaling)
GET /api/chat/ - Lấy danh sách các phòng hội thoại hiện tại

POST /api/chat/open/ - Khởi tạo luồng chat với người dùng khác

GET/POST /api/chat/<id>/messages/ - Lấy lịch sử tin nhắn / Gửi tin nhắn mới

Giao tiếp WebRTC Signaling phục vụ cuộc gọi Video/Voice được xử lý qua kênh WebSocket riêng biệt tại cấu hình cổng real-time.

🔔 Thông báo (Notifications)
GET/POST /api/notifications/ - Lấy danh sách thông báo cá nhân

POST /api/notifications/read-all/ - Đánh dấu đã đọc toàn bộ thông báo

POST /api/notifications/<id>/read/ - Đánh dấu đã đọc một thông báo cụ thể

🤝 Bạn bè & Hội nhóm (Social Network)
GET /api/users/friends/ - Lấy danh sách bạn bè đã kết nối

GET /api/users/friends/requests/inbox/ - Hộp thư đến chứa lời mời kết bạn

POST /api/users/friends/requests/send/ - Gửi lời mời kết bạn mới

POST /api/users/friends/requests/<id>/decide/ - Chấp nhận hoặc từ chối lời mời kết bạn

🛠️ Ghi chú Phát triển & Khắc phục sự cố
CORS Policy (Môi trường Web): Khi chạy ứng dụng trên nền tảng Web có thể gặp lỗi CORS nếu dùng các custom headers phức tạp. Ứng dụng hiện tại đã được tối ưu hóa bằng cách truyền định danh username qua query/body để bypass thành công các lỗi tiền kiểm duyệt (preflight check) của trình duyệt.

Microsoft OAuth2 Flow: Luồng xác thực Microsoft Azure cần các thông số Tenant ID và Client App Registration hợp lệ từ Azure Portal để vận hành trên môi trường Production.

Mock Login Mode: Chế độ đăng nhập giả lập (Mock mode) đang được kích hoạt mặc định ở môi trường Local giúp lập trình viên phát triển nhanh giao diện (UI) và luồng nghiệp vụ (Flow) mà không phụ thuộc vào quyền hạn Azure Enterprise.
