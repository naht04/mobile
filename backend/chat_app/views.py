from django.contrib.auth.models import User
from django.db.models import Count, Max, OuterRef, Q, Subquery
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user
from core.permissions import IsAuthenticatedOrDemoUser
from notifications_app.realtime import notify_conversation, notify_user
from notifications_app.services import create_notification
from users.models import FriendRequest, Profile

from django.utils import timezone
from .models import Conversation, ConversationParticipant, Message, CallLog
from .serializers import ConversationParticipantSerializer, ConversationSerializer, MessageSerializer, CallLogSerializer


def _are_friends(user_a, user_b):
    """Return True when two users have an accepted friend relationship."""
    return FriendRequest.objects.filter(status="accepted").filter(
        Q(from_user=user_a, to_user=user_b) | Q(from_user=user_b, to_user=user_a)
    ).exists()


def _active_participant(conversation, user):
    """Find the current participant row that can still see the conversation."""
    return conversation.participants.filter(
        user=user,
        status__in=["active", "pending"],
    ).first()


def _is_active_member(conversation, user):
    """Check whether a user can send/read messages in this conversation."""
    return conversation.participants.filter(user=user, status="active").exists()


def _can_manage_members(participant):
    """Owners and admins are the only roles allowed to change group members."""
    return participant and participant.role in ["owner", "admin"] and participant.status == "active"


def _normalize_usernames(usernames):
    """Normalize user input from the client into unique lowercase usernames."""
    normalized = []
    seen = set()
    for raw in usernames or []:
        username = str(raw or "").strip().lower()
        if not username or username in seen:
            continue
        seen.add(username)
        normalized.append(username)
    return normalized


def _conversation_queryset_for_user(user):
    """Base queryset for conversations visible to a user, with profile prefetching."""
    return (
        Conversation.objects.filter(
            participants__user=user,
            participants__status__in=["active", "pending"],
            is_active=True,
        )
        .prefetch_related(
            "participants__user__profile",
        )
        .distinct()
    )


def _with_conversation_summary(qs, user, search_query=""):
    """Attach list-screen summary fields without per-conversation message queries."""
    latest_message = (
        Message.objects.filter(conversation=OuterRef("pk"))
        .select_related("sender")
        .order_by("-created_at", "-id")
    )
    annotations = {
        "latest": Max("messages__created_at"),
        "last_message_content": Subquery(latest_message.values("content")[:1]),
        "last_message_type": Subquery(latest_message.values("message_type")[:1]),
        "last_message_file_name": Subquery(latest_message.values("file_name")[:1]),
        "last_message_sender": Subquery(latest_message.values("sender__username")[:1]),
        "last_message_created_at": Subquery(latest_message.values("created_at")[:1]),
        "unread_messages": Count(
            "messages",
            filter=Q(messages__is_read=False) & ~Q(messages__sender=user),
            distinct=True,
        ),
    }
    if search_query:
        annotations["matched_messages"] = Count(
            "messages",
            filter=Q(messages__content__icontains=search_query),
            distinct=True,
        )

    return qs.annotate(**annotations)


def _get_or_create_direct_conversation(user_a, user_b):
    """Reuse an existing direct chat or create a two-member conversation."""
    if user_a.id == user_b.id:
        return None

    conv = (
        Conversation.objects.filter(is_group=False, is_active=True)
        .filter(participants__user=user_a, participants__status="active")
        .filter(participants__user=user_b, participants__status="active")
        .annotate(member_count=Count("participants", distinct=True))
        .filter(member_count=2)
        .first()
    )
    if conv:
        return conv

    conv = Conversation.objects.create(
        title="",
        is_group=False,
        created_by=user_a,
        owner=None,
        is_active=True,
    )
    ConversationParticipant.objects.create(
        conversation=conv,
        user=user_a,
        role="member",
        status="active",
    )
    ConversationParticipant.objects.create(
        conversation=conv,
        user=user_b,
        role="member",
        status="active",
    )
    return conv


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversations_api(request):
    """GET /api/chat/ - list chat conversations and optional message/member search."""
    me = resolve_demo_user(request)
    q = (request.query_params.get("q") or "").strip()

    qs = _conversation_queryset_for_user(me)

    if q:
        qs = (
            qs.filter(
                Q(title__icontains=q)
                | Q(participants__user__profile__full_name__icontains=q)
                | Q(participants__user__profile__student_id__icontains=q)
                | Q(participants__user__username__icontains=q)
                | Q(messages__content__icontains=q)
            )
            .distinct()
        )

    qs = _with_conversation_summary(qs, me, q).order_by("-latest", "-updated_at")

    serializer = ConversationSerializer(
        qs[:100],
        many=True,
        context={
            "request": request,
            "user": me,
            "search_query": q,
        },
    )
    return Response(serializer.data)


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_open_api(request):
    """POST /api/chat/open/ - open or create a direct chat with an accepted friend."""
    me = resolve_demo_user(request)
    peer_username = (
        request.data.get("peer_username")
        or request.data.get("target_username")
        or ""
    ).strip().lower()

    if not peer_username:
        return Response({"detail": "peer_username required"}, status=400)

    peer = User.objects.filter(username=peer_username).first()
    if peer is None:
        return Response({"detail": "user not found"}, status=404)

    if not _are_friends(me, peer):
        return Response({"detail": "only friends can chat"}, status=400)

    conv = _get_or_create_direct_conversation(me, peer)
    if not conv:
        return Response({"detail": "invalid peer"}, status=400)

    serializer = ConversationSerializer(
        conv,
        context={"request": request, "user": me},
    )
    return Response(serializer.data, status=201)


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_create_group_api(request):
    """POST /api/chat/create-group/ - create a group chat from selected friends."""
    me = resolve_demo_user(request)

    title = (request.data.get("title") or "").strip()
    usernames = _normalize_usernames(request.data.get("usernames"))

    usernames = [username for username in usernames if username != me.username.lower()]

    if len(usernames) < 2:
        return Response({"detail": "phải chọn ít nhất 2 thành viên"}, status=400)

    users = list(User.objects.filter(username__in=usernames))
    found_usernames = {user.username.lower() for user in users}

    missing = [username for username in usernames if username not in found_usernames]
    if missing:
        return Response(
            {"detail": f"không tìm thấy người dùng: {', '.join(missing)}"},
            status=400,
        )

    for user in users:
        if not _are_friends(me, user):
            return Response(
                {"detail": f"{user.username} chưa là bạn bè"},
                status=400,
            )

    conv = Conversation.objects.create(
        title=title,
        is_group=True,
        created_by=me,
        owner=me,
        is_active=True,
    )

    ConversationParticipant.objects.create(
        conversation=conv,
        user=me,
        role="owner",
        status="active",
    )

    for user in users:
        ConversationParticipant.objects.create(
            conversation=conv,
            user=user,
            role="member",
            status="active",
        )

    group_name = title or "Nhóm chat mới"

    for user in users:
        notify_user(
            user.username,
            {"type": "conversation_refresh", "conversation_id": conv.id},
        )
        create_notification(
            user=user,
            title="Bạn được thêm vào nhóm chat",
            content=f"{me.username} đã thêm bạn vào nhóm '{group_name}'",
            notification_type="message",
            target_username=me.username,
            conversation_id=conv.id,
        )

    serializer = ConversationSerializer(
        conv,
        context={"request": request, "user": me},
    )
    return Response(serializer.data, status=201)


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_members_api(request, pk):
    """GET /api/chat/{id}/members/ - return active/pending group members."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_active=True)

    if not _active_participant(conv, me):
        return Response({"detail": "forbidden"}, status=403)

    participants = conv.participants.select_related("user").exclude(
        status__in=["left", "removed"]
    )
    serializer = ConversationParticipantSerializer(
        participants,
        many=True,
        context={"request": request},
    )
    return Response(serializer.data)


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_add_members_api(request, pk):
    """POST /api/chat/{id}/members/add/ - add friends to an existing group chat."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_group=True, is_active=True)

    me_participant = _active_participant(conv, me)
    if not _can_manage_members(me_participant):
        return Response({"detail": "Bạn không có quyền thêm thành viên"}, status=403)

    usernames = _normalize_usernames(request.data.get("usernames"))
    if not usernames:
        return Response({"detail": "usernames must be a non-empty list"}, status=400)

    users = list(User.objects.filter(username__in=usernames))
    found_usernames = {u.username.lower() for u in users}
    missing = [u for u in usernames if u not in found_usernames]
    if missing:
        return Response(
            {"detail": f"không tìm thấy người dùng: {', '.join(missing)}"},
            status=400,
        )

    for user in users:
        if user == me:
            continue
        if not _are_friends(me, user):
            return Response(
                {"detail": f"{user.username} chưa là bạn bè"},
                status=400,
            )

    for user in users:
        participant, created = ConversationParticipant.objects.get_or_create(
            conversation=conv,
            user=user,
            defaults={
                "role": "member",
                "status": "pending" if conv.require_approval_to_join else "active",
            },
        )
        if not created and participant.status in ["left", "removed"]:
            participant.role = "member"
            participant.status = "pending" if conv.require_approval_to_join else "active"
            participant.save()

        notify_user(
            user.username,
            {"type": "conversation_refresh", "conversation_id": conv.id},
        )
        create_notification(
            user=user,
            title="Bạn được thêm vào nhóm chat",
            content=f"{me.username} đã thêm bạn vào nhóm '{conv.title or 'Nhóm chat'}'",
            notification_type="message",
            target_username=me.username,
            conversation_id=conv.id,
        )

    return Response({"detail": "Đã thêm thành viên"})


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_leave_api(request, pk):
    """POST /api/chat/{id}/leave/ - mark the current user as left."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_active=True)

    participant = _active_participant(conv, me)
    if not participant:
        return Response({"detail": "forbidden"}, status=403)

    if conv.is_group and participant.role == "owner":
        active_count = conv.participants.filter(status="active").count()
        if active_count > 1:
            return Response(
                {"detail": "Trưởng nhóm phải chuyển quyền trước khi rời nhóm"},
                status=400,
            )

    participant.status = "left"
    participant.save(update_fields=["status"])

    notify_user(
        me.username,
        {"type": "conversation_refresh", "conversation_id": conv.id},
    )

    return Response({"detail": "Đã rời nhóm"})


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_transfer_owner_api(request, pk):
    """POST /api/chat/{id}/transfer-owner/ - transfer group owner role."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_group=True, is_active=True)

    me_participant = conv.participants.filter(
        user=me,
        role="owner",
        status="active",
    ).first()
    if not me_participant:
        return Response({"detail": "Chỉ trưởng nhóm mới được chuyển quyền"}, status=403)

    username = (request.data.get("username") or "").strip()
    target_user = User.objects.filter(username=username).first()
    if not target_user:
        return Response({"detail": "Không tìm thấy người dùng"}, status=404)

    target_participant = conv.participants.filter(
        user=target_user,
        status="active",
    ).first()
    if not target_participant:
        return Response({"detail": "Người dùng không ở trong nhóm"}, status=400)

    me_participant.role = "admin"
    me_participant.save(update_fields=["role"])

    target_participant.role = "owner"
    target_participant.save(update_fields=["role"])

    conv.owner = target_user
    conv.save(update_fields=["owner"])

    return Response({"detail": "Đã chuyển quyền trưởng nhóm"})


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_approval_setting_api(request, pk):
    """POST /api/chat/{id}/approval-setting/ - toggle member approval mode."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_group=True, is_active=True)

    participant = _active_participant(conv, me)
    if not _can_manage_members(participant):
        return Response({"detail": "forbidden"}, status=403)

    enabled = request.data.get("enabled")
    conv.require_approval_to_join = bool(enabled)
    conv.save(update_fields=["require_approval_to_join"])

    return Response({
        "detail": "Đã cập nhật chế độ duyệt thành viên",
        "require_approval_to_join": conv.require_approval_to_join,
    })


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_dissolve_api(request, pk):
    """POST /api/chat/{id}/dissolve/ - owner-only group deletion."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_group=True, is_active=True)

    participant = conv.participants.filter(
        user=me,
        role="owner",
        status="active",
    ).first()
    if not participant:
        return Response({"detail": "Chỉ trưởng nhóm mới được giải tán nhóm"}, status=403)

    conv.delete()
    return Response({"detail": "Đã giải tán nhóm"})


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def messages_api(request, pk):
    """GET/POST /api/chat/{id}/messages/ - read messages or send text/file content."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_active=True)

    if not _is_active_member(conv, me):
        return Response({"detail": "forbidden"}, status=403)

    if request.method == "GET":
        conv.messages.exclude(sender=me).filter(is_read=False).update(is_read=True)

        q = (request.query_params.get("q") or "").strip()
        msgs = conv.messages.all()
        if q:
            msgs = msgs.filter(content__icontains=q)

        return Response(
            MessageSerializer(msgs, many=True, context={"request": request}).data
        )

    uploaded_file = request.FILES.get("file")
    content = (request.data.get("content") or "").strip()
    message_type = (request.data.get("message_type") or "text").strip()

    if not content and not uploaded_file:
        return Response({"detail": "content or file required"}, status=400)

    msg = Message(
        conversation=conv,
        sender=me,
        content=content,
        message_type=message_type or "text",
    )

    if uploaded_file:
        msg.file = uploaded_file
        msg.file_name = uploaded_file.name
        msg.file_size = uploaded_file.size

        if uploaded_file.content_type and uploaded_file.content_type.startswith("image/"):
            msg.message_type = "image"
        elif msg.message_type != "image":
            msg.message_type = "file"

    msg.save()
    conv.save(update_fields=["updated_at"])

    payload = MessageSerializer(msg, context={"request": request}).data
    notify_conversation(conv.id, {"type": "message", "data": payload})

    participants = conv.participants.exclude(user=me).filter(status="active").select_related("user")
    for item in participants:
        notify_user(
            item.user.username,
            {"type": "conversation_refresh", "conversation_id": conv.id},
        )
        create_notification(
            user=item.user,
            title="Tin nhắn nhóm mới" if conv.is_group else "Tin nhắn mới",
            content=f"{me.username}: {(content or msg.file_name or 'Đã gửi tệp')[:80]}",
            notification_type="message",
            target_username=me.username,
            conversation_id=conv.id,
        )

    notify_user(
        me.username,
        {"type": "conversation_refresh", "conversation_id": conv.id},
    )

    return Response(payload, status=201)


@api_view(["DELETE"])
@permission_classes([IsAuthenticatedOrDemoUser])
def conversation_delete_api(request, pk):
    """DELETE /api/chat/{id}/delete/ - delete a direct conversation for both users."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_active=True)

    participant = _active_participant(conv, me)
    if not participant:
        return Response({"detail": "forbidden"}, status=403)

    if conv.is_group:
        return Response(
            {"detail": "Vui lòng dùng rời nhóm hoặc giải tán nhóm"},
            status=400,
        )

    conv.delete()
    return Response(status=204)

@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def call_invite_api(request, pk):
    """POST /api/chat/{id}/call/invite/ - create a call log and notify callees."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_active=True)

    if not _is_active_member(conv, me):
        return Response({"detail": "forbidden"}, status=403)

    call_type = (request.data.get("call_type") or "video").strip()
    if call_type not in ["audio", "video"]:
        return Response({"detail": "invalid call type"}, status=400)

    participants = list(
        conv.participants.exclude(user=me).filter(status="active").select_related("user")
    )
    callee = participants[0].user if (not conv.is_group and participants) else None
    caller_profile, _ = Profile.objects.get_or_create(user=me)
    caller_name = (caller_profile.full_name or "").strip() or me.username

    call_log = CallLog.objects.create(
        conversation=conv,
        caller=me,
        callee=callee,
        call_type=call_type,
        status="ringing",
    )

    for item in participants:
        notify_user(
            item.user.username,
            {
                "type": "incoming_call",
                "conversation_id": conv.id,
                "call_log_id": call_log.id,
                "call_type": call_type,
                "caller_username": me.username,
                "caller_name": caller_name,
                "conversation_name": conv.title or "",
                "is_group": conv.is_group,
            },
        )

    Message.objects.create(
        conversation=conv,
        sender=me,
        message_type="call",
        content="Đang gọi video..." if call_type == "video" else "Đang gọi thoại...",
    )
    conv.save(update_fields=["updated_at"])

    return Response(CallLogSerializer(call_log).data, status=201)


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def call_update_status_api(request, pk, call_log_id):
    """POST /api/chat/{id}/call-logs/{log_id}/status/ - update call lifecycle state."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_active=True)
    call_log = get_object_or_404(CallLog, pk=call_log_id, conversation=conv)

    new_status = (request.data.get("status") or "").strip()
    if new_status not in ["answered", "rejected", "busy", "missed", "ended", "canceled"]:
        return Response({"detail": "invalid status"}, status=400)

    call_log.status = new_status

    if new_status == "answered":
        call_log.answered_at = timezone.now()

    if new_status in ["ended", "missed", "rejected", "busy", "canceled"]:
        call_log.ended_at = timezone.now()
        if call_log.answered_at:
            call_log.duration_seconds = max(
                0,
                int((call_log.ended_at - call_log.answered_at).total_seconds()),
            )

    call_log.save()

    preview_map = {
        "answered": "Cuộc gọi đã kết nối",
        "rejected": "Cuộc gọi bị từ chối",
        "busy": "Máy bận",
        "missed": "Cuộc gọi nhỡ",
        "ended": "Cuộc gọi đã kết thúc",
        "canceled": "Cuộc gọi đã bị hủy",
    }

    Message.objects.create(
        conversation=conv,
        sender=me,
        message_type="call",
        content=preview_map.get(new_status, "Cuộc gọi"),
    )
    conv.save(update_fields=["updated_at"])

    for item in conv.participants.exclude(user=me).filter(status="active").select_related("user"):
        notify_user(
            item.user.username,
            {
                "type": "call_status",
                "conversation_id": conv.id,
                "call_log_id": call_log.id,
                "status": new_status,
                "call_type": call_log.call_type,
            },
        )

    return Response(CallLogSerializer(call_log).data)


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def call_history_api(request, pk):
    """GET /api/chat/{id}/call-logs/ - return recent call history for a conversation."""
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk, is_active=True)

    if not _is_active_member(conv, me):
        return Response({"detail": "forbidden"}, status=403)

    logs = conv.call_logs.all()[:50]
    serializer = CallLogSerializer(logs, many=True)
    return Response(serializer.data)
