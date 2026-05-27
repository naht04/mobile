from django.db.models import Q
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user

from .models import Document
from .serializers import DocumentSerializer

DEFAULT_SUBJECTS = [
    "Flutter",
    "Python",
    "Java",
    "AI",
    "Database",
    "Web",
]

DEFAULT_CATEGORIES = [
    "Giáo trình",
    "Slide",
    "Đề thi",
    "Báo cáo",
    "Ghi chú",
]


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def documents_api(request):
    if request.method == "GET":
        qs = Document.objects.all()
        subject = request.query_params.get("subject", "").strip()
        category = request.query_params.get("category", "").strip()
        q = request.query_params.get("q", "").strip()
        if subject:
            qs = qs.filter(subject__iexact=subject)
        if category:
            qs = qs.filter(category__iexact=category)
        if q:
            qs = qs.filter(
                Q(title__icontains=q)
                | Q(description__icontains=q)
                | Q(subject__icontains=q)
                | Q(category__icontains=q)
            )
        serializer = DocumentSerializer(qs[:100], many=True, context={"request": request})
        return Response(serializer.data)

    actor = resolve_demo_user(request)
    title = (request.data.get("title") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    category = (request.data.get("category") or "").strip()
    document_type = (request.data.get("document_type") or "other").strip().lower()
    description = (request.data.get("description") or "").strip()
    file_obj = request.FILES.get("file")
    if not title or not subject:
        return Response(
            {"detail": "title and subject are required"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not file_obj:
        return Response(
            {"detail": "file is required (multipart upload)"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    doc = Document.objects.create(
        uploader=actor,
        title=title,
        subject=subject,
        category=category,
        document_type=document_type if document_type in dict(Document.TYPE_CHOICES) else "other",
        description=description,
        file=file_obj,
    )
    return Response(
        DocumentSerializer(doc, context={"request": request}).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([permissions.IsAuthenticated])
def document_detail_api(request, pk):
    doc = get_object_or_404(Document, pk=pk)
    if request.method == "GET":
        return Response(DocumentSerializer(doc, context={"request": request}).data)

    actor = resolve_demo_user(request)
    if doc.uploader_id != actor.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

    if request.method == "PATCH":
        doc.title = (request.data.get("title") or doc.title).strip()
        doc.subject = (request.data.get("subject") or doc.subject).strip()
        doc.category = (request.data.get("category") or doc.category).strip()
        doc_type = (request.data.get("document_type") or doc.document_type).strip().lower()
        doc.document_type = doc_type if doc_type in dict(Document.TYPE_CHOICES) else doc.document_type
        doc.description = (request.data.get("description") or doc.description).strip()
        if request.FILES.get("file"):
            doc.file = request.FILES["file"]
        doc.save()
        return Response(DocumentSerializer(doc, context={"request": request}).data)

    doc.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def document_subjects_api(request):
    db_subjects = (
        Document.objects.exclude(subject__exact="")
        .values_list("subject", flat=True)
        .distinct()
    )
    subjects = sorted(set(DEFAULT_SUBJECTS).union(set(db_subjects)))
    db_categories = (
        Document.objects.exclude(category__exact="")
        .values_list("category", flat=True)
        .distinct()
    )
    categories = sorted(set(DEFAULT_CATEGORIES).union(set(db_categories)))
    return Response({"subjects": subjects, "categories": categories, "results": subjects})
