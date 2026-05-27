from django.contrib.auth.models import User


def resolve_demo_user(request):
    """Resolve actor: authenticated user, else X-Demo-User header or username in body."""
    user = getattr(request, "user", None)
    if user is not None and user.is_authenticated:
        return user
    username = None
    meta = getattr(request, "META", {}) or {}
    username = meta.get("HTTP_X_DEMO_USER")
    if not username and hasattr(request, "headers"):
        username = request.headers.get("X-Demo-User")
    if not username and hasattr(request, "data"):
        try:
            username = request.data.get("username")
        except Exception:
            pass
    if not username and hasattr(request, "query_params"):
        try:
            username = request.query_params.get("username")
        except Exception:
            pass
    username = (username or "demo_user").strip().replace(" ", "_").lower()[:40] or "demo_user"
    u, _ = User.objects.get_or_create(
        username=username,
        defaults={"email": f"{username}@stu.ptit.edu.vn"},
    )
    return u
