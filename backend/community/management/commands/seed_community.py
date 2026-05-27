import random

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

from community.models import Comment, Post, PostLike, SavedPost


class Command(BaseCommand):
    help = "Seed sample community data (posts/comments/likes/saves)."

    def add_arguments(self, parser):
        parser.add_argument("--count", type=int, default=40)

    def handle(self, *args, **options):
        count = max(1, min(options["count"], 100))

        users = self._ensure_users()
        posts = self._seed_posts(users, count)
        self._seed_comments(posts, users, random.randint(count, count * 2))
        self._seed_reactions(posts, users, random.randint(count, count * 2))

        self.stdout.write(self.style.SUCCESS(f"Seeded {len(posts)} posts to database successfully."))

    def _ensure_users(self):
        names = [
            "hongnhung",
            "maiphuong",
            "ngannguyen",
            "quanbui",
            "baohoang",
            "ducanh",
            "lananh",
            "minhduc",
        ]
        users = []
        for username in names:
            user, _ = User.objects.get_or_create(
                username=username,
                defaults={
                    "email": f"{username}@stu.ptit.edu.vn",
                },
            )
            users.append(user)
        return users

    def _seed_posts(self, users, count):
        topics = ["Flutter", "Python", "AI", "Mobile", "Database", "Study Group"]
        titles = [
            "Chia sẻ tài liệu học phần",
            "Nhóm học tối nay",
            "Kinh nghiệm làm đồ án",
            "Cần review code",
            "Tài liệu ôn thi cuối kỳ",
            "Tips học hiệu quả",
        ]
        bodies = [
            "Mình tổng hợp được tài liệu khá ổn, bạn nào cần mình gửi link nhé.",
            "Ai rảnh tối nay vào nhóm học cùng mình từ 20h đến 22h.",
            "Mình đang gặp lỗi khi build app, ai từng gặp cho mình xin hướng xử lý.",
            "Bài này là checklist những thứ cần có trước khi demo đồ án môn Mobile.",
            "Nếu bạn cần source mẫu, mình có thể gửi bản rút gọn để tham khảo.",
        ]

        posts = []
        for _ in range(count):
            post = Post.objects.create(
                author=random.choice(users),
                title=f"{random.choice(titles)} #{random.randint(10, 999)}",
                content=random.choice(bodies),
                topic=random.choice(topics),
            )
            posts.append(post)
        return posts

    def _seed_comments(self, posts, users, count):
        comments = [
            "Bài viết hữu ích quá, cảm ơn bạn.",
            "Cho mình xin thêm tài liệu với nhé.",
            "Mình cũng đang làm phần này, cùng trao đổi nhé.",
            "Cách này hay, mình sẽ thử ngay.",
            "Bạn có thể chia sẻ chi tiết hơn không?",
        ]
        for _ in range(count):
            Comment.objects.create(
                post=random.choice(posts),
                author=random.choice(users),
                content=random.choice(comments),
            )

    def _seed_reactions(self, posts, users, count):
        for _ in range(count):
            post = random.choice(posts)
            user = random.choice(users)
            PostLike.objects.get_or_create(post=post, user=user)
            if random.choice([True, False]):
                SavedPost.objects.get_or_create(post=post, user=user)
