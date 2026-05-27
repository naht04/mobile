from django.urls import path
from .views import (
    call_history_api,
    call_invite_api,
    call_update_status_api,
    conversation_add_members_api,
    conversation_approval_setting_api,
    conversation_create_group_api,
    conversation_delete_api,
    conversation_dissolve_api,
    conversation_leave_api,
    conversation_members_api,
    conversation_open_api,
    conversation_transfer_owner_api,
    conversations_api,
    messages_api,
)

urlpatterns = [
    path("", conversations_api, name="conversations"),
    path("open/", conversation_open_api, name="conversation-open"),
    path("create-group/", conversation_create_group_api, name="conversation-create-group"),
    path("<int:pk>/messages/", messages_api, name="conversation-messages"),
    path("<int:pk>/members/", conversation_members_api, name="conversation-members"),
    path("<int:pk>/members/add/", conversation_add_members_api, name="conversation-add-members"),
    path("<int:pk>/leave/", conversation_leave_api, name="conversation-leave"),
    path("<int:pk>/transfer-owner/", conversation_transfer_owner_api, name="conversation-transfer-owner"),
    path("<int:pk>/approval-setting/", conversation_approval_setting_api, name="conversation-approval-setting"),
    path("<int:pk>/dissolve/", conversation_dissolve_api, name="conversation-dissolve"),
    path("<int:pk>/call/invite/", call_invite_api, name="call-invite"),
    path("<int:pk>/call-logs/", call_history_api, name="call-history"),
    path("<int:pk>/call-logs/<int:call_log_id>/status/", call_update_status_api, name="call-update-status"),
    path("<int:pk>/delete/", conversation_delete_api, name="conversation-delete"),
]
