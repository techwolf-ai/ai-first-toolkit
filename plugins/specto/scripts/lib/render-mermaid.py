#!/usr/bin/env python3
"""Render a mermaid dependency graph from a JSON ticket list (stdin → stdout).

Input: JSON array of objects shaped like

    {"id": "M1-SE1", "version": "V-Agent", "blocked_by": ["..."], "short_label": "..."}

``version`` may be ``V-Agent`` / ``V-Console`` / ``V-plus`` and selects the node
colour. ``short_label`` is optional and shown on a second line of the node.

Output: a ``flowchart LR`` mermaid source on stdout.

Exit: ``0`` with source on stdout; ``1`` on empty / unparseable input.
"""
from __future__ import annotations

import json
import re
import sys


VERSION_CLASS = {
    "V-Agent": "vagent",
    "V-Console": "vconsole",
    "V-plus": "vplus",
}

CLASSDEFS = (
    "    classDef vagent fill:#bbdefb,stroke:#1976d2,color:#000\n"
    "    classDef vconsole fill:#c8e6c9,stroke:#388e3c,color:#000\n"
    "    classDef vplus fill:#ffe0b2,stroke:#f57c00,color:#000\n"
)


def _node_id(ticket_id: str) -> str:
    """``M1-SE1`` → ``M1_SE1`` (mermaid identifiers can't contain ``-``)."""
    return re.sub(r"[^A-Za-z0-9_]", "_", ticket_id)


def _escape_label(text: str) -> str:
    """Escape characters that would break a mermaid ``["..."]`` label.

    Mermaid reads ``"`` / ``[`` / ``]`` as quoting and node-shape delimiters,
    so an unescaped one in an id or short_label produces malformed source.
    Mermaid's ``#NNN;`` / ``#quot;`` entity syntax renders them literally.
    """
    return (str(text).replace("&", "#amp;")
                     .replace('"', "#quot;")
                     .replace("[", "#91;")
                     .replace("]", "#93;"))


def render(tickets: list[dict]) -> str:
    lines = ["flowchart LR"]
    for t in tickets:
        nid = _node_id(t["id"])
        cls = VERSION_CLASS.get(t.get("version", ""), "vagent")
        label = _escape_label(t["id"])
        if t.get("short_label"):
            label = f"{label}<br/>{_escape_label(t['short_label'])}"
        lines.append(f'    {nid}["{label}"]:::{cls}')
    for t in tickets:
        nid = _node_id(t["id"])
        for parent in t.get("blocked_by", []) or []:
            lines.append(f"    {_node_id(parent)} --> {nid}")
    return "\n".join(lines) + "\n" + CLASSDEFS


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError) as exc:
        print(f"render-mermaid: input unparseable: {exc}", file=sys.stderr)
        return 1
    if not data:
        print("render-mermaid: empty input", file=sys.stderr)
        return 1
    if not isinstance(data, list) or not all(
        isinstance(t, dict) and t.get("id") for t in data
    ):
        print("render-mermaid: input must be a JSON array of objects, each with an 'id'",
              file=sys.stderr)
        return 1
    sys.stdout.write(render(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
