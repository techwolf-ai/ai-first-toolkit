#!/usr/bin/env python3
"""Verify that quoted citations exist literally in KB files.

Reads an answer from stdin (or a file) and checks each citation block against
the actual KB files. Exits with code 1 if any quote doesn't match.

Two match passes:
  1. Strict: the quote appears character-for-character in the source file.
  2. Normalized: whitespace collapsed and markdown markers (**, *, _, `) stripped.
     Normalized-only passes are reported as PASS (normalized) so the author knows
     the citation works but isn't byte-exact.

Supports single-line and multi-line citations.

Usage:
    echo "answer text" | python3 scripts/kb-verify.py
    python3 scripts/kb-verify.py answer.md
    python3 scripts/kb-verify.py answer.md kb/
    python3 scripts/kb-verify.py --strict answer.md   # disable normalized fallback

Citation formats accepted:

    Single-line:
        > "exact quote from the file"
        > Source: kb/category/filename.md

    Multi-line (opening " on first line, closing " at the end of the last):
        > "exact quote line 1
        > exact quote line 2
        > exact quote line 3"
        > Source: kb/category/filename.md
"""

import re
import sys
from pathlib import Path


MARKDOWN_MARKERS = re.compile(r"(\*\*|\*|__|_|`)")
WHITESPACE = re.compile(r"\s+")


def find_kb_path(args: list[str]) -> Path:
    for arg in args:
        p = Path(arg)
        if p.is_dir() and (p / ".kb-config.yaml").exists():
            return p
    cwd_kb = Path.cwd() / "kb"
    if cwd_kb.is_dir():
        return cwd_kb
    return Path("kb")


def parse_citations(text: str) -> list[dict]:
    """Parse single-line and multi-line `> "..."` citation blocks.

    Single-line: the whole quote lives on one `> "..."` line.
    Multi-line:  opens with `> "...` on one line, continues on subsequent
                 `> ...` lines, and closes with a `"` at the end of the last
                 quote line. The next non-blank line must be `> Source: ...`.
    """
    citations = []
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped.startswith('> "'):
            rest = stripped[3:]
            if rest.endswith('"') and len(rest) >= 1:
                quote = rest[:-1]
                consumed = 1
            else:
                parts = [rest]
                j = i + 1
                closed = False
                while j < len(lines):
                    line_j = lines[j].strip()
                    if not line_j.startswith(">"):
                        break
                    inner = line_j[1:].lstrip()
                    if inner.endswith('"'):
                        parts.append(inner[:-1])
                        j += 1
                        closed = True
                        break
                    parts.append(inner)
                    j += 1
                if not closed:
                    i += 1
                    continue
                quote = "\n".join(parts)
                consumed = j - i

            source_idx = i + consumed
            while source_idx < len(lines) and not lines[source_idx].strip():
                source_idx += 1
            if source_idx < len(lines):
                match = re.match(r'>\s*Source:\s*(.+)', lines[source_idx].strip())
                if match:
                    citations.append({"quote": quote, "source": match.group(1).strip()})
                    i = source_idx + 1
                    continue
        i += 1
    return citations


def normalize(text: str) -> str:
    text = MARKDOWN_MARKERS.sub("", text)
    text = WHITESPACE.sub(" ", text)
    return text.strip()


def verify_citation(quote: str, source_path: Path, allow_normalized: bool) -> str:
    """Return "strict", "normalized", or "fail"."""
    if not source_path.exists():
        return "missing"
    content = source_path.read_text(encoding="utf-8")
    if quote in content:
        return "strict"
    if allow_normalized and normalize(quote) in normalize(content):
        return "normalized"
    return "fail"


def main():
    args = sys.argv[1:]
    strict = "--strict" in args
    args = [a for a in args if a != "--strict"]
    allow_normalized = not strict

    kb_path = find_kb_path(args)

    file_args = [a for a in args if Path(a).is_file()]
    if file_args:
        text = Path(file_args[0]).read_text(encoding="utf-8")
    elif not sys.stdin.isatty():
        text = sys.stdin.read()
    else:
        print("Usage: python3 scripts/kb-verify.py [--strict] [answer.md] [kb_path]", file=sys.stderr)
        print("  Or pipe answer text via stdin", file=sys.stderr)
        sys.exit(1)

    citations = parse_citations(text)

    if not citations:
        print("No citations found in input.")
        print('Expected format: > "quote"')
        print(">  Source: kb/path/file.md")
        sys.exit(0)

    all_valid = True
    normalized_count = 0
    for i, c in enumerate(citations, 1):
        source = Path(c["source"])
        if not source.is_absolute():
            source = Path.cwd() / source

        result = verify_citation(c["quote"], source, allow_normalized)
        if result == "strict":
            print(f"  [{i}] PASS: {c['source']}")
        elif result == "normalized":
            normalized_count += 1
            print(f"  [{i}] PASS (normalized): {c['source']}")
            print(f"        Quote matches after stripping markdown/whitespace.")
        elif result == "missing":
            all_valid = False
            print(f"  [{i}] FAIL: {c['source']} (file not found)")
        else:
            all_valid = False
            print(f"  [{i}] FAIL: {c['source']} (quote not found in file)")
            q = c["quote"]
            print(f"        Quote: \"{q[:80]}...\"" if len(q) > 80 else f"        Quote: \"{q}\"")

    print()
    if all_valid:
        total = len(citations)
        if normalized_count:
            print(f"All {total} citation(s) verified ({normalized_count} via normalized match).")
            print("Tip: re-copy those quotes with their original markdown for byte-exact matches.")
        else:
            print(f"All {total} citation(s) verified.")
    else:
        print("FAILED: Some citations could not be verified.")
        sys.exit(1)


if __name__ == "__main__":
    main()
