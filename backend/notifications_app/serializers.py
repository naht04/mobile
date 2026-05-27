from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    """Serialize notification payloads for REST responses and realtime pushes."""
    class Meta:
        model = Notification
        fields = [
            "id",
            "title",
            "content",
            "notification_type",
            "target_username",
            "conversation_id",
            "post_id",
            "group_id",
            "is_read",
            "created_at",
        ]
