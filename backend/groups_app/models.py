from django.db import models
from django.contrib.auth.models import User


class StudyGroup(models.Model):
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="owned_groups")
    title = models.CharField(max_length=255)
    subject = models.CharField(max_length=100)
    category = models.CharField(max_length=100, blank=True)
    description = models.TextField()
    avatar_url = models.TextField(blank=True)
    max_members = models.IntegerField(default=5)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


class GroupMember(models.Model):
    group = models.ForeignKey(
        StudyGroup, on_delete=models.CASCADE, related_name="memberships"
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="group_memberships")
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["group", "user"], name="unique_group_member")
        ]

    def __str__(self):
        return f"{self.user.username} in {self.group.title}"


class JoinRequest(models.Model):
    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("approved", "Approved"),
        ("rejected", "Rejected"),
    ]

    group = models.ForeignKey(
        StudyGroup, on_delete=models.CASCADE, related_name="join_requests"
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="join_requests")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["group", "user"], name="unique_join_request")
        ]

    def __str__(self):
        return f"{self.user.username} -> {self.group.title} ({self.status})"
