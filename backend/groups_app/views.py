from django.db.models import Q
from django.contrib.auth.models import User
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user

from .models import GroupMember, JoinRequest, StudyGroup
from .serializers import JoinRequestSerializer, StudyGroupSerializer
from community.models import Post
from community.serializers import PostSerializer


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def groups_api(request):
    if request.method == "GET":
        actor = resolve_demo_user(request)
        qs = StudyGroup.objects.all()
        subject = request.query_params.get("subject", "").strip()
        category = request.query_params.get("category", "").strip()
        q = request.query_params.get("q", "").strip()
        if subject:
            qs = qs.filter(subject__iexact=subject)
        if category:
            qs = qs.filter(category__iexact=category)
        if q:
            qs = qs.filter(Q(title__icontains=q) | Q(description__icontains=q))
        return Response(
            StudyGroupSerializer(qs[:100], many=True, context={"user": actor}).data
        )

    actor = resolve_demo_user(request)
    title = (request.data.get("title") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    category = (request.data.get("category") or "").strip()
    description = (request.data.get("description") or "").strip()
    avatar_url = (request.data.get("avatar_url") or "").strip()
    max_members = int(request.data.get("max_members") or 5)
    if not title or not subject or not description:
        return Response(
            {"detail": "title, subject, description required"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    g = StudyGroup.objects.create(
        owner=actor,
        title=title,
        subject=subject,
        category=category,
        description=description,
        avatar_url=avatar_url,
        max_members=max(2, min(max_members, 50)),
    )
    GroupMember.objects.get_or_create(group=g, user=actor)
    return Response(StudyGroupSerializer(g).data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([permissions.IsAuthenticated])
def group_detail_api(request, pk):
    g = get_object_or_404(StudyGroup, pk=pk)
    if request.method == "GET":
        actor = resolve_demo_user(request)
        return Response(StudyGroupSerializer(g, context={"user": actor}).data)

    actor = resolve_demo_user(request)
    if g.owner_id != actor.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

    if request.method == "PATCH":
        g.title = (request.data.get("title") or g.title).strip()
        g.subject = (request.data.get("subject") or g.subject).strip()
        g.category = (request.data.get("category") or g.category).strip()
        g.description = (request.data.get("description") or g.description).strip()
        g.avatar_url = (request.data.get("avatar_url") or g.avatar_url).strip()
        max_members = request.data.get("max_members")
        if max_members is not None:
            g.max_members = max(2, min(int(max_members), 50))
        g.save()
        return Response(StudyGroupSerializer(g).data)

    g.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def group_join_api(request, pk):
    group = get_object_or_404(StudyGroup, pk=pk)
    actor = resolve_demo_user(request)
    if group.owner_id == actor.id:
        return Response({"detail": "owner is already member"}, status=status.HTTP_400_BAD_REQUEST)
    if GroupMember.objects.filter(group=group, user=actor).exists():
        return Response({"detail": "already member"}, status=status.HTTP_400_BAD_REQUEST)
    jr, created = JoinRequest.objects.get_or_create(group=group, user=actor, defaults={"status": "pending"})
    if not created and jr.status != "pending":
        jr.status = "pending"
        jr.save()
    return Response(JoinRequestSerializer(jr).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def group_members_api(request, pk):
    group = get_object_or_404(StudyGroup, pk=pk)
    users = (
        User.objects.filter(group_memberships__group=group)
        .distinct()
        .order_by("username")
    )
    data = [{"username": u.username, "is_owner": group.owner_id == u.id} for u in users]
    return Response({"results": data})


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def group_posts_api(request, pk):
    group = get_object_or_404(StudyGroup, pk=pk)
    actor = resolve_demo_user(request)
    posts = Post.objects.filter(
        Q(topic__icontains=group.title)
        | Q(topic__icontains=group.subject)
        | Q(content__icontains=f"#{group.title}")
    ).order_by("-created_at")[:30]
    return Response(PostSerializer(posts, many=True, context={"request": request, "user": actor}).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def group_invite_api(request, pk):
    group = get_object_or_404(StudyGroup, pk=pk)
    actor = resolve_demo_user(request)
    if group.owner_id != actor.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

    target_username = (request.data.get("target_username") or "").strip().lower()
    if not target_username:
        return Response({"detail": "target_username required"}, status=status.HTTP_400_BAD_REQUEST)
    if target_username == actor.username:
        return Response({"detail": "cannot invite yourself"}, status=status.HTTP_400_BAD_REQUEST)

    target_user = User.objects.filter(username=target_username).first()
    if target_user is None:
        return Response({"detail": "user not found"}, status=status.HTTP_404_NOT_FOUND)
    if GroupMember.objects.filter(group=group, user=target_user).exists():
        return Response({"detail": "already member"}, status=status.HTTP_400_BAD_REQUEST)

    invite, created = JoinRequest.objects.get_or_create(
        group=group,
        user=target_user,
        defaults={"status": "pending"},
    )
    if not created and invite.status != "pending":
        invite.status = "pending"
        invite.save(update_fields=["status"])

    return Response(JoinRequestSerializer(invite).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def group_join_requests_api(request, pk):
    group = get_object_or_404(StudyGroup, pk=pk)
    actor = resolve_demo_user(request)
    if group.owner_id != actor.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)
    pending = group.join_requests.filter(status="pending")
    return Response(JoinRequestSerializer(pending, many=True).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def group_join_decide_api(request, pk, request_id):
    group = get_object_or_404(StudyGroup, pk=pk)
    actor = resolve_demo_user(request)
    if group.owner_id != actor.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)
    jr = get_object_or_404(JoinRequest, id=request_id, group=group)
    action = (request.data.get("action") or "").lower()
    if action == "approve":
        if group.memberships.count() >= group.max_members:
            return Response({"detail": "group full"}, status=status.HTTP_400_BAD_REQUEST)
        jr.status = "approved"
        jr.save()
        GroupMember.objects.get_or_create(group=group, user=jr.user)
    elif action == "reject":
        jr.status = "rejected"
        jr.save()
    else:
        return Response({"detail": "action must be approve or reject"}, status=status.HTTP_400_BAD_REQUEST)
    return Response(JoinRequestSerializer(jr).data)
