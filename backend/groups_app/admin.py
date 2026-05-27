from django.contrib import admin
from .models import GroupMember, JoinRequest, StudyGroup

admin.site.register(StudyGroup)
admin.site.register(GroupMember)
admin.site.register(JoinRequest)
