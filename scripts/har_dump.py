"""
Minimal HAR dump addon for mitmproxy.
Usage: mitmdump -s scripts/har_dump.py --set har_output=output.har -nr input.mitm
"""
import json
import base64
from datetime import datetime
from mitmproxy import ctx

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
                "entries": []
            }
        }

    def response(self, flow):
        # Only handle HTTP flows
        if not getattr(flow, 'response', None):
            return

        req_start = flow.request.timestamp_start or 0
        resp_end = flow.response.timestamp_end or req_start
        started = datetime.fromtimestamp(req_start).isoformat()
        total_time = max(0, int((resp_end - req_start) * 1000))

        # Request headers
        req_headers = [{"name": k, "value": v} for k, v in flow.request.headers.items(multi=True)]

        # Response headers
        resp_headers = [{"name": k, "value": v} for k, v in flow.response.headers.items(multi=True)]

        # Request body
        req_body_size = len(flow.request.content) if flow.request.content else 0
        req_body = ""
        if flow.request.content:
            try:
                req_body = flow.request.content.decode('utf-8')
            except UnicodeDecodeError:
                req_body = base64.b64encode(flow.request.content).decode('ascii')

        # Response body
        resp_body_size = len(flow.response.content) if flow.response.content else 0
        resp_body = ""
        resp_encoding = ""
        if flow.response.content:
            try:
                resp_body = flow.response.content.decode('utf-8')
            except UnicodeDecodeError:
                resp_body = base64.b64encode(flow.response.content).decode('ascii')
                resp_encoding = "base64"

        entry = {
            "startedDateTime": started,
            "time": total_time,
            "request": {
                "method": flow.request.method,
                "url": flow.request.url,
                "httpVersion": flow.request.http_version,
                "headers": req_headers,
                "queryString": [],
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
        self.har["log"]["entries"].append(entry)

    def done(self):
        output_file = getattr(ctx.options, "har_output", "")
        if output_file:
            with open(output_file, "w") as f:
                json.dump(self.har, f, indent=2)


addons = [HARWriter()]
