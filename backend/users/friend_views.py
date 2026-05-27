import math
import re

from django.contrib.auth.models import User
from django.db.models import Q
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user
from core.permissions import IsAuthenticatedOrDemoUser
from notifications_app.services import create_notification

from .models import FriendRequest, Profile
from .serializers import FriendRequestSerializer, ProfileSerializer


MAJOR_WEIGHT = 0.5
INTERESTS_WEIGHT = 0.3
COHORT_WEIGHT = 0.2
DEFAULT_SUGGESTION_PAGE_SIZE = 20
MAX_SUGGESTION_PAGE_SIZE = 50


def _accepted_friend_users(user):
    """
    Return User objects that have an accepted friendship with the current user.

    The relation is directional in storage, so this helper normalizes both
    from_user and to_user into a plain list of peer users.
    """
    accepted = (
        FriendRequest.objects.filter(status="accepted")
        .filter(Q(from_user=user) | Q(to_user=user))
        .select_related("from_user__profile", "to_user__profile")
        .order_by("-created_at")
    )
    return [fr.to_user if fr.from_user_id == user.id else fr.from_user for fr in accepted]


def _pending_user_ids(user):
    """Collect both incoming and outgoing pending request user ids."""
    sent = FriendRequest.objects.filter(from_user=user, status="pending").values_list("to_user_id", flat=True)
    received = FriendRequest.objects.filter(to_user=user, status="pending").values_list("from_user_id", flat=True)
    return set(sent) | set(received)


def _connected_user_ids(user):
    """
    Collect accepted and pending relationship ids that must not be suggested.

    This is the exclusion layer for GET /api/users/friends/suggestions/: it
    removes existing friends and pending requests from either direction.
    """
    connected_pairs = FriendRequest.objects.filter(
        Q(from_user=user) | Q(to_user=user),
        status__in=["accepted", "pending"],
    ).values_list("from_user_id", "to_user_id")

    connected_ids = set()
    for from_user_id, to_user_id in connected_pairs:
        connected_ids.add(to_user_id if from_user_id == user.id else from_user_id)
    return connected_ids


def _normalized_text(value):
    """Normalize free-text profile fields before comparing major or interests."""
    return (value or "").strip().casefold()


def _normalized_interests(value):
    """
    Convert profile interests into a comparable set.

    The database stores interests as JSON arrays, but this function also accepts
    comma-separated strings to stay tolerant of imported/demo data.
    """
    if isinstance(value, str):
        raw_items = value.split(",")
    elif isinstance(value, (list, tuple, set)):
        raw_items = value
    else:
        raw_items = []
    return {
        _normalized_text(item)
        for item in raw_items
        if _normalized_text(item)
    }


def _cohort_from_class_code(class_code):
    """
    Extract a cohort token from PTIT-style class codes such as D22CNPM01.

    Example: D22CNPM01 and D22ATTT02 both map to cohort "22".
    """
    normalized = _normalized_text(class_code)
    match = re.search(r"[a-z]?(\d{2})", normalized)
    return match.group(1) if match else normalized


def _suggestion_score(current_profile, candidate_profile):
    """
    Calculate the hybrid weight-based similarity score for one candidate.

    Formula:
    - same major contributes 0.5
    - shared interests contribute up to 0.3, scaled by the current user's
      interest count
    - same cohort/batch contributes 0.2
    """
    current_major = _normalized_text(current_profile.major)
    candidate_major = _normalized_text(candidate_profile.major)
    major_match = bool(current_major and current_major == candidate_major)

    current_interests = _normalized_interests(current_profile.interests)
    candidate_interests = _normalized_interests(candidate_profile.interests)
    shared_interests = current_interests & candidate_interests
    interest_ratio = (
        min(len(shared_interests) / len(current_interests), 1.0)
        if current_interests
        else 0
    )

    current_cohort = _cohort_from_class_code(current_profile.class_code)
    candidate_cohort = _cohort_from_class_code(candidate_profile.class_code)
    cohort_match = bool(current_cohort and current_cohort == candidate_cohort)

    score = (
        (MAJOR_WEIGHT if major_match else 0)
        + (INTERESTS_WEIGHT * interest_ratio)
        + (COHORT_WEIGHT if cohort_match else 0)
    )
    reasons = {
        "major_match": major_match,
        "shared_interests": sorted(shared_interests),
        "shared_interests_count": len(shared_interests),
        "cohort_match": cohort_match,
    }
    return round(score, 4), reasons


class FriendSuggestionPagination(PageNumberPagination):
    """
    Page-number pagination for friend suggestions.

    The response keeps the legacy "results" key used by Flutter and adds
    pagination metadata so large student lists do not overload the client.
    """
    page_size = DEFAULT_SUGGESTION_PAGE_SIZE
    page_size_query_param = "page_size"
    max_page_size = MAX_SUGGESTION_PAGE_SIZE

    def get_paginated_response(self, data):
        """Return paginated JSON payload consumed by the mobile suggestions tab."""
        total_pages = (
            math.ceil(self.page.paginator.count / self.get_page_size(self.request))
            if self.get_page_size(self.request)
            else 1
        )
        return Response(
            {
                "count": self.page.paginator.count,
                "total_pages": total_pages,
                "page": self.page.number,
                "page_size": self.get_page_size(self.request),
                "next": self.get_next_link(),
                "previous": self.get_previous_link(),
                "results": data,
            }
        )


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def friend_requests_inbox_api(request):
    """GET /api/users/friends/requests/inbox/ - incoming pending friend requests."""
    me = resolve_demo_user(request)
    pending = (
        FriendRequest.objects.filter(to_user=me, status="pending")
        .select_related("from_user__profile", "to_user__profile")
        .order_by("-created_at")
    )
    return Response(FriendRequestSerializer(pending, many=True, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def friend_requests_sent_api(request):
    """GET /api/users/friends/requests/sent/ - outgoing pending friend requests."""
    me = resolve_demo_user(request)
    pending = (
        FriendRequest.objects.filter(from_user=me, status="pending")
        .select_related("from_user__profile", "to_user__profile")
        .order_by("-created_at")
    )
    return Response(FriendRequestSerializer(pending, many=True, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def friends_list_api(request):
    """GET /api/users/friends/ - accepted friends with profile data."""
    me = resolve_demo_user(request)
    profiles = []
    for user in _accepted_friend_users(me):
        profile, _ = Profile.objects.get_or_create(user=user)
        profiles.append(ProfileSerializer(profile, context={"request": request}).data)
    return Response({"friends": profiles})


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def users_search_api(request):
    """GET /api/users/search/ - search people by username, email, name, or student id."""
    me = resolve_demo_user(request)
    q = (request.query_params.get("q") or "").strip()
    qs = User.objects.exclude(id=me.id).select_related("profile")
    if q:
        qs = qs.filter(
            Q(username__icontains=q)
            | Q(email__icontains=q)
            | Q(profile__full_name__icontains=q)
            | Q(profile__student_id__icontains=q)
        )
    results = []
    for user in qs.order_by("username")[:30]:
        profile, _ = Profile.objects.get_or_create(user=user)
        results.append(ProfileSerializer(profile, context={"request": request}).data)
    return Response({"results": results})


@api_view(["GET"])
@permission_classes([IsAuthenticatedOrDemoUser])
def friend_suggestions_api(request):
    """
    GET /api/users/friends/suggestions/ - ranked friend suggestions.

    External mobile API flow:
    1. Resolve the current authenticated or demo user.
    2. Exclude self, accepted friends, and pending requests from both sides.
    3. Fetch candidate profiles with select_related("user") to avoid N+1
       queries while serializing username/email.
    4. Score each candidate, sort by score, and return a paginated response.
    """
    me = resolve_demo_user(request)
    current_profile, _ = Profile.objects.get_or_create(user=me)
    blocked_ids = _connected_user_ids(me) | {me.id}
    candidate_profiles = (
        Profile.objects.exclude(user_id__in=blocked_ids)
        .select_related("user")
        .order_by("user__username")
    )

    ranked_suggestions = []
    for profile in candidate_profiles:
        # Calculate ranking metadata before serialization so each item carries
        # both the profile data and the explanation for the recommendation.
        score, reasons = _suggestion_score(current_profile, profile)
        data = ProfileSerializer(profile, context={"request": request}).data
        data["similarity_score"] = score
        data["match_reasons"] = reasons
        ranked_suggestions.append(data)

    ranked_suggestions.sort(
        # Highest score first, then most shared interests, then stable username
        # ordering to keep pagination deterministic between requests.
        key=lambda item: (
            -item["similarity_score"],
            -item["match_reasons"]["shared_interests_count"],
            item["username"],
        )
    )

    paginator = FriendSuggestionPagination()
    page = paginator.paginate_queryset(ranked_suggestions, request)
    return paginator.get_paginated_response(page)


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def friend_request_send_api(request):
    """POST /api/users/friends/requests/send/ - create or auto-accept a friend request."""
    me = resolve_demo_user(request)
    target_username = (request.data.get("to_username") or "").strip().lower()
    if not target_username or target_username == me.username:
        return Response({"detail": "invalid to_username"}, status=status.HTTP_400_BAD_REQUEST)
    target = User.objects.filter(username=target_username).first()
    if target is None:
        return Response({"detail": "user not found"}, status=status.HTTP_404_NOT_FOUND)

    existing_reverse = FriendRequest.objects.filter(from_user=target, to_user=me).first()
    if existing_reverse and existing_reverse.status == "pending":
        existing_reverse.status = "accepted"
        existing_reverse.save(update_fields=["status"])
        create_notification(
            user=target,
            title="Đã trở thành bạn bè",
            content=f"{me.username} đã chấp nhận lời mời kết bạn.",
            notification_type="friend_accept",
            target_username=me.username,
        )
        create_notification(
            user=me,
            title="Đã trở thành bạn bè",
            content=f"Bạn và {target.username} đã là bạn bè.",
            notification_type="friend_accept",
            target_username=target.username,
        )
        return Response(FriendRequestSerializer(existing_reverse).data, status=status.HTTP_201_CREATED)

    fr, created = FriendRequest.objects.get_or_create(from_user=me, to_user=target, defaults={"status": "pending"})
    if not created and fr.status != "pending":
        fr.status = "pending"
        fr.save(update_fields=["status"])
    if created:
        create_notification(
            user=target,
            title="Lời mời kết bạn mới",
            content=f"{me.username} đã gửi lời mời kết bạn cho bạn.",
            notification_type="friend_request",
            target_username=me.username,
        )
    return Response(FriendRequestSerializer(fr).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsAuthenticatedOrDemoUser])
def friend_request_decide_api(request, pk):
    """POST /api/users/friends/requests/{id}/decide/ - accept or reject a request."""
    me = resolve_demo_user(request)
    fr = get_object_or_404(FriendRequest, pk=pk, to_user=me)
    action = (request.data.get("action") or "").lower()
    if action == "accept":
        fr.status = "accepted"
        fr.save(update_fields=["status"])
        create_notification(
            user=fr.from_user,
            title="Lời mời được chấp nhận",
            content=f"{me.username} đã chấp nhận lời mời kết bạn của bạn.",
            notification_type="friend_accept",
            target_username=me.username,
        )
    elif action == "reject":
        fr.status = "rejected"
        fr.save(update_fields=["status"])
    else:
        return Response({"detail": "action must be accept or reject"}, status=status.HTTP_400_BAD_REQUEST)
    return Response(FriendRequestSerializer(fr).data)
