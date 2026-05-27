from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/users/", include("users.urls")),
    path("api/chat/", include("chat_app.urls")),
    path("api/notifications/", include("notifications_app.urls")),
    path("api/community/", include("community.urls")),
    path("api/documents/", include("documents.urls")),
    path("api/groups/", include("groups_app.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)