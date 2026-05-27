import json
from channels.generic.websocket import AsyncWebsocketConsumer
from asgiref.sync import sync_to_async
from django.contrib.auth.models import User
from django.utils import timezone


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.username = self.scope['url_route']['kwargs']['username']
        self.group_name = f"user_{self.username}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        await self.send(text_data=json.dumps({"type": "connected", "scope": "notifications"}))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def push_event(self, event):
        await self.send(text_data=json.dumps(event['payload']))


class PresenceConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.username = self.scope['url_route']['kwargs']['username']
        await self.accept()
        await self._set_presence(True)
        await self.send(text_data=json.dumps({"type": "presence", "is_online": True}))

    async def disconnect(self, close_code):
        await self._set_presence(False)

    async def receive(self, text_data=None, bytes_data=None):
        await self.send(text_data=json.dumps({"type": "presence", "is_online": True}))

    @sync_to_async
    def _set_presence(self, online: bool):
        user = User.objects.filter(username=self.username).select_related('profile').first()
        if not user:
            return
        profile = getattr(user, 'profile', None)
        if not profile:
            return
        profile.is_online = online
        profile.last_seen = timezone.now()
        profile.save(update_fields=['is_online', 'last_seen'])
