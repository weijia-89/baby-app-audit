#!/usr/bin/env python3
"""Unit tests for zero-byte .mitm evidence policy."""
import sys
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(repo / "scripts"))
from evidence_mitm_policy import classify_zero_byte_mitms  # noqa: E402


def main() -> int:
    errors, warns = classify_zero_byte_mitms([("only.mitm", 0)])
    assert errors == [], errors
    assert warns == ["only.mitm"], warns

    errors, warns = classify_zero_byte_mitms(
        [("failed-start.mitm", 0), ("real.mitm", 100)]
    )
    assert errors == [], errors
    assert warns == ["failed-start.mitm"], warns

    errors, warns = classify_zero_byte_mitms([("real.mitm", 50)])
    assert errors == [], errors
    assert warns == [], warns

    errors, warns = classify_zero_byte_mitms([])
    assert errors == [], errors
    assert warns == [], warns

    src = (repo / "scripts" / "evidence-inventory.sh").read_text(encoding="utf-8")
    assert "classify_zero_byte_mitms" in src
    assert "kept failed-start" in src or "failed start" in src

    print("PASS: zero-byte mitm policy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
