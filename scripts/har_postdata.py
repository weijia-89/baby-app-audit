#!/usr/bin/env python3
"""Pack and decode HAR request bodies. No mitmproxy import."""
from __future__ import annotations

import base64
import binascii
import gzip
from pathlib import Path
from typing import Optional, Union


def request_post_data(content_type: str, body_bytes: Optional[bytes]) -> Optional[dict]:
    """Build HAR postData for a body, or None if empty."""
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
    """Decode a raw body to (text, encoding_or_None)."""
    try:
        return body_bytes.decode("utf-8"), None
    except UnicodeDecodeError:
        return base64.b64encode(body_bytes).decode("ascii"), "base64"


def decode_har_text(text: str, encoding: Optional[str] = None) -> str:
    """Return plain text from a HAR body field for scanning.

    Decode base64 when set. On failure return empty (avoid false marker hits).
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


def _header_blob(headers) -> str:
    values = []
    if isinstance(headers, dict):
        values = [str(value) for value in headers.values()]
    elif isinstance(headers, list):
        for item in headers:
            if isinstance(item, dict):
                values.append(str(item.get("name", "")))
                values.append(str(item.get("value", "")))
    return " ".join(values).lower()


def _body_bytes(text: str, encoding: Optional[str]) -> Optional[bytes]:
    if encoding and str(encoding).lower() == "base64":
        try:
            return base64.b64decode(text.encode("ascii"), validate=False)
        except (ValueError, binascii.Error):
            return None
    stripped = "".join(text.split())
    try:
        return base64.b64decode(stripped, validate=True)
    except (ValueError, binascii.Error):
        pass
    try:
        return text.encode("utf-8")
    except UnicodeEncodeError:
        return None


def _gunzip(raw: bytes) -> Optional[bytes]:
    if len(raw) < 2 or raw[0] != 0x1F or raw[1] != 0x8B:
        return None
    try:
        return gzip.decompress(raw)
    except OSError:
        return None


def _varint(raw: bytes, index: int, limit: int):
    shift = 0
    value = 0
    while index < limit and shift <= 63:
        byte = raw[index]
        index += 1
        value |= (byte & 0x7F) << shift
        if byte < 128:
            return value, index
        shift += 7
    return None


def _printable(chunk: bytes) -> Optional[str]:
    try:
        text = chunk.decode("utf-8")
    except UnicodeDecodeError:
        return None
    if not text:
        return None
    for char in text:
        if char not in "\t\n\r" and not char.isprintable():
            return None
    return text


def _walk_protobuf(raw: bytes, start: int, limit: int, depth: int):
    # shortcut: wire types 3 and 4 (groups) count as unscannable, upgrade if a capture uses groups
    strings = []
    index = start
    if start == limit:
        return strings, index, True
    while index < limit:
        parsed = _varint(raw, index, limit)
        if parsed is None:
            return strings, index, False
        tag, index = parsed
        wire = tag & 7
        if tag >> 3 == 0:
            return strings, index, False
        if wire == 0:
            parsed = _varint(raw, index, limit)
            if parsed is None:
                return strings, index, False
            _, index = parsed
        elif wire == 1:
            if index + 8 > limit:
                return strings, index, False
            index += 8
        elif wire == 5:
            if index + 4 > limit:
                return strings, index, False
            index += 4
        elif wire == 2:
            parsed = _varint(raw, index, limit)
            if parsed is None:
                return strings, index, False
            length, index = parsed
            if length < 0 or index + length > limit:
                return strings, index, False
            chunk = raw[index:index + length]
            index += length
            if depth < 8 and chunk:
                nested, _, ok = _walk_protobuf(chunk, 0, len(chunk), depth + 1)
                if ok:
                    strings.extend(nested)
            text = _printable(chunk)
            if text:
                strings.append(text)
        else:
            return strings, index, False
    return strings, index, True


def protobuf_text(raw: bytes) -> Optional[str]:
    """UTF-8 strings from a raw protobuf body. None when the buffer is not a message."""
    if not raw:
        return ""
    strings, end, ok = _walk_protobuf(raw, 0, len(raw), 0)
    if not ok or end != len(raw):
        return None
    return "\n".join(strings)


def prepare_scan_body(text: str, encoding: Optional[str] = None, headers=None):
    """Return (searchable text, unscannable) for one body.

    Gunzip a body sent with Accept application/x-clarity-gzip.
    Walk a protobuf body with the standard library. Count it unscannable
    when that walk fails. protoc is not used.
    """
    if not text:
        return "", False
    if not isinstance(text, str):
        text = str(text)
    header_blob = _header_blob(headers)
    clarity = "application/x-clarity-gzip" in header_blob
    protobuf = "protobuf" in header_blob
    if not clarity and not protobuf:
        if encoding and str(encoding).lower() == "base64":
            return decode_har_text(text, encoding), False
        return text, False
    raw = _body_bytes(text, encoding)
    if raw is None:
        return "", True
    if clarity:
        inflated = _gunzip(raw)
        if inflated is None:
            return "", True
        return inflated.decode("utf-8", errors="replace"), False
    payload = raw
    if raw[:2] == b"\x1f\x8b":
        inflated = _gunzip(raw)
        if inflated is None:
            return "", True
        payload = inflated
    extracted = protobuf_text(payload)
    if extracted is None:
        return "", True
    return extracted, False


def is_under_directory(path: Union[str, Path], root: Union[str, Path]) -> bool:
    """True if path is root or under root. Reject sibling-prefix paths."""
    try:
        Path(path).resolve().relative_to(Path(root).resolve())
        return True
    except ValueError:
        return False
