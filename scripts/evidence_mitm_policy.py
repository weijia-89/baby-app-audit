#!/usr/bin/env python3
"""Classify zero-byte .mitm files in one captures directory.

Policy (AGENTS.md Evidence retention):
- Never delete zero-byte .mitm files from failed mitmdump starts.
- Always WARN on zero-byte .mitm (kept evidence of a bad start).
- Do not ERROR on zero-byte alone: intentional empty files and true clobbers
  look the same on disk without a prior size ledger.
- Hard failures stay on missing committed network logs (see evidence-inventory.sh).
"""
from __future__ import annotations

from typing import List, Sequence, Tuple


def classify_zero_byte_mitms(
    mitm_sizes: Sequence[Tuple[str, int]],
) -> Tuple[List[str], List[str]]:
    """Return (error_names, warn_names) for zero-byte .mitm entries.

    error_names is always empty under the keep-zero-byte policy.
    """
    warns: List[str] = [name for name, size in mitm_sizes if size == 0]
    return [], warns
