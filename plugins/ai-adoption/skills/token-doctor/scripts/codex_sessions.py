"""Codex session adapter.

Codex (OpenAI) stores each session as a JSONL "rollout" at
`~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-*.jsonl`. Lines are wrapper objects
`{type, timestamp, payload}`. The types we use:

  session_meta              -> payload.cwd, payload.timestamp, payload.model_provider
  turn_context              -> payload.model (the concrete model id)
  event_msg/user_message    -> payload.message|text (first one = session title)
  event_msg/agent_message   -> payload.message|text
  response_item/message     -> payload.role + payload.content ([{type,text}] or str)

This adapter exposes the same shape session-search uses for Claude transcripts
(cwd, title, plus a (role, text) iterator for grep), so routing is a drop-in.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Iterator

CODEX_ROOT = Path.home() / ".codex" / "sessions"


def _content_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for c in content:
            if isinstance(c, dict):
                t = c.get("text") or c.get("content")
                if isinstance(t, str) and t:
                    parts.append(t)
        return "\n".join(parts)
    return ""


def iter_turns(path: Path) -> Iterator[tuple[str, str]]:
    """Yield (role, text) for the conversational turns in a rollout.

    Codex records each turn twice: a clean `event_msg` (user_message /
    agent_message) and a lower-level `response_item/message` that also carries
    system/developer preamble. We use the clean channel and fall back to
    response_item only if a rollout has no event_msg turns at all.
    """
    event_turns: list[tuple[str, str]] = []
    item_turns: list[tuple[str, str]] = []
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                p = e.get("payload") or {}
                if not isinstance(p, dict):
                    continue
                typ, ptyp = e.get("type"), p.get("type")
                if typ == "event_msg" and ptyp == "user_message":
                    txt = p.get("message") or p.get("text") or ""
                    if isinstance(txt, str) and txt:
                        event_turns.append(("user", txt))
                elif typ == "event_msg" and ptyp == "agent_message":
                    txt = p.get("message") or p.get("text") or ""
                    if isinstance(txt, str) and txt:
                        event_turns.append(("assistant", txt))
                elif typ == "response_item" and ptyp == "message":
                    txt = _content_text(p.get("content"))
                    if txt and p.get("role") in ("user", "assistant"):
                        item_turns.append((p.get("role"), txt))
    except OSError:
        return
    yield from (event_turns or item_turns)


def peek(path: Path) -> tuple[str, str]:
    """Return (cwd, first_user_line) for a rollout, reading only the head."""
    cwd = ""
    first_user = ""
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i > 120 and cwd and first_user:
                    break
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                p = e.get("payload") or {}
                if not isinstance(p, dict):
                    continue
                if not cwd and e.get("type") == "session_meta":
                    cwd = p.get("cwd", "") or ""
                if (not first_user and e.get("type") == "event_msg"
                        and p.get("type") == "user_message"):
                    txt = p.get("message") or p.get("text") or ""
                    if isinstance(txt, str) and txt.strip():
                        first_user = txt.strip().splitlines()[0]
    except OSError:
        pass
    return cwd, first_user


def iter_sessions() -> Iterator[dict]:
    """Yield session records shaped like session-search's Claude records."""
    if not CODEX_ROOT.is_dir():
        return
    for jsonl in CODEX_ROOT.glob("*/*/*/rollout-*.jsonl"):
        try:
            st = jsonl.stat()
        except OSError:
            continue
        cwd, title = peek(jsonl)
        yield {
            "kind": "codex",
            "mtime": st.st_mtime,
            "size": st.st_size,
            "title": title,
            "cwd": cwd,
            "path": str(jsonl),
        }


def _usage_from_last(lt: dict) -> dict:
    """Map a Codex last_token_usage record to the Anthropic-style usage dict the
    token-doctor pipeline expects (uncached input + cache_read split; OpenAI has
    no separate cache-write metric).
    """
    inp = int(lt.get("input_tokens") or 0)
    cached = int(lt.get("cached_input_tokens") or 0)
    out = int(lt.get("output_tokens") or 0) + int(lt.get("reasoning_output_tokens") or 0)
    return {
        "input": max(inp - cached, 0),
        "output": out,
        "cache_read": cached,
        "cache_creation": 0,
    }


def session_meta(path: Path) -> dict:
    """Return {cwd, model, start_ts} for a rollout."""
    cwd, model, start_ts = "", "", ""
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i > 200 and cwd and model:
                    break
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                p = e.get("payload") or {}
                if not isinstance(p, dict):
                    continue
                if e.get("type") == "session_meta":
                    cwd = cwd or p.get("cwd", "") or ""
                    start_ts = start_ts or p.get("timestamp", "") or e.get("timestamp", "")
                elif e.get("type") == "turn_context" and p.get("model"):
                    model = model or p["model"]
    except OSError:
        pass
    return {"cwd": cwd, "model": model, "start_ts": start_ts}


def codex_turns(path: Path, model_hint: str = "") -> list[dict]:
    """Parse a rollout into turn dicts matching the token-doctor/task-profile
    shape: {role, ts, text, tool_calls, [model, usage]}.

    Usage is attached from each `token_count` event's per-response
    `last_token_usage` to the assistant turn it belongs to.
    """
    model = model_hint
    turns: list[dict] = []
    pending_tools: list[str] = []
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                p = e.get("payload") or {}
                if not isinstance(p, dict):
                    continue
                typ, ptyp = e.get("type"), p.get("type")
                ts = e.get("timestamp")
                if typ == "turn_context" and p.get("model"):
                    model = p["model"]
                elif typ == "event_msg" and ptyp == "user_message":
                    txt = p.get("message") or p.get("text") or ""
                    if isinstance(txt, str) and txt:
                        turns.append({"role": "user", "ts": ts, "text": txt, "tool_calls": []})
                elif typ == "event_msg" and ptyp == "agent_message":
                    txt = p.get("message") or p.get("text") or ""
                    turns.append({"role": "assistant", "ts": ts,
                                  "text": txt if isinstance(txt, str) else "",
                                  "tool_calls": pending_tools})
                    pending_tools = []
                elif typ == "response_item" and ptyp == "function_call":
                    name = p.get("name") or p.get("tool_name")
                    if name:
                        pending_tools.append(name)
                elif typ == "event_msg" and ptyp == "token_count":
                    lt = (p.get("info") or {}).get("last_token_usage") or {}
                    if not lt:
                        continue
                    target = next((t for t in reversed(turns)
                                   if t["role"] == "assistant" and "usage" not in t), None)
                    if target is None:
                        target = {"role": "assistant", "ts": ts, "text": "", "tool_calls": []}
                        turns.append(target)
                    if pending_tools:
                        target["tool_calls"] = target.get("tool_calls", []) + pending_tools
                        pending_tools = []
                    target["model"] = model or "gpt-5"
                    target["usage"] = _usage_from_last(lt)
    except OSError:
        return []
    return turns
