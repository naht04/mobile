from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer


def notify_user(username: str, payload: dict):
    if not username:
        return
    channel_layer = get_channel_layer()
    if not channel_layer:
        return
    async_to_sync(channel_layer.group_send)(f"user_{username}", {"type": "push.event", "payload": payload})


def notify_conversation(conversation_id: int, payload: dict):
    channel_layer = get_channel_layer()
    if not channel_layer or not conversation_id:
        return
    async_to_sync(channel_layer.group_send)(f"chat_{conversation_id}", {"type": "push.event", "payload": payload})
