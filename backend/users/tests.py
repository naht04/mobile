from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from .models import FriendRequest, Profile


class FriendSuggestionTests(TestCase):
    """Regression tests for the hybrid friend suggestion API."""

    def setUp(self):
        """Create the current user with all scoring dimensions populated."""
        self.client = APIClient()
        self.me = User.objects.create_user(
            username="me", email="me@stu.ptit.edu.vn", password="pass"
        )
        Profile.objects.filter(user=self.me).update(
            major="CNTT",
            class_code="D22CNPM01",
            interests=["python", "ai", "football"],
        )
        self.client.force_authenticate(self.me)

    def _user(self, username, major="", class_code="", interests=None):
        """Create a candidate user and update the auto-created profile."""
        user = User.objects.create_user(
            username=username,
            email=f"{username}@stu.ptit.edu.vn",
            password="pass",
        )
        Profile.objects.filter(user=user).update(
            major=major,
            class_code=class_code,
            interests=interests or [],
        )
        return user

    def test_suggestions_are_ranked_by_hybrid_similarity_score(self):
        """Candidates with stronger major/interest/cohort matches rank first."""
        strong = self._user(
            "strong",
            major="CNTT",
            class_code="D22ATTT01",
            interests=["python", "ai"],
        )
        medium = self._user(
            "medium",
            major="CNTT",
            class_code="D21CNPM01",
            interests=["music"],
        )
        weak = self._user(
            "weak",
            major="DTVT",
            class_code="D21DTVT01",
            interests=["football"],
        )

        response = self.client.get("/api/users/friends/suggestions/")

        self.assertEqual(response.status_code, 200)
        usernames = [item["username"] for item in response.data["results"]]
        self.assertEqual(usernames, [strong.username, medium.username, weak.username])
        self.assertGreater(
            response.data["results"][0]["similarity_score"],
            response.data["results"][1]["similarity_score"],
        )
        self.assertEqual(
            response.data["results"][0]["match_reasons"]["shared_interests_count"],
            2,
        )

    def test_suggestions_exclude_self_friends_and_pending_requests(self):
        """Existing friends and pending requests in either direction are hidden."""
        friend = self._user("friend", "CNTT", "D22CNPM02", ["python"])
        pending_out = self._user("pending_out", "CNTT", "D22CNPM03", ["ai"])
        pending_in = self._user("pending_in", "CNTT", "D22CNPM04", ["football"])
        visible = self._user("visible", "CNTT", "D22CNPM05", ["python"])
        FriendRequest.objects.create(
            from_user=self.me,
            to_user=friend,
            status="accepted",
        )
        FriendRequest.objects.create(
            from_user=self.me,
            to_user=pending_out,
            status="pending",
        )
        FriendRequest.objects.create(
            from_user=pending_in,
            to_user=self.me,
            status="pending",
        )

        response = self.client.get("/api/users/friends/suggestions/")

        usernames = {item["username"] for item in response.data["results"]}
        self.assertEqual(usernames, {visible.username})
        self.assertNotIn(self.me.username, usernames)

    def test_suggestions_are_paginated(self):
        """The endpoint returns page metadata and only the requested page."""
        for index in range(3):
            self._user(f"user{index}", "CNTT", "D22CNPM01", ["python"])

        response = self.client.get("/api/users/friends/suggestions/?page=2&page_size=2")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 3)
        self.assertEqual(response.data["page"], 2)
        self.assertEqual(response.data["page_size"], 2)
        self.assertEqual(len(response.data["results"]), 1)
