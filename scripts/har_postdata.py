#!/usr/bin/env python3
"""Pure helpers for HAR request body packing and text decode (no mitmproxy import)."""
from __future__ import annotations

import base64
import binascii
from typing import Optional


def request_post_data(content_type: str, body_bytes: Optional[bytes]) -> Optional[dict]:
    """Return HAR postData dict for a request body, or None if empty."""
    if not body_bytes:
        return None
    try:
        text = body_bytes.decode("utf-8")
        encoding = None
    except UnicodeDecodeError:
        text = base64.b64encode(body_bytes).decode("ascii")
        encoding = "base64"
    post = {
        "mimeType": content_type or "",
        "text": text,
    }
    if encoding:
        post["encoding"] = encoding
    return post


def decode_har_text(text: str, encoding: Optional[str] = None) -> str:
    """Return searchable plaintext from a HAR body field.

    When encoding is base64, decode before scan. On decode failure return empty
    so base64 noise cannot invent marker hits.
    """
    if not text:
        return ""
    if encoding and str(encoding).lower() == "base64":
        try:
            raw = base64.b64decode(text.encode("ascii"))
        except (ValueError, TypeError, binascii.Error):
            return ""
        return raw.decode("utf-8", errors="replace")
    return text
