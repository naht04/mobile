from django.urls import re_path
from .consumers import CallConsumer

websocket_urlpatterns = [
    re_path(r"ws/call/(?P<conversation_id>\d+)/$", CallConsumer.as_asgi()),
]
