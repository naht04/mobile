from django.urls import path

from .views import document_detail_api, documents_api, document_subjects_api

urlpatterns = [
    path("", documents_api, name="documents-api"),
    path("subjects/", document_subjects_api, name="document-subjects"),
    path("<int:pk>/", document_detail_api, name="document-detail"),
]
