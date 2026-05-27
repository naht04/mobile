from django.db import models
from django.contrib.auth.models import User


class Document(models.Model):
    TYPE_CHOICES = [
        ("slide", "Slide"),
        ("report", "Report"),
        ("exam", "Exam"),
        ("note", "Note"),
        ("other", "Other"),
    ]

    uploader = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="uploaded_documents"
    )
    title = models.CharField(max_length=255)
    subject = models.CharField(max_length=100)
    category = models.CharField(max_length=100, blank=True)
    document_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default="other")
    description = models.TextField(blank=True)
    download_count = models.IntegerField(default=0)
    file = models.FileField(upload_to="documents/")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.title
