from django.urls import path

from .views import (
    notification_badges_api,
    notification_delete_api,
    notification_read_api,
    notifications_api,
    notifications_read_all_api,
)

urlpatterns = [
    path("", notifications_api, name="notifications"),
    path("badges/", notification_badges_api, name="notification-badges"),
    path("read-all/", notifications_read_all_api, name="notifications-read-all"),
    path("<int:pk>/read/", notification_read_api, name="notification-read"),
    path("<int:pk>/delete/", notification_delete_api, name="notification-delete"),
]
