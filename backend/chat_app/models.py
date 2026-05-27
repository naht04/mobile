from django.db import models
from django.contrib.auth.models import User


class Conversation(models.Model):
    """A direct or group chat room."""
    title = models.CharField(max_length=255, blank=True)
    is_group = models.BooleanField(default=False)
    created_by = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="created_conversations",
    )
    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="owned_conversations",
        null=True,
        blank=True,
    )
    require_approval_to_join = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title or f"Conversation #{self.id}"


class ConversationParticipant(models.Model):
    """Membership row that stores each user's role and join status in a conversation."""
    ROLE_CHOICES = [
        ("owner", "Owner"),
        ("admin", "Admin"),
        ("member", "Member"),
    ]
    STATUS_CHOICES = [
        ("active", "Active"),
        ("pending", "Pending"),
        ("left", "Left"),
        ("removed", "Removed"),
    ]

    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="participants",
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="chat_participations",
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="member")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="active")
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("conversation", "user")


class Message(models.Model):
    """A chat item: text, image, file, or call preview in one conversation."""
    MESSAGE_TYPE_CHOICES = [
        ("text", "Text"),
        ("image", "Image"),
        ("file", "File"),
        ("call", "Call"),
    ]

    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="messages_sent",
    )
    message_type = models.CharField(max_length=20, choices=MESSAGE_TYPE_CHOICES, default="text")
    content = models.TextField(blank=True)
    file = models.FileField(upload_to="chat_files/", blank=True, null=True)
    file_name = models.CharField(max_length=255, blank=True)
    file_size = models.PositiveIntegerField(default=0)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]


class CallLog(models.Model):
    """Lifecycle record for audio/video calls started from chat."""
    CALL_TYPE_CHOICES = [("audio", "Audio"), ("video", "Video")]
    STATUS_CHOICES = [
        ("ringing", "Ringing"),
        ("answered", "Answered"),
        ("rejected", "Rejected"),
        ("busy", "Busy"),
        ("missed", "Missed"),
        ("ended", "Ended"),
        ("canceled", "Canceled"),
    ]

    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="call_logs",
    )
    caller = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="calls_started",
    )
    callee = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="calls_received",
        null=True,
        blank=True,
    )
    call_type = models.CharField(max_length=20, choices=CALL_TYPE_CHOICES, default="video")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="ringing")
    started_at = models.DateTimeField(auto_now_add=True)
    answered_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    duration_seconds = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["-started_at"]
