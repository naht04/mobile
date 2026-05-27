from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

def notify_user(username, payload):
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f"user_{username}",
        {
            "type": "send_event",
            "payload": payload,
        },
    )