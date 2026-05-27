from urllib.parse import quote, urljoin, urlparse
import xml.etree.ElementTree as ET

import requests
from bs4 import BeautifulSoup
from django.db.models import Q
from django.http import HttpResponse
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response
from rest_framework.views import APIView

from core.demo_auth import resolve_demo_user

from .models import Comment, Post, PostLike, SavedPost
from .serializers import CommentSerializer, PostSerializer

PTIT_RSS_URLS = [
    "https://ptit.edu.vn/feed/",
    "https://ptit.edu.vn/tin-tuc/feed/",
]


class AutoFeedView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        limit = min(int(request.query_params.get("limit", 12)), 30)
        items = _fetch_news(limit)
        for item in items:
            image_url = (item.get("image_url") or "").strip()
            if image_url:
                item["image_url"] = request.build_absolute_uri(
                    f"/api/community/image-proxy/?url={quote(image_url, safe='')}"
                )
        return Response({"count": len(items), "results": items}, status=status.HTTP_200_OK)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def news_image_proxy_api(request):
    raw_url = (request.query_params.get("url") or "").strip()
    if not raw_url:
        return Response({"detail": "url is required"}, status=status.HTTP_400_BAD_REQUEST)

    parsed = urlparse(raw_url)
    if parsed.scheme not in ("http", "https"):
        return Response({"detail": "invalid url scheme"}, status=status.HTTP_400_BAD_REQUEST)
    if not parsed.netloc.endswith("ptit.edu.vn"):
        return Response({"detail": "only ptit.edu.vn is allowed"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        upstream = requests.get(
            raw_url,
            timeout=10,
            headers={
                "User-Agent": "Mozilla/5.0 (compatible; PTITConnectBot/1.0)",
                "Referer": "https://ptit.edu.vn/",
            },
        )
        upstream.raise_for_status()
    except Exception:
        return Response({"detail": "failed to fetch image"}, status=status.HTTP_502_BAD_GATEWAY)

    content_type = upstream.headers.get("Content-Type", "image/jpeg")
    return HttpResponse(upstream.content, content_type=content_type)


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def posts_api(request):
    if request.method == "GET":
        keyword = request.query_params.get("q", "").strip()
        queryset = Post.objects.all()
        if keyword:
            queryset = queryset.filter(
                Q(title__icontains=keyword) | Q(content__icontains=keyword) | Q(topic__icontains=keyword)
            )
        actor = resolve_demo_user(request)
        serializer = PostSerializer(queryset[:50], many=True, context={'request': request, 'user': actor})
        return Response(serializer.data)

    actor = resolve_demo_user(request)
    title = (request.data.get("title") or "").strip()
    content = (request.data.get("content") or "").strip()
    topic = (request.data.get("topic") or "").strip()
    image = request.FILES.get("image")
    attached_file = request.FILES.get("attached_file")
    if not title or not content:
        return Response({"detail": "title and content are required"}, status=status.HTTP_400_BAD_REQUEST)
    post = Post.objects.create(
        author=actor,
        title=title,
        content=content,
        topic=topic,
        image=image,
        file=attached_file,
    )
    return Response(PostSerializer(post, context={'request': request, 'user': actor}).data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([permissions.IsAuthenticated])
def post_detail_api(request, post_id):
    post = get_object_or_404(Post, id=post_id)
    actor = resolve_demo_user(request)
    if request.method == "GET":
        return Response(PostSerializer(post, context={'request': request, 'user': actor}).data)
    if post.author_id != actor.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

    if request.method == "PATCH":
        title = (request.data.get("title") or post.title).strip()
        content = (request.data.get("content") or post.content).strip()
        topic = (request.data.get("topic") or post.topic).strip()
        if not title or not content:
            return Response({"detail": "title and content are required"}, status=status.HTTP_400_BAD_REQUEST)

        post.title = title
        post.content = content
        post.topic = topic

        image = request.FILES.get("image")
        remove_image = str(request.data.get("remove_image", "")).lower() in ["1", "true", "yes", "on"]
        if image is not None:
            post.image = image
        elif remove_image:
            post.image = None

        update_fields = ["title", "content", "topic"]
        if image is not None or remove_image:
            update_fields.append("image")

        post.save(update_fields=update_fields)
        return Response(PostSerializer(post, context={'request': request, 'user': actor}).data)

    post.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def post_comment_api(request, post_id):
    post = get_object_or_404(Post, id=post_id)
    actor = resolve_demo_user(request)
    content = (request.data.get("content") or "").strip()
    parent_id = request.data.get("parent_id")
    if not content:
        return Response({"detail": "content is required"}, status=status.HTTP_400_BAD_REQUEST)
    
    parent = None
    if parent_id:
        parent = get_object_or_404(Comment, id=parent_id, post=post)
    
    comment = Comment.objects.create(post=post, author=actor, content=content, parent=parent)
    return Response(CommentSerializer(comment).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def post_react_api(request, post_id):
    post = get_object_or_404(Post, id=post_id)
    actor = resolve_demo_user(request)
    like, created = PostLike.objects.get_or_create(post=post, user=actor)
    if not created:
        like.delete()
    return Response(
        {
            "liked": created,
            "like_count": post.likes.count(),
        }
    )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def post_save_api(request, post_id):
    post = get_object_or_404(Post, id=post_id)
    actor = resolve_demo_user(request)
    save, created = SavedPost.objects.get_or_create(post=post, user=actor)
    if not created:
        save.delete()
    return Response(
        {
            "saved": created,
            "save_count": post.saved_by.count(),
        }
    )


def _fetch_news(limit):
    rss_items = _fetch_from_rss(limit)
    if rss_items:
        return rss_items
    return _fetch_from_homepage(limit)


def _fetch_from_rss(limit):
    for rss_url in PTIT_RSS_URLS:
        try:
            response = requests.get(rss_url, timeout=10)
            response.raise_for_status()
            root = ET.fromstring(response.content)
            channel = root.find("channel")
            if channel is None:
                continue

            items = []
            for node in channel.findall("item")[:limit]:
                title = _xml_text(node, "title")
                link = _xml_text(node, "link")
                summary = _xml_text(node, "description")
                pub_date = _xml_text(node, "pubDate")
                image_url = None

                enclosure = node.find("enclosure")
                if enclosure is not None:
                    image_url = enclosure.attrib.get("url")
                if not image_url and link:
                    image_url = _extract_image_from_article(link)

                if title and link:
                    items.append(
                        {
                            "title": title,
                            "url": link,
                            "summary": _strip_html(summary),
                            "published_at": pub_date,
                            "image_url": image_url,
                            "source": "ptit.edu.vn",
                        }
                    )
            if items:
                return items
        except Exception:
            continue
    return []


def _fetch_from_homepage(limit):
    try:
        response = requests.get("https://ptit.edu.vn/", timeout=10)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")

        items = []
        seen = set()
        for anchor in soup.select("a[href]"):
            href = anchor.get("href", "").strip()
            text = anchor.get_text(" ", strip=True)
            if not href or not text or len(text) < 35:
                continue

            full_url = urljoin("https://ptit.edu.vn", href)
            if "ptit.edu.vn" not in full_url or full_url in seen:
                continue
            seen.add(full_url)

            items.append(
                {
                    "title": text,
                    "url": full_url,
                    "summary": "",
                    "published_at": "",
                    "image_url": _extract_image_from_article(full_url),
                    "source": "ptit.edu.vn",
                }
            )
            if len(items) >= limit:
                break
        return items
    except Exception:
        return []


def _xml_text(node, key):
    child = node.find(key)
    if child is None:
        return ""
    return (child.text or "").strip()


def _strip_html(raw):
    if not raw:
        return ""
    return BeautifulSoup(raw, "html.parser").get_text(" ", strip=True)


def _extract_image_from_article(article_url):
    try:
        response = requests.get(article_url, timeout=8)
        response.raise_for_status()
    except Exception:
        return None

    soup = BeautifulSoup(response.text, "html.parser")

    # Prefer OpenGraph/Twitter images first for stable preview quality.
    for selector, attr in [
        ('meta[property="og:image"]', "content"),
        ('meta[property="og:image:secure_url"]', "content"),
        ('meta[name="twitter:image"]', "content"),
    ]:
        node = soup.select_one(selector)
        if node:
            raw = (node.get(attr) or "").strip()
            if raw:
                return urljoin(article_url, raw)

    first_img = soup.select_one("article img, .entry-content img, .post-content img, img")
    if first_img:
        raw = (
            first_img.get("src")
            or first_img.get("data-src")
            or first_img.get("data-lazy-src")
            or first_img.get("data-original")
            or ""
        ).strip()
        if raw:
            return urljoin(article_url, raw)

    # Some PTIT pages render the banner as CSS background-image.
    for node in soup.select("[style*='background-image']"):
        style = (node.get("style") or "").strip()
        marker = "background-image"
        idx = style.lower().find(marker)
        if idx < 0:
            continue
        segment = style[idx:]
        start = segment.find("url(")
        end = segment.find(")", start + 4)
        if start < 0 or end < 0:
            continue
        raw = segment[start + 4 : end].strip().strip('"').strip("'")
        if raw:
            return urljoin(article_url, raw)

    return None


