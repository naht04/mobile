from rest_framework import serializers

from .models import Document


class DocumentSerializer(serializers.ModelSerializer):
    uploader_name = serializers.CharField(source="uploader.username", read_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = Document
        fields = [
            "id",
            "uploader_name",
            "title",
            "subject",
            "category",
            "document_type",
            "description",
            "download_count",
            "file",
            "file_url",
            "created_at",
        ]
        read_only_fields = ["id", "uploader_name", "file_url", "created_at"]

    def get_file_url(self, obj):
        if not obj.file:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.file.url)
        return obj.file.url
