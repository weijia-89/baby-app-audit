#!/usr/bin/env python3
"""Tests for HAR postData pack/decode, path checks, and scan use."""
import base64
import sys
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(repo / "scripts"))
from har_postdata import (  # noqa: E402
    decode_har_text,
    encode_body_text,
    is_under_directory,
    request_post_data,
)


def main() -> int:
    body = b'{"firstName":"Privatia Rigatoni","location":"US"}'
    post = request_post_data("application/json", body)
    assert post is not None, "expected postData for non-empty body"
    assert post["text"] == body.decode("utf-8"), post
    assert "Privatia Rigatoni" in post["text"]
    assert "encoding" not in post
    assert request_post_data("application/json", b"") is None
    assert request_post_data("application/json", None) is None

    text_utf8, enc_utf8 = encode_body_text(body)
    assert enc_utf8 is None
    assert text_utf8 == body.decode("utf-8")

    binary = b"\xff\xfePrivatia Rigatoni\x00"
    post_b64 = request_post_data("application/octet-stream", binary)
    assert post_b64 is not None
    assert post_b64.get("encoding") == "base64"
    assert "Privatia" not in post_b64["text"]
    decoded = decode_har_text(post_b64["text"], post_b64.get("encoding"))
    assert "Privatia Rigatoni" in decoded, decoded
    text_b, enc_b = encode_body_text(binary)
    assert enc_b == "base64"
    assert text_b == post_b64["text"]

    assert decode_har_text("", None) == ""
    assert decode_har_text("plain", None) == "plain"
    assert decode_har_text("plain", "") == "plain"
    assert decode_har_text("@@@", "base64") == ""

    har_entry = {
        "request": {
            "method": "PUT",
            "url": "https://appserver.example/user",
            "postData": post,
        },
        "response": {
            "status": 200,
            "content": {
                "text": base64.b64encode(b'{"echo":"Privatia Rigatoni"}').decode("ascii"),
                "encoding": "base64",
            },
        },
    }
    req_text = decode_har_text(
        (har_entry["request"].get("postData") or {}).get("text", "") or "",
        (har_entry["request"].get("postData") or {}).get("encoding"),
    )
    resp_text = decode_har_text(
        (har_entry["response"].get("content") or {}).get("text", "") or "",
        (har_entry["response"].get("content") or {}).get("encoding"),
    )
    assert "Privatia Rigatoni" in req_text
    assert "Privatia Rigatoni" in resp_text

    root = Path("/tmp/baby-app-audit-sprint4-pathguard-root")
    assert is_under_directory(root / "results" / "a.json", root)
    assert is_under_directory(root, root)
    assert not is_under_directory(Path(str(root) + "-evil") / "a.json", root)

    har_dump = (repo / "scripts" / "har_dump.py").read_text(encoding="utf-8")
    assert "request_post_data" in har_dump
    assert "encode_body_text" in har_dump
    assert '["postData"]' in har_dump or "['postData']" in har_dump

    scan_src = (repo / "scripts" / "scan-synthetic-baby-data.sh").read_text(encoding="utf-8")
    assert "decode_har_text" in scan_src
    assert "is_under_directory" in scan_src
    assert "startswith(str(repo_root" not in scan_src

    print("PASS: HAR postData pack/decode, path guards, and scan wiring")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
