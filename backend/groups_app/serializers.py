from rest_framework import serializers

from .models import GroupMember, JoinRequest, StudyGroup


class StudyGroupSerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source="owner.username", read_only=True)
    member_count = serializers.SerializerMethodField()
    joined = serializers.SerializerMethodField()
    join_status = serializers.SerializerMethodField()
    is_owner = serializers.SerializerMethodField()

    class Meta:
        model = StudyGroup
        fields = [
            "id",
            "owner_name",
            "title",
            "subject",
            "category",
            "description",
            "avatar_url",
            "max_members",
            "created_at",
            "member_count",
            "joined",
            "join_status",
            "is_owner",
        ]
        read_only_fields = [
            "id",
            "owner_name",
            "created_at",
            "member_count",
            "joined",
            "join_status",
            "is_owner",
        ]

    def get_member_count(self, obj):
        return obj.memberships.count()

    def get_joined(self, obj):
        user = self.context.get("user")
        if not user or not getattr(user, "is_authenticated", False):
            return False
        if obj.owner_id == user.id:
            return True
        return GroupMember.objects.filter(group=obj, user=user).exists()

    def get_join_status(self, obj):
        user = self.context.get("user")
        if not user or not getattr(user, "is_authenticated", False):
            return "none"
        if obj.owner_id == user.id:
            return "owner"
        if GroupMember.objects.filter(group=obj, user=user).exists():
            return "member"
        request = (
            JoinRequest.objects.filter(group=obj, user=user)
            .order_by("-created_at")
            .first()
        )
        if request is None:
            return "none"
        if request.status == "pending":
            return "pending"
        if request.status == "approved":
            return "member"
        return "none"

    def get_is_owner(self, obj):
        user = self.context.get("user")
        if not user or not getattr(user, "is_authenticated", False):
            return False
        return obj.owner_id == user.id


class JoinRequestSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.username", read_only=True)

    class Meta:
        model = JoinRequest
        fields = ["id", "group", "user_name", "status", "created_at"]
