#!/usr/bin/env python3
"""Pure helpers for HAR request body packing (no mitmproxy import)."""
from __future__ import annotations

from typing import Optional


def request_post_data(content_type: str, body_bytes: Optional[bytes]) -> Optional[dict]:
    """Return HAR postData dict for a request body, or None if empty."""
    if not body_bytes:
        return None
    try:
        text = body_bytes.decode("utf-8")
        encoding = None
    except UnicodeDecodeError:
        import base64

        text = base64.b64encode(body_bytes).decode("ascii")
        encoding = "base64"
    post = {
        "mimeType": content_type or "",
        "text": text,
    }
    if encoding:
        post["encoding"] = encoding
    return post
