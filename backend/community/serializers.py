from rest_framework import serializers

from .models import Comment, Post


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.username", read_only=True)
    replies = serializers.SerializerMethodField()

    class Meta:
        model = Comment
        fields = ["id", "author_name", "content", "created_at", "replies"]

    def get_replies(self, obj):
        replies = obj.replies.all()
        return CommentSerializer(replies, many=True).data


class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.username", read_only=True)
    comments = serializers.SerializerMethodField()
    like_count = serializers.SerializerMethodField()
    save_count = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()
    file_name = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    is_saved = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = [
            "id",
            "author_name",
            "title",
            "content",
            "topic",
            "image",
            "file",
            "file_name",
            "created_at",
            "like_count",
            "save_count",
            "comment_count",
            "is_liked",
            "is_saved",
            "comments",
        ]

    def get_comments(self, obj):
        # Only get top-level comments (where parent is None)
        root_comments = obj.comments.filter(parent__isnull=True)
        return CommentSerializer(root_comments, many=True).data

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_save_count(self, obj):
        return obj.saved_by.count()

    def get_comment_count(self, obj):
        # Count all comments (root + replies)
        return obj.comments.count()

    def get_is_liked(self, obj):
        user = self.context.get('user')
        if not user:
            return False
        from .models import PostLike
        return PostLike.objects.filter(post=obj, user=user).exists()

    def get_is_saved(self, obj):
        user = self.context.get('user')
        if not user:
            return False
        from .models import SavedPost
        return SavedPost.objects.filter(post=obj, user=user).exists()

    def get_comment_count(self, obj):
        return obj.comments.count()

    def get_file_name(self, obj):
        if not obj.file:
            return None
        return obj.file.name.rsplit('/', 1)[-1]
