import os

from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application
from django.urls import path

from chat_app.consumers import CallConsumer, ChatConsumer, NotificationConsumer

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")

django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": URLRouter([
        path("ws/core/<str:username>/", NotificationConsumer.as_asgi()),
        path("ws/notifications/<str:username>/", NotificationConsumer.as_asgi()),
        path("ws/chat/<int:conversation_id>/", ChatConsumer.as_asgi()),
        path("ws/call/<int:conversation_id>/", CallConsumer.as_asgi()),
    ]),
})
