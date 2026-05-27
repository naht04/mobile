from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .friend_views import (
    friend_request_decide_api,
    friend_request_send_api,
    friend_requests_inbox_api,
    friend_requests_sent_api,
    friend_suggestions_api,
    friends_list_api,
    users_search_api,
)
from .views import EmailLoginView, ProfileView, RegisterView

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", EmailLoginView.as_view(), name="login"),
    path("refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("profile/", ProfileView.as_view(), name="profile"),
    path("friends/", friends_list_api, name="friends-list"),
    path("search/", users_search_api, name="users-search"),
    path("friends/suggestions/", friend_suggestions_api, name="friend-suggestions"),
    path("friends/requests/inbox/", friend_requests_inbox_api, name="friend-requests-inbox"),
    path("friends/requests/sent/", friend_requests_sent_api, name="friend-requests-sent"),
    path("friends/requests/send/", friend_request_send_api, name="friend-request-send"),
    path("friends/requests/<int:pk>/decide/", friend_request_decide_api, name="friend-request-decide"),
]
