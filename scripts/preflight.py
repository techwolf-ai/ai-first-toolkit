#!/usr/bin/env python3
"""Release preflight lint for the ai-first-toolkit marketplace repo.

Catches the class of packaging bug that skips plugins during marketplace sync:
- a plugin missing one of its two required markers
- a plugin's two markers disagreeing on name or version
- a marker whose name does not match its plugin directory
- the two marketplace manifests drifting apart
- unparseable JSON
- README version badge out of sync with the CHANGELOG top entry
- the README "N plugins, M skills" line out of sync with what is on disk

Run from the repo root. Exit 0 = clean, 1 = problems found.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGINS = ROOT / "plugins"
CC_MARKET = ROOT / ".claude-plugin" / "marketplace.json"
AG_MARKET = ROOT / ".agents" / "plugins" / "marketplace.json"
README = ROOT / "README.md"
CHANGELOG = ROOT / "CHANGELOG.md"

errors: list[str] = []
warnings: list[str] = []


def load_json(path: Path):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        errors.append(f"missing file: {path.relative_to(ROOT)}")
    except json.JSONDecodeError as e:
        errors.append(f"invalid JSON in {path.relative_to(ROOT)}: {e}")
    return None


def plugin_dirs() -> list[Path]:
    return sorted(p for p in PLUGINS.iterdir() if p.is_dir())


def skill_dirs(plugin: Path) -> list[Path]:
    skills = plugin / "skills"
    if not skills.is_dir():
        return []
    return sorted(p for p in skills.iterdir() if p.is_dir())


def check_markers():
    """Every plugin needs BOTH markers (Claude Code + Antigravity), name-matched
    to its directory, and the two must agree on name and version.

    'description' is deliberately NOT compared: the Claude Code marker carries a
    longer, more detailed blurb than the Antigravity one in most plugins, so
    equality here would fail the repo rather than catch drift.
    """
    for p in plugin_dirs():
        name = p.name
        markers = {
            "Claude Code .claude-plugin/plugin.json": p / ".claude-plugin" / "plugin.json",
            "Antigravity plugin.json": p / "plugin.json",
        }
        loaded = {}
        for label, path in markers.items():
            if not path.exists():
                errors.append(f"{name}: missing {label} marker")
                continue
            data = load_json(path)
            if data is None:
                continue
            loaded[label] = data
            if data.get("name") != name:
                errors.append(
                    f"{name}: {label} name is '{data.get('name')}', expected '{name}'")
        if len(loaded) < 2:
            continue
        (cc_label, cc_data), (ag_label, ag_data) = loaded.items()
        for field in ("name", "version"):
            if cc_data.get(field) != ag_data.get(field):
                errors.append(
                    f"{name}: markers disagree on {field}: "
                    f"{cc_label} has '{cc_data.get(field)}', "
                    f"{ag_label} has '{ag_data.get(field)}'")


def market_plugin_names(market: dict) -> set[str]:
    return {e.get("name") for e in market.get("plugins", []) if e.get("name")}


def check_marketplaces():
    cc = load_json(CC_MARKET)
    ag = load_json(AG_MARKET)
    if not (cc and ag):
        return
    disk = {p.name for p in plugin_dirs()}
    cc_names = market_plugin_names(cc)
    ag_names = market_plugin_names(ag)
    if cc_names != disk:
        errors.append(
            f".claude-plugin/marketplace.json plugins {sorted(cc_names)} "
            f"!= plugin dirs {sorted(disk)}")
    if ag_names != disk:
        errors.append(
            f".agents/plugins/marketplace.json plugins {sorted(ag_names)} "
            f"!= plugin dirs {sorted(disk)}")
    if cc_names != ag_names:
        errors.append(
            "marketplace manifests disagree: "
            f"claude={sorted(cc_names)} agents={sorted(ag_names)}")


def check_version_sync():
    if not (README.exists() and CHANGELOG.exists()):
        errors.append("README.md or CHANGELOG.md missing")
        return
    readme = README.read_text()
    badge = re.search(r"version-(\d+\.\d+\.\d+)-green", readme)
    top = re.search(r"^## \[(\d+\.\d+\.\d+)\]", CHANGELOG.read_text(), re.M)
    if not badge:
        warnings.append("README version badge not found (skipped sync check)")
    elif not top:
        warnings.append("no versioned CHANGELOG heading found (skipped sync check)")
    elif badge.group(1) != top.group(1):
        errors.append(
            f"version drift: README badge {badge.group(1)} "
            f"!= CHANGELOG top {top.group(1)}")
    # The badge renders from the URL, but the alt text carries a version too and
    # is what a reader sees when images are blocked. They drifted apart once.
    alt = re.search(r"!\[v(\d+\.\d+\.\d+)\]", readme)
    if badge and alt and alt.group(1) != badge.group(1):
        errors.append(
            f"version drift: README badge alt text v{alt.group(1)} "
            f"!= badge URL {badge.group(1)}")


def check_counts():
    """The README's "N plugins, M skills" headline must match the tree.

    This line has gone stale on its own every time a skill moved or was added,
    which is a docs bug the two marker checks above cannot see.
    """
    if not README.exists():
        return
    m = re.search(r"(\d+) plugins?, (\d+) skills?", README.read_text())
    if not m:
        warnings.append('README "N plugins, M skills" line not found (skipped count check)')
        return
    plugins = plugin_dirs()
    n_plugins = len(plugins)
    n_skills = sum(len(skill_dirs(p)) for p in plugins)
    if (int(m.group(1)), int(m.group(2))) != (n_plugins, n_skills):
        errors.append(
            f"README says {m.group(1)} plugins, {m.group(2)} skills; "
            f"disk has {n_plugins} plugins, {n_skills} skills")


def main():
    check_markers()
    check_marketplaces()
    check_version_sync()
    check_counts()
    for w in warnings:
        print(f"warn: {w}")
    if errors:
        for e in errors:
            print(f"FAIL: {e}")
        print(f"\n{len(errors)} problem(s) found.")
        return 1
    plugins = plugin_dirs()
    n_skills = sum(len(skill_dirs(p)) for p in plugins)
    print(f"preflight clean: {len(plugins)} plugins, {n_skills} skills, "
          "both manifests agree, versions and counts in sync.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
