#!/usr/bin/env python3
"""Markdown → ADF (Atlassian Document Format) JSON converter.

Reads Markdown on stdin, writes ADF on stdout. Handles ATX headings, paragraphs,
bullet/ordered lists, GitHub-flavoured task lists (``- [x]`` / ``- [ ]``),
blockquotes, fenced code blocks, and inline marks (``**strong**``, `` `code` ``,
``[text](url)``, bare URLs). Tables, nested lists, images, and HTML are not
supported. Used by ``create-ticket.sh`` and ``comment.sh`` to auto-convert ticket
descriptions / comments before they reach ``acli``.

Exit: ``0`` with ADF on stdout; ``1`` on empty input.
"""
from __future__ import annotations

import json
import re
import sys
import uuid


_TASK_LINE_RE = re.compile(r'^[-*]\s+\[([ xX])\]\s+(.+)$')


_INLINE_RE = re.compile(
    r'\*\*([^*\n]+?)\*\*'          # **bold**
    r'|`([^`\n]+?)`'               # `code`
    r'|\[([^\]]+)\]\(([^)]+)\)'    # [text](url)
    r'|(https?://[^\s)\]]+)'       # bare URL
)


def parse_inline(text: str) -> list[dict]:
    """Tokenize a single paragraph's text into ADF inline nodes."""
    result: list[dict] = []
    pos = 0
    for m in _INLINE_RE.finditer(text):
        if m.start() > pos:
            chunk = text[pos:m.start()]
            if chunk:
                result.append({"type": "text", "text": chunk})
        if m.group(1) is not None:
            result.append({"type": "text", "text": m.group(1),
                           "marks": [{"type": "strong"}]})
        elif m.group(2) is not None:
            result.append({"type": "text", "text": m.group(2),
                           "marks": [{"type": "code"}]})
        elif m.group(3) is not None:
            result.append({"type": "text", "text": m.group(3),
                           "marks": [{"type": "link",
                                      "attrs": {"href": m.group(4)}}]})
        elif m.group(5) is not None:
            url = m.group(5).rstrip('.,;)')
            result.append({"type": "text", "text": url,
                           "marks": [{"type": "link",
                                      "attrs": {"href": url}}]})
            # Trailing punctuation stripped off the URL belongs to the
            # surrounding prose — leave it for the next plain-text chunk
            # rather than dropping it with `pos = m.end()`.
            pos = m.start(5) + len(url)
            continue
        pos = m.end()
    if pos < len(text):
        tail = text[pos:]
        if tail:
            result.append({"type": "text", "text": tail})
    if not result:
        result.append({"type": "text", "text": text})
    return result


def _is_block_start(stripped: str) -> bool:
    if not stripped:
        return True
    if stripped.startswith('>') or stripped.startswith('#'):
        return True
    if stripped.startswith('```'):
        return True
    if re.match(r'^[-*]\s', stripped):
        return True
    if re.match(r'^\d+\.\s', stripped):
        return True
    return False


def md_to_adf(markdown_text: str) -> dict:
    """Convert Markdown text to an ADF doc dict (top-level ``{"type": "doc", ...}``)."""
    lines = markdown_text.split('\n')
    content: list[dict] = []
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if not stripped:
            i += 1
            continue

        # Fenced code block — ```lang ... ```
        if stripped.startswith('```'):
            language = stripped[3:].strip() or None
            body_lines: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                body_lines.append(lines[i])
                i += 1
            i += 1  # consume the closing ```
            attrs = {"language": language} if language else {}
            content.append({
                "type": "codeBlock",
                "attrs": attrs,
                "content": [{"type": "text", "text": '\n'.join(body_lines)}]
                if body_lines else [],
            })
            continue

        # Blockquote (potentially multi-line)
        if stripped.startswith('> '):
            quote_text = stripped[2:]
            while i + 1 < len(lines) and lines[i + 1].strip().startswith('> '):
                i += 1
                quote_text += ' ' + lines[i].strip()[2:]
            content.append({
                "type": "blockquote",
                "content": [{"type": "paragraph",
                             "content": parse_inline(quote_text)}],
            })
            i += 1
            continue

        # Heading
        m = re.match(r'^(#{1,6})\s+(.+)$', stripped)
        if m:
            level = len(m.group(1))
            content.append({
                "type": "heading",
                "attrs": {"level": level},
                "content": parse_inline(m.group(2)),
            })
            i += 1
            continue

        # Task list (GitHub checkbox syntax — `- [x] foo` / `- [ ] foo`).
        # Must precede the plain bullet branch so ``[x]`` doesn't leak as
        # literal text. Per Jira's ADF schema, ``taskItem.content`` holds
        # *inline* runs directly — not wrapped in a ``paragraph`` — or acli
        # rejects the payload with ``INVALID_INPUT``.
        if _TASK_LINE_RE.match(stripped):
            task_items: list[dict] = []
            while i < len(lines):
                tm = _TASK_LINE_RE.match(lines[i].strip())
                if not tm:
                    break
                state = "DONE" if tm.group(1).lower() == "x" else "TODO"
                task_items.append({
                    "type": "taskItem",
                    "attrs": {"localId": str(uuid.uuid4()), "state": state},
                    "content": parse_inline(tm.group(2)),
                })
                i += 1
            content.append({
                "type": "taskList",
                "attrs": {"localId": str(uuid.uuid4())},
                "content": task_items,
            })
            continue

        # Bullet list
        if re.match(r'^[-*]\s', stripped):
            items: list[dict] = []
            while i < len(lines):
                s = lines[i].strip()
                if not re.match(r'^[-*]\s', s):
                    break
                item_text = re.sub(r'^[-*]\s+', '', s)
                items.append({
                    "type": "listItem",
                    "content": [{"type": "paragraph",
                                 "content": parse_inline(item_text)}],
                })
                i += 1
            content.append({"type": "bulletList", "content": items})
            continue

        # Ordered list
        if re.match(r'^\d+\.\s', stripped):
            items = []
            while i < len(lines):
                s = lines[i].strip()
                if not re.match(r'^\d+\.\s', s):
                    break
                item_text = re.sub(r'^\d+\.\s+', '', s)
                items.append({
                    "type": "listItem",
                    "content": [{"type": "paragraph",
                                 "content": parse_inline(item_text)}],
                })
                i += 1
            content.append({"type": "orderedList",
                            "attrs": {"order": 1},
                            "content": items})
            continue

        # Plain paragraph (accumulate continuation lines)
        para_lines = [stripped]
        j = i + 1
        while j < len(lines):
            s = lines[j].strip()
            if not s or _is_block_start(s):
                break
            para_lines.append(s)
            j += 1
        content.append({"type": "paragraph",
                        "content": parse_inline(' '.join(para_lines))})
        i = j

    return {"version": 1, "type": "doc", "content": content}


def main() -> int:
    md = sys.stdin.read()
    if not md.strip():
        print("md_to_adf: input is empty", file=sys.stderr)
        return 1
    json.dump(md_to_adf(md), sys.stdout, ensure_ascii=False)
    sys.stdout.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
