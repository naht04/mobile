import json

from channels.generic.websocket import AsyncWebsocketConsumer


class _BaseJsonConsumer(AsyncWebsocketConsumer):
    group_name = ""

    async def connect(self):
        self.group_name = self.get_group_name()
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if self.group_name:
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        try:
            payload = json.loads(text_data or "{}")
        except json.JSONDecodeError:
            return
        await self.handle_payload(payload)

    async def handle_payload(self, payload):
        return

    async def _broadcast(self, payload):
        await self.channel_layer.group_send(
            self.group_name,
            {
                "type": "push.event",
                "payload": payload,
                "sender_channel": self.channel_name,
            },
        )

    async def push_event(self, event):
        if event.get("sender_channel") == self.channel_name:
            return
        await self.send(text_data=json.dumps(event.get("payload", {})))

    def get_group_name(self):
        raise NotImplementedError


class NotificationConsumer(_BaseJsonConsumer):
    def get_group_name(self):
        username = self.scope["url_route"]["kwargs"]["username"]
        return f"user_{username}"


class ChatConsumer(_BaseJsonConsumer):
    def get_group_name(self):
        conversation_id = self.scope["url_route"]["kwargs"]["conversation_id"]
        return f"chat_{conversation_id}"

    async def handle_payload(self, payload):
        if payload.get("type") == "typing":
            await self._broadcast(payload)


class CallConsumer(_BaseJsonConsumer):
    def get_group_name(self):
        conversation_id = self.scope["url_route"]["kwargs"]["conversation_id"]
        return f"call_{conversation_id}"

    async def handle_payload(self, payload):
        if payload.get("type") in {"ready", "offer", "answer", "candidate", "hangup"}:
            await self._broadcast(payload)
