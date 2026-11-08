#!/usr/bin/env python3
"""HAR dump keeps query names and records flows the HAR entry list drops."""
import json
import sys
from pathlib import Path
from types import SimpleNamespace

repo = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(repo / "scripts"))
import har_dump  # noqa: E402


class HeaderMap:
    def __init__(self, pairs):
        self.pairs = list(pairs)

    def items(self, multi=True):
        return list(self.pairs)

    def get(self, key, default=""):
        for name, value in self.pairs:
            if name.lower() == key.lower():
                return value
        return default


class QueryMap:
    def __init__(self, pairs):
        self.pairs = list(pairs)

    def items(self, multi=True):
        return list(self.pairs)


def http_flow(method, url, query, response=True):
    request = SimpleNamespace(
        method=method,
        url=url,
        http_version="HTTP/1.1",
        headers=HeaderMap([("X-Android-Package", "com.naraorganics.nara")]),
        query=QueryMap(query),
        content=b"",
        timestamp_start=1_700_000_000.0,
    )
    flow = SimpleNamespace(request=request, response=None, error=None)
    if response:
        flow.response = SimpleNamespace(
            status_code=200,
            reason="OK",
            http_version="HTTP/1.1",
            headers=HeaderMap([("Content-Type", "application/json")]),
            content=b"{}",
            timestamp_end=1_700_000_001.0,
        )
    else:
        flow.error = SimpleNamespace(msg="connection reset")
    return flow


def main() -> int:
    out_dir = Path("/tmp/har-dump-flow-test")
    out_dir.mkdir(exist_ok=True)
    har_path = out_dir / "out.har"
    if har_path.exists():
        har_path.unlink()
    sidecar_path = Path(str(har_path) + ".sidecar.json")
    if sidecar_path.exists():
        sidecar_path.unlink()

    writer = har_dump.HARWriter()
    writer.configure(set())
    writer.har_output = str(har_path)
    writer.response(
        http_flow(
            "GET",
            "https://example.test/a?baby_name=SecretValue",
            [("baby_name", "SecretValue")],
        )
    )
    missed = http_flow(
        "POST",
        "https://example.test/miss?token=SecretToken",
        [("token", "SecretToken")],
        response=False,
    )
    writer.error(missed)
    writer.tcp_end(
        SimpleNamespace(
            server_conn=SimpleNamespace(sni="tcp.example.test", address=("203.0.113.10", 443), error=None),
            error=None,
        )
    )
    writer.tls_failed_client(
        SimpleNamespace(
            conn=SimpleNamespace(
                sni="tls.example.test",
                address=("203.0.113.11", 443),
                error="handshake failed",
            )
        )
    )
    writer.done()

    har = json.loads(har_path.read_text())
    query = har["log"]["entries"][0]["request"]["queryString"]
    assert query, query
    assert query[0]["name"] == "baby_name"
    assert query[0]["value"]
    assert len(har["log"]["entries"]) == 1

    sidecar = json.loads(sidecar_path.read_text())
    assert sidecar["response_less"], sidecar
    missed_req = sidecar["response_less"][0]["request"]
    assert missed_req["method"] == "POST"
    assert missed_req["queryString"][0]["name"] == "token"
    assert sidecar["response_less"][0]["error"] == "connection reset"
    assert sidecar["non_http"][0]["kind"] == "tcp"
    assert sidecar["non_http"][0]["sni"] == "tcp.example.test"
    assert sidecar["non_http"][0]["host"] == "203.0.113.10"
    assert sidecar["tls_unread"][0]["side"] == "client"
    assert sidecar["tls_unread"][0]["sni"] == "tls.example.test"
    assert sidecar["tls_unread"][0]["reason"] == "handshake failed"
    print("PASS: HAR queryString and sidecar flows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
