# PTIT Connect App

Ứng dụng kết nối sinh viên PTIT gồm:
- `mobile_app`: Flutter (web/mobile)
- `backend`: Django REST API + PostgreSQL

## Tính năng chính

- Đăng nhập (mock mode để dev nhanh, có luồng Microsoft để mở rộng)
- Feed tự động crawl tin từ website PTIT
- Cộng đồng:
  - tạo bài viết
  - tìm kiếm + lọc theo `#category`
  - bình luận
  - react / save
- Nhắn tin:
  - mở hội thoại với user tồn tại
  - gửi/nhận tin
  - auto refresh
- Thông báo
- Kết bạn (gửi lời mời, duyệt lời mời, danh sách bạn bè)
- Hồ sơ cá nhân (xem/sửa)

---

## Cấu trúc dự án

```txt
PTITCONNECT_APP/
  mobile_app/      # Flutter client
  backend/         # Django API server
  .gitignore
  readme.md
```

---

## Công nghệ sử dụng

### Frontend
- Flutter
- `http`
- `shared_preferences`
- `url_launcher`
- `webview_flutter`

### Backend
- Django
- Django REST Framework
- PostgreSQL
- `django-cors-headers`
- `djangorestframework-simplejwt`

---

## Yêu cầu môi trường

- Flutter stable
- Python 3.11+
- PostgreSQL 14+

---

## Hướng dẫn chạy nhanh

## 1) Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install django djangorestframework django-cors-headers djangorestframework-simplejwt pillow psycopg[binary] python-dotenv requests beautifulsoup4
```

Tạo file `.env` (tham khảo `.env.example`):

```env
USE_POSTGRES=true
POSTGRES_DB=ptit_connect_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=123456
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
```

Chạy migration + server:

```bash
python manage.py migrate
python manage.py runserver
```

## 2) Mobile app

```bash
cd mobile_app
flutter pub get
flutter run -d chrome
```

---

## Seed dữ liệu cộng đồng

Để tạo dữ liệu test (30-50 bài):

```bash
cd backend
source venv/bin/activate
python manage.py seed_community --count 40
```

---

## API nổi bật

### Users
- `POST /api/users/register/`
- `POST /api/users/login/`
- `GET/PATCH /api/users/profile/`
- `GET /api/users/search/`

### Community
- `GET /api/community/auto-feed/`
- `GET/POST /api/community/posts/`
- `GET /api/community/posts/<id>/`
- `POST /api/community/posts/<id>/comments/`
- `POST /api/community/posts/<id>/react/`
- `POST /api/community/posts/<id>/save/`

### Chat
- `GET /api/chat/`
- `POST /api/chat/open/`
- `GET/POST /api/chat/<id>/messages/`

### Notifications
- `GET/POST /api/notifications/`
- `POST /api/notifications/read-all/`
- `POST /api/notifications/<id>/read/`

### Friends
- `GET /api/users/friends/`
- `GET /api/users/friends/requests/inbox/`
- `POST /api/users/friends/requests/send/`
- `POST /api/users/friends/requests/<id>/decide/`

---

## Ghi chú phát triển

- Web có thể gặp CORS nếu dùng custom headers; app hiện dùng `username` qua query/body để tránh preflight lỗi.
- Luồng Microsoft OAuth cần tenant/app registration hợp lệ để chạy production.
- Mock login đang bật để dev nhanh UI/flow khi chưa có quyền Azure đầy đủ.

---

## Tác giả
Mai Phượng
Repo: [ITIS-mphuong169/PTITCONNECT-APP](https://github.com/ITIS-mphuong169/PTITCONNECT-APP)

