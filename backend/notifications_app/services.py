from notifications_app.models import Notification
from notifications_app.realtime import notify_user
from notifications_app.serializers import NotificationSerializer


def create_notification(*, user, title, content, notification_type="system", target_username="", conversation_id=None, post_id=None, group_id=None):
    """Persist a notification and push the serialized payload over the user socket."""
    notification = Notification.objects.create(
        user=user,
        title=title,
        content=content,
        notification_type=notification_type,
        target_username=target_username or "",
        conversation_id=conversation_id,
        post_id=post_id,
        group_id=group_id,
    )
    notify_user(user.username, {"type": "notification", "data": NotificationSerializer(notification).data})
    return notification
