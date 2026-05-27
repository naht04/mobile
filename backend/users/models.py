from django.db import models
from django.contrib.auth.models import User


class Profile(models.Model):
    """
    Extended student profile rendered in friend, chat member, search, and
    recommendation screens.

    The recommendation API uses major, class_code, and interests to calculate
    a lightweight hybrid similarity score between two students.
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    full_name = models.CharField(max_length=100, blank=True)
    student_id = models.CharField(max_length=20, blank=True)
    class_code = models.CharField(max_length=30, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    gender = models.CharField(max_length=20, blank=True)
    date_of_birth = models.CharField(max_length=30, blank=True)
    address = models.CharField(max_length=255, blank=True)
    major = models.CharField(max_length=100, blank=True)
    # Stores a list of normalized or user-entered interests, for example:
    # ["python", "ai", "football"]. JSONField works on PostgreSQL and SQLite.
    interests = models.JSONField(default=list, blank=True)
    bio = models.TextField(blank=True)
    avatar = models.ImageField(upload_to="avatars/", blank=True, null=True)

    def __str__(self):
        return self.user.username


class FriendRequest(models.Model):
    """
    Directional friend request between two accounts.

    In the project report this relationship is described as Match_User. In the
    codebase, FriendRequest is the concrete Django model that stores pending,
    accepted, and rejected connection states.
    """
    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("accepted", "Accepted"),
        ("rejected", "Rejected"),
    ]
    from_user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="friend_requests_sent"
    )
    to_user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="friend_requests_received"
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["from_user", "to_user"], name="unique_friend_request"
            )
        ]

    def __str__(self):
        return f"{self.from_user} -> {self.to_user} ({self.status})"
