from django.contrib import admin
from .models import Comment, Post, PostLike, SavedPost

admin.site.register(Post)
admin.site.register(Comment)
admin.site.register(PostLike)
admin.site.register(SavedPost)
