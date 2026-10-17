#!/usr/bin/env python3
"""Check committed marker-scan reports.

Default directory: results/marker-scans/
Pass another directory to check reports that are not committed yet.

--strict also loads jsonschema and checks each report against
results/synthetic-baby-data.schema.json. The lint job does not install
jsonschema, so the default path stays on the stdlib checks.
"""

import json
import sys
from pathlib import Path

METHOD = (
    "marker search of the raw local capture (request body, response body, and URL). "
    "Sanitized network logs are not searched."
)
NEGATIVE = (
    "not observed in this capture window under marker search of the raw file. "
    "This does not prove the app never sends the value."
)
POSITIVE = (
    "a high or medium name, note, or string marker was in a request or URL "
    "in this capture window."
)
FINDING_KEYS = (
    "marker_id",
    "marker_type",
    "marker_confidence",
    "method",
    "host",
    "path",
    "status",
    "vendor",
    "recipient_class",
    "side",
)


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def safe_path(value, label):
    if not isinstance(value, str) or not value:
        return f"{label} is empty"
    if value.startswith("/") or value.startswith("../") or "/../" in value or value == "..":
        return f"{label} is not a relative path: {value}"
    return None


def check_report(report, label):
    errors = []
    if not isinstance(report, dict):
        return [f"{label}: report is not an object"]
    if report.get("$schema") != "synthetic-baby-data/1.0":
        errors.append(f"{label}: bad $schema")
    if report.get("schema_version") != "1.0":
        errors.append(f"{label}: bad schema_version")
    if report.get("method") != METHOD:
        errors.append(f"{label}: method text does not match the scanner")
    path_error = safe_path(report.get("profile_source"), f"{label} profile_source")
    if path_error:
        errors.append(path_error)
    apps = report.get("apps")
    if not isinstance(apps, list):
        errors.append(f"{label}: apps is not a list")
        return errors
    if report.get("captures_scanned") != len(apps):
        errors.append(f"{label}: captures_scanned does not match apps")
    transmitted = 0
    for index, app in enumerate(apps):
        prefix = f"{label} apps[{index}]"
        if not isinstance(app, dict):
            errors.append(f"{prefix}: not an object")
            continue
        capture_error = safe_path(app.get("capture"), f"{prefix} capture")
        if capture_error:
            errors.append(capture_error)
        findings = app.get("findings")
        if not isinstance(findings, list):
            errors.append(f"{prefix}: findings is not a list")
            findings = []
        if app.get("markers_matched") != len(findings):
            errors.append(f"{prefix}: markers_matched does not match findings")
        if not isinstance(app.get("flows_scanned"), int) or app.get("flows_scanned") < 0:
            errors.append(f"{prefix}: flows_scanned is missing")
        verdict = app.get("verdict")
        observed = app.get("transmission_observed")
        if verdict == "no_transmission_detected":
            if observed is not False:
                errors.append(f"{prefix}: negative verdict with transmission_observed true")
            if app.get("claim_limit") != NEGATIVE:
                errors.append(f"{prefix}: negative claim_limit missing")
        elif verdict == "transmission_observed":
            transmitted += 1
            if observed is not True:
                errors.append(f"{prefix}: positive verdict with transmission_observed false")
            if app.get("claim_limit") != POSITIVE:
                errors.append(f"{prefix}: positive claim_limit missing")
        else:
            errors.append(f"{prefix}: unknown verdict")
        for finding in findings:
            if not isinstance(finding, dict):
                errors.append(f"{prefix}: finding is not an object")
                continue
            missing = [key for key in FINDING_KEYS if key not in finding]
            if missing:
                errors.append(f"{prefix}: finding missing {', '.join(missing)}")
            if finding.get("side") not in ("request", "response", "url"):
                errors.append(f"{prefix}: finding side is not request, response, or url")
    if report.get("apps_with_transmission") != transmitted:
        errors.append(f"{label}: apps_with_transmission does not match verdicts")
    return errors


def strict_validate(schema, report, label):
    try:
        from jsonschema import Draft7Validator
    except ImportError:
        print("ERROR: --strict needs jsonschema. Install jsonschema==4.26.0.", file=sys.stderr)
        return 1
    validator = Draft7Validator(schema)
    errors = sorted(validator.iter_errors(report), key=lambda item: list(item.path))
    if not errors:
        return 0
    for err in errors:
        path = ".".join(str(part) for part in err.path) or "(root)"
        print(f"ERROR: {label} {path}: {err.message}", file=sys.stderr)
    return 1


def main(argv):
    strict = "--strict" in argv
    args = [arg for arg in argv if arg != "--strict"]
    repo = Path(__file__).resolve().parent.parent
    schema_path = repo / "results" / "synthetic-baby-data.schema.json"
    try:
        schema = json.loads(schema_path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        return fail(f"schema file: {exc}")
    if args:
        report_dir = Path(args[0])
        if not report_dir.is_dir():
            return fail(f"report directory missing: {report_dir}")
    else:
        report_dir = repo / "results" / "marker-scans"
        if not report_dir.is_dir():
            print("marker-scan reports checked: 0")
            print("no committed marker-scan reports")
            return 0
    reports = sorted(path for path in report_dir.glob("*.json") if path.is_file())
    status = 0
    for path in reports:
        try:
            report = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            print(f"ERROR: {path.name}: {exc}", file=sys.stderr)
            status = 1
            continue
        for message in check_report(report, path.name):
            print(f"ERROR: {message}", file=sys.stderr)
            status = 1
        if strict and strict_validate(schema, report, path.name) != 0:
            status = 1
    if strict and not reports:
        try:
            from jsonschema import Draft7Validator
        except ImportError:
            return fail("--strict needs jsonschema. Install jsonschema==4.26.0.")
        Draft7Validator.check_schema(schema)
    print(f"marker-scan reports checked: {len(reports)}")
    if not reports and not args:
        print("no committed marker-scan reports")
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
