from rest_framework.permissions import BasePermission


class IsAuthenticatedOrDemoUser(BasePermission):
    def has_permission(self, request, view):
        user = getattr(request, "user", None)
        if user is not None and user.is_authenticated:
            return True

        headers = getattr(request, "headers", None)
        if headers and headers.get("X-Demo-User"):
            return True

        meta = getattr(request, "META", {}) or {}
        if meta.get("HTTP_X_DEMO_USER"):
            return True

        try:
            if request.query_params.get("username"):
                return True
        except Exception:
            pass

        try:
            if request.data.get("username"):
                return True
        except Exception:
            pass

        return False
