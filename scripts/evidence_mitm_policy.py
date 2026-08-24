#!/usr/bin/env python3
"""List zero-byte .mitm files in one captures directory.

Keep zero-byte .mitm files (failed mitmdump starts). Always WARN.
Do not ERROR on zero-byte alone. Missing network logs still fail
in evidence-inventory.sh (see AGENTS.md).
"""
from __future__ import annotations

from typing import List, Sequence, Tuple


def classify_zero_byte_mitms(
    mitm_sizes: Sequence[Tuple[str, int]],
) -> Tuple[List[str], List[str]]:
    """Return (error_names, warn_names) for zero-byte .mitm files.

    error_names is always empty (keep-zero-byte policy).
    Non-integer size counts as empty so WARN still runs.
    """
    warns: List[str] = []
    for name, size in mitm_sizes:
        try:
            is_empty = int(size) == 0
        except (TypeError, ValueError):
            is_empty = True
        if is_empty:
            warns.append(name)
    return [], warns
