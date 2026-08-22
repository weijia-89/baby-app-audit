#!/usr/bin/env python3
"""Pure helpers for HAR request body packing and text decode (no mitmproxy import)."""
from __future__ import annotations

import base64
import binascii
from pathlib import Path
from typing import Optional, Union


def request_post_data(content_type: str, body_bytes: Optional[bytes]) -> Optional[dict]:
    """Return HAR postData dict for a request body, or None if empty."""
    if not body_bytes:
        return None
    text, encoding = encode_body_text(body_bytes)
    post = {
        "mimeType": content_type or "",
        "text": text,
    }
    if encoding:
        post["encoding"] = encoding
    return post


def encode_body_text(body_bytes: bytes) -> tuple:
    """Return (text, encoding_or_None) for a raw body."""
    try:
        return body_bytes.decode("utf-8"), None
    except UnicodeDecodeError:
        return base64.b64encode(body_bytes).decode("ascii"), "base64"


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


def is_under_directory(path: Union[str, Path], root: Union[str, Path]) -> bool:
    """True when resolved path is root or a descendant. Rejects sibling prefix tricks."""
    try:
        Path(path).resolve().relative_to(Path(root).resolve())
        return True
    except ValueError:
        return False
