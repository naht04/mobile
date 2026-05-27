from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from chat_app.models import Conversation, Message
from core.demo_auth import resolve_demo_user
from core.permissions import IsAuthenticatedOrDemoUser
from users.models import FriendRequest

from .models import Notification
from .serializers import NotificationSerializer
from .realtime import notify_user


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def notifications_api(request):
    """GET/POST /api/notifications/ - list notifications or create a system notice."""
    me = resolve_demo_user(request)
    if request.method == "GET":
        qs = Notification.objects.filter(user=me)[:100]
        return Response(NotificationSerializer(qs, many=True, context={"request": request}).data)
    title = (request.data.get("title") or "").strip()
    content = (request.data.get("content") or "").strip()
    if not title or not content:
        return Response({"detail": "title and content required"}, status=status.HTTP_400_BAD_REQUEST)
    n = Notification.objects.create(
        user=me,
        title=title,
        content=content,
        notification_type=(request.data.get("notification_type") or "system").strip() or "system",
        target_username=(request.data.get("target_username") or "").strip(),
        conversation_id=request.data.get("conversation_id") or None,
        post_id=request.data.get("post_id") or None,
        group_id=request.data.get("group_id") or None,
    )
    return Response(NotificationSerializer(n, context={"request": request}).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def notification_badges_api(request):
    """GET /api/notifications/badges/ - compact counters for bottom-nav badges."""
    me = resolve_demo_user(request)
    conversation_ids = Conversation.objects.filter(
        participants__user=me,
        participants__status__in=["active", "pending"],
        is_active=True,
    ).values("id")
    return Response(
        {
            "messages": Message.objects.filter(
                conversation_id__in=conversation_ids,
                is_read=False,
            ).exclude(sender=me).count(),
            "notifications": Notification.objects.filter(
                user=me,
                is_read=False,
            ).count(),
            "friends": FriendRequest.objects.filter(
                to_user=me,
                status="pending",
            ).count(),
        }
    )


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def notification_read_api(request, pk):
    """POST /api/notifications/{id}/read/ - mark one notification as read."""
    me = resolve_demo_user(request)
    n = get_object_or_404(Notification, pk=pk, user=me)
    n.is_read = True
    n.save(update_fields=["is_read"])
    data = NotificationSerializer(n, context={"request": request}).data
    notify_user(me.username, {"type": "notification_read", "data": data})
    return Response(data)


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def notifications_read_all_api(request):
    """POST /api/notifications/read-all/ - mark every notification as read."""
    me = resolve_demo_user(request)
    Notification.objects.filter(user=me, is_read=False).update(is_read=True)
    notify_user(me.username, {"type": "notification_read_all"})
    return Response({"ok": True})


@api_view(["DELETE"])
@permission_classes([IsAuthenticatedOrDemoUser])
def notification_delete_api(request, pk):
    """DELETE /api/notifications/{id}/delete/ - remove a notification for the user."""
    me = resolve_demo_user(request)
    n = get_object_or_404(Notification, pk=pk, user=me)
    nid = n.id
    n.delete()
    notify_user(me.username, {"type": "notification_deleted", "id": nid})
    return Response(status=status.HTTP_204_NO_CONTENT)
