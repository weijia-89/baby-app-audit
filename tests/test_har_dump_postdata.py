#!/usr/bin/env python3
"""Fail if HAR postData helper drops plaintext request bodies, or if har_dump omits postData."""
import sys
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(repo / "scripts"))
from har_postdata import request_post_data  # noqa: E402


def main() -> int:
    body = b'{"firstName":"Privatia Rigatoni","location":"US"}'
    post = request_post_data("application/json", body)
    assert post is not None, "expected postData for non-empty body"
    assert post["text"] == body.decode("utf-8"), post
    assert "Privatia Rigatoni" in post["text"]
    assert request_post_data("application/json", b"") is None
    assert request_post_data("application/json", None) is None

    har_dump = (repo / "scripts" / "har_dump.py").read_text(encoding="utf-8")
    assert "request_post_data" in har_dump, "har_dump.py must call request_post_data"
    assert '["postData"]' in har_dump or "['postData']" in har_dump, (
        "har_dump.py must assign request['postData'] so scan-synthetic-baby-data.sh can read bodies"
    )
    print("PASS: request_post_data keeps plaintext JSON bodies and har_dump wires postData")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
