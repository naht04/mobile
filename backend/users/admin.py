from django.contrib import admin

from .models import FriendRequest, Profile

admin.site.register(Profile)
admin.site.register(FriendRequest)
