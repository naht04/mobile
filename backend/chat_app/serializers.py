from rest_framework import serializers

from users.models import Profile
from users.serializers import ProfileSerializer

from .models import Conversation, ConversationParticipant, Message, CallLog


def _profile_for_user(user):
    """Read an already-prefetched profile or create the missing one lazily."""
    try:
        return user.profile
    except Profile.DoesNotExist:
        return Profile.objects.create(user=user)


class MessageSerializer(serializers.ModelSerializer):
    """Serialize chat messages for the mobile chat detail screen."""
    sender_name = serializers.CharField(source="sender.username", read_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            "id",
            "sender_name",
            "message_type",
            "content",
            "file_name",
            "file_size",
            "file_url",
            "is_read",
            "created_at",
        ]

    def get_file_url(self, obj):
        request = self.context.get("request")
        if not getattr(obj, "file", None):
            return ""
        if request:
            return request.build_absolute_uri(obj.file.url)
        return obj.file.url


class ConversationParticipantSerializer(serializers.ModelSerializer):
    """Serialize group/direct chat membership with nested profile data."""
    profile = serializers.SerializerMethodField()

    class Meta:
        model = ConversationParticipant
        fields = [
            "id",
            "user_id",
            "role",
            "status",
            "joined_at",
            "profile",
        ]

    def get_profile(self, obj):
        request = self.context.get("request")
        profile = _profile_for_user(obj.user)
        return ProfileSerializer(profile, context={"request": request}).data


class ConversationSerializer(serializers.ModelSerializer):
    """Serialize conversation list/detail summary used by the mobile message inbox."""
    display_name = serializers.SerializerMethodField()
    participant_count = serializers.SerializerMethodField()
    member_profiles = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    matched_message = serializers.SerializerMethodField()
    matched_count = serializers.SerializerMethodField()
    last_message_time = serializers.SerializerMethodField()
    my_role = serializers.SerializerMethodField()
    owner_username = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            "id",
            "title",
            "is_group",
            "display_name",
            "participant_count",
            "member_profiles",
            "last_message",
            "matched_message",
            "matched_count",
            "unread_count",
            "created_at",
            "updated_at",
            "last_message_time",
            "my_role",
            "owner_username",
            "require_approval_to_join",
        ]

    def _participants(self, obj):
        prefetched = getattr(obj, "_prefetched_objects_cache", {}).get("participants")
        if prefetched is not None:
            return [
                item for item in prefetched
                if item.status not in ["left", "removed"]
            ]
        return obj.participants.select_related("user").exclude(
            status__in=["left", "removed"]
        )

    def _peer_user(self, obj):
        me = self.context.get("user")
        if not me:
            return None

        for item in self._participants(obj):
            if item.user_id != me.id:
                return item.user
        return None

    def get_display_name(self, obj):
        if obj.is_group:
            if (obj.title or "").strip():
                return obj.title.strip()

            names = []
            for item in self._participants(obj)[:3]:
                profile = _profile_for_user(item.user)
                names.append(profile.full_name or item.user.username)

            return ", ".join(names) if names else "Nhóm chat"

        peer = self._peer_user(obj)
        if not peer:
            return "Cuộc trò chuyện"

        profile = _profile_for_user(peer)
        return profile.full_name or peer.username

    def get_participant_count(self, obj):
        participants = self._participants(obj)
        if isinstance(participants, list):
            return len(participants)
        return participants.count()

    def get_member_profiles(self, obj):
        request = self.context.get("request")
        result = []

        for item in self._participants(obj)[:8]:
            profile = _profile_for_user(item.user)
            result.append(
                ProfileSerializer(profile, context={"request": request}).data
            )

        return result

    def get_last_message(self, obj):
        annotated_type = getattr(obj, "last_message_type", None)
        if annotated_type is not None:
            sender_name = getattr(obj, "last_message_sender", "") or ""
            file_name = getattr(obj, "last_message_file_name", "") or ""
            content = getattr(obj, "last_message_content", "") or ""

            if annotated_type == "file":
                return f"{sender_name} Ä‘Ã£ gá»­i 1 file"

            if annotated_type == "image":
                return f"{sender_name} Ä‘Ã£ gá»­i 1 áº£nh"

            if annotated_type == "call":
                return (content or "Cuá»™c gá»i")[:200]

            return (content or file_name or "")[:200]

        last = obj.messages.order_by("-created_at").first()
        if not last:
            return ""

        sender_name = last.sender.username

        if last.message_type == "file":
            return f"{sender_name} đã gửi 1 file"

        if last.message_type == "image":
            return f"{sender_name} đã gửi 1 ảnh"

        if last.message_type == "call":
            return (last.content or "Cuộc gọi")[:200]

        return (last.content or "")[:200]

    def get_last_message_time(self, obj):
        annotated_time = getattr(obj, "last_message_created_at", None)
        if annotated_time is not None:
            return annotated_time
        last = obj.messages.order_by("-created_at").first()
        return getattr(last, "created_at", None)

    def get_matched_message(self, obj):
        query = (self.context.get("search_query") or "").strip()
        if not query:
            return ""

        msg = obj.messages.filter(content__icontains=query).order_by("-created_at").first()
        if not msg:
            return ""

        sender_name = msg.sender.username

        if msg.message_type == "file":
            return f"{sender_name} đã gửi 1 file"

        if msg.message_type == "image":
            return f"{sender_name} đã gửi 1 ảnh"

        if msg.message_type == "call":
            return (msg.content or "Cuộc gọi")[:200]

        return (msg.content or "")[:200]

    def get_matched_count(self, obj):
        query = (self.context.get("search_query") or "").strip()
        if not query:
            return 0
        annotated_count = getattr(obj, "matched_messages", None)
        if annotated_count is not None:
            return annotated_count
        return obj.messages.filter(content__icontains=query).count()

    def get_unread_count(self, obj):
        me = self.context.get("user")
        if not me:
            return 0
        annotated_count = getattr(obj, "unread_messages", None)
        if annotated_count is not None:
            return annotated_count
        return obj.messages.exclude(sender=me).filter(is_read=False).count()

    def get_my_role(self, obj):
        me = self.context.get("user")
        if not me:
            return "member"

        participant = obj.participants.filter(user=me).first()
        if not participant:
            return "member"

        return participant.role

    def get_owner_username(self, obj):
        return obj.owner.username if obj.owner else ""


class CallLogSerializer(serializers.ModelSerializer):
    """Serialize audio/video call history and current call status."""
    caller_username = serializers.CharField(source="caller.username", read_only=True)
    callee_username = serializers.CharField(source="callee.username", read_only=True, default="")
    caller_name = serializers.SerializerMethodField()
    callee_name = serializers.SerializerMethodField()

    class Meta:
        model = CallLog
        fields = [
            "id",
            "conversation",
            "caller_username",
            "callee_username",
            "caller_name",
            "callee_name",
            "call_type",
            "status",
            "started_at",
            "answered_at",
            "ended_at",
            "duration_seconds",
        ]

    def get_caller_name(self, obj):
        profile = _profile_for_user(obj.caller)
        return profile.full_name or obj.caller.username

    def get_callee_name(self, obj):
        if not obj.callee:
            return ""
        profile = _profile_for_user(obj.callee)
        return profile.full_name or obj.callee.username
