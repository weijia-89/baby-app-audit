"""Write a HAR file from mitmproxy flows.

Usage: mitmdump -s scripts/har_dump.py --set har_output=output.har -nr input.mitm

Flows with a response become HAR entries. Flows with no response, raw TCP or
UDP flows, and TLS handshake failures are written beside the HAR as
`<har>.sidecar.json`. mitmproxy is imported only when a dump is running.
"""
import json
from datetime import datetime, timezone
from pathlib import Path
import sys

# Let mitmdump import helpers next to this file.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from har_postdata import encode_body_text, request_post_data  # noqa: E402


def query_string(flow):
    request = getattr(flow, "request", None)
    query = getattr(request, "query", None) if request is not None else None
    if query is None or not hasattr(query, "items"):
        return []
    return [{"name": name, "value": value} for name, value in query.items(multi=True)]


def header_list(headers):
    if headers is None or not hasattr(headers, "items"):
        return []
    return [{"name": name, "value": value} for name, value in headers.items(multi=True)]


def _address(conn):
    if conn is None:
        return None, None
    address = getattr(conn, "address", None) or getattr(conn, "peername", None)
    if isinstance(address, tuple) and address:
        host = address[0]
        port = address[1] if len(address) > 1 else None
        return host, port
    return None, None


def _error_text(err):
    if err is None:
        return None
    msg = getattr(err, "msg", None)
    if isinstance(msg, str):
        return msg
    if isinstance(err, str):
        return err
    return str(err)


class HARWriter:
    def load(self, loader):
        loader.add_option(
            name="har_output",
            typespec=str,
            default="",
            help="Path to write the HAR output file",
        )

    def configure(self, updates):
        self.har = {
            "log": {
                "version": "1.2",
                "creator": {"name": "mitmproxy-har-dump", "version": "1.0"},
                "entries": [],
            }
        }
        self.response_less = []
        self.non_http = []
        self.tls_unread = []
        self._seen = set()

    def _output_path(self):
        explicit = getattr(self, "har_output", "")
        if explicit:
            return explicit
        try:
            from mitmproxy import ctx
        except ImportError:
            return ""
        return getattr(ctx.options, "har_output", "") or ""

    def _remember(self, flow):
        key = id(flow)
        if key in self._seen:
            return False
        self._seen.add(key)
        return True

    def _request_view(self, flow):
        req = flow.request
        content = getattr(req, "content", None)
        body_size = len(content) if content else 0
        headers = getattr(req, "headers", None)
        content_type = ""
        if headers is not None and hasattr(headers, "get"):
            content_type = headers.get("Content-Type", "")
        view = {
            "method": req.method,
            "url": req.url,
            "headers": header_list(headers),
            "queryString": query_string(flow),
            "bodySize": body_size,
        }
        post_data = request_post_data(content_type, content)
        if post_data is not None:
            view["postData"] = post_data
        return view

    def _record_response_less(self, flow):
        if not getattr(flow, "request", None):
            return
        if not self._remember(flow):
            return
        self.response_less.append({
            "request": self._request_view(flow),
            "error": _error_text(getattr(flow, "error", None)),
        })

    def response(self, flow):
        # Handle HTTP flows only. A flow with no response is kept in the sidecar.
        if not getattr(flow, "response", None):
            self._record_response_less(flow)
            return

        req_start = flow.request.timestamp_start or 0
        if req_start == 0:
            return
        resp_end = flow.response.timestamp_end or req_start
        started = datetime.fromtimestamp(req_start, tz=timezone.utc).isoformat()
        total_time = max(0, int((resp_end - req_start) * 1000))

        req_headers = header_list(flow.request.headers)
        resp_headers = header_list(flow.response.headers)

        req_body_size = len(flow.request.content) if flow.request.content else 0
        post_data = request_post_data(
            flow.request.headers.get("Content-Type", ""),
            flow.request.content,
        )

        resp_body_size = len(flow.response.content) if flow.response.content else 0
        resp_body = ""
        resp_encoding = ""
        if flow.response.content:
            resp_body, enc = encode_body_text(flow.response.content)
            resp_encoding = enc or ""

        entry = {
            "startedDateTime": started,
            "time": total_time,
            "request": {
                "method": flow.request.method,
                "url": flow.request.url,
                "httpVersion": flow.request.http_version,
                "headers": req_headers,
                "queryString": query_string(flow),
                "cookies": [],
                "headersSize": -1,
                "bodySize": req_body_size,
            },
            "response": {
                "status": flow.response.status_code,
                "statusText": flow.response.reason,
                "httpVersion": flow.response.http_version,
                "headers": resp_headers,
                "cookies": [],
                "content": {
                    "size": resp_body_size,
                    "mimeType": flow.response.headers.get("Content-Type", ""),
                    "text": resp_body,
                    "encoding": resp_encoding,
                },
                "redirectURL": flow.response.headers.get("Location", ""),
                "headersSize": -1,
                "bodySize": resp_body_size,
            },
            "cache": {},
            "timings": {
                "send": 0,
                "wait": 0,
                "receive": 0,
            },
        }
        if post_data is not None:
            entry["request"]["postData"] = post_data
        self.har["log"]["entries"].append(entry)

    def error(self, flow):
        if getattr(flow, "response", None):
            return
        self._record_response_less(flow)

    def tcp_end(self, flow):
        self._record_non_http(flow, "tcp")

    def udp_end(self, flow):
        self._record_non_http(flow, "udp")

    def _record_non_http(self, flow, kind):
        server = getattr(flow, "server_conn", None)
        host, port = _address(server)
        self.non_http.append({
            "kind": kind,
            "sni": getattr(server, "sni", None) if server is not None else None,
            "host": host,
            "port": port,
            "reason": _error_text(getattr(flow, "error", None)),
        })

    def tls_failed_client(self, data):
        self._record_tls(data, "client")

    def tls_failed_server(self, data):
        self._record_tls(data, "server")

    def _record_tls(self, data, side):
        conn = getattr(data, "conn", None)
        host, port = _address(conn)
        self.tls_unread.append({
            "side": side,
            "sni": getattr(conn, "sni", None) if conn is not None else None,
            "host": host,
            "port": port,
            "reason": _error_text(getattr(conn, "error", None) if conn is not None else None),
        })

    def done(self):
        output_file = self._output_path()
        if not output_file:
            return
        with open(output_file, "w") as handle:
            json.dump(self.har, handle, indent=2)
        sidecar = {
            "response_less": getattr(self, "response_less", []),
            "non_http": getattr(self, "non_http", []),
            "tls_unread": getattr(self, "tls_unread", []),
        }
        with open(output_file + ".sidecar.json", "w") as handle:
            json.dump(sidecar, handle, indent=2)


addons = [HARWriter()]
