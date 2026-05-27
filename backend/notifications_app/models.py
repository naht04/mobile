from django.db import models
from django.contrib.auth.models import User


class Notification(models.Model):
    """User-facing notification used by the notification screen and realtime badges."""
    TYPE_CHOICES = [
        ("message", "Message"),
        ("friend_request", "Friend Request"),
        ("friend_accept", "Friend Accept"),
        ("post_new", "Post New"),
        ("post_like", "Post Like"),
        ("post_comment", "Post Comment"),
        ("group", "Group"),
        ("system", "System"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    title = models.CharField(max_length=255)
    content = models.TextField()
    notification_type = models.CharField(max_length=30, choices=TYPE_CHOICES, default="system")
    target_username = models.CharField(max_length=150, blank=True)
    conversation_id = models.PositiveIntegerField(null=True, blank=True)
    post_id = models.PositiveIntegerField(null=True, blank=True)
    group_id = models.PositiveIntegerField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user.username} - {self.title}"
