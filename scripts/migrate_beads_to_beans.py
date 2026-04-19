#!/usr/bin/env python
"""
Migrate beads issues to beans markdown files.

Reads:
  .beads/backup/issues.jsonl      - All issues
  .beads/backup/dependencies.jsonl - Parent-child and blocking relationships
  .beads/backup/labels.jsonl      - Labels per issue

Writes:
  .beans/<prefix><nanoid>--<slug>.md  - One file per issue

Field mappings (beads -> beans):
  status:  open -> todo, closed -> completed
  type:    task/bug/feature/epic -> task/bug/feature/epic (1:1)
  priority: 1 -> critical, 2 -> high, 3 -> normal, 4 -> low
  dependencies (type=parent-child) -> parent field
  dependencies (type=blocks) -> blocked_by field

Usage:
  python scripts/migrate_beads_to_beans.py                  # dry run
  python scripts/migrate_beads_to_beans.py --write          # write files
  python scripts/migrate_beads_to_beans.py --write --open-only  # only open issues
  python scripts/migrate_beads_to_beans.py --stats          # just show stats
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #

BEADS_BACKUP = Path(".beads/backup")
BEANS_DIR = Path(".beans")
BEAN_PREFIX = "sera-"

# Beads priority (int) -> beans priority (string)
PRIORITY_MAP = {
    0: "critical",
    1: "critical",
    2: "high",
    3: "normal",
    4: "low",
}

# Beads status -> beans status
STATUS_MAP = {
    "open": "todo",
    "in_progress": "in-progress",
    "closed": "completed",
}

# Beads type -> beans type (1:1 for matching types)
TYPE_MAP = {
    "task": "task",
    "bug": "bug",
    "feature": "feature",
    "epic": "epic",
}


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #


def slugify(text: str, max_len: int = 60) -> str:
    """Convert title to URL-safe slug."""
    text = text.lower().strip()
    text = re.sub(r"[^a-z0-9\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    text = text.strip("-")
    return text[:max_len].rstrip("-")


def short_id(beads_id: str) -> str:
    """Generate a short ID from the beads ID.

    For short IDs like 'serapeum-0udg', keep the suffix.
    For long IDs like 'serapeum-1774459563297-1-1517ca57', use the hash part.
    """
    parts = beads_id.replace("serapeum-", "")
    # If it's already short (4 chars), use it
    if len(parts) <= 6:
        return parts
    # For long IDs, use the last segment (the hash)
    segments = parts.split("-")
    if len(segments) >= 3:
        return segments[-1][:6]
    return parts[:6]


def yaml_escape(value: str) -> str:
    """Escape a string for YAML if needed."""
    if not value:
        return '""'
    # If it contains special chars, quote it
    if any(c in value for c in ":#{}[]|>&*!?,\\'\"\n"):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    if value.startswith(("-", " ")) or value.endswith(" "):
        return f'"{value}"'
    return value


def format_timestamp(ts_str: str | None) -> str | None:
    """Format a timestamp string to ISO 8601."""
    if not ts_str:
        return None
    try:
        dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, AttributeError):
        return None


def build_bean_markdown(issue: dict, parent_id: str | None,
                        blocked_by: list[str], tags: list[str]) -> str:
    """Build a beans-format markdown file from a beads issue."""
    lines = ["---"]

    # Title
    lines.append(f"title: {yaml_escape(issue['title'])}")

    # Status
    status = STATUS_MAP.get(issue.get("status", "open"), "todo")
    lines.append(f"status: {status}")

    # Type
    issue_type = TYPE_MAP.get(issue.get("issue_type", "task"), "task")
    lines.append(f"type: {issue_type}")

    # Priority
    priority = PRIORITY_MAP.get(issue.get("priority", 3), "normal")
    lines.append(f"priority: {priority}")

    # Tags (from beads labels)
    if tags:
        lines.append("tags:")
        for tag in sorted(tags):
            lines.append(f"  - {tag}")

    # Timestamps
    created = format_timestamp(issue.get("created_at"))
    updated = format_timestamp(issue.get("updated_at"))
    if created:
        lines.append(f"created_at: {created}")
    if updated:
        lines.append(f"updated_at: {updated}")

    # Parent
    if parent_id:
        lines.append(f"parent: {BEAN_PREFIX}{parent_id}")

    # Blocked-by
    if blocked_by:
        lines.append("blocked_by:")
        for blocker in blocked_by:
            lines.append(f"  - {BEAN_PREFIX}{blocker}")

    lines.append("---")
    lines.append("")

    # Body: description
    description = issue.get("description", "").strip()
    if description:
        lines.append(description)

    # Append close reason if present
    close_reason = issue.get("close_reason", "").strip()
    if close_reason:
        lines.append("")
        lines.append(f"## Resolution")
        lines.append("")
        lines.append(close_reason)

    # Append notes if present
    notes = issue.get("notes", "").strip()
    if notes:
        lines.append("")
        lines.append(f"## Notes")
        lines.append("")
        lines.append(notes)

    # Append design decisions if present
    design = issue.get("design", "").strip()
    if design:
        lines.append("")
        lines.append(f"## Design")
        lines.append("")
        lines.append(design)

    # Append acceptance criteria if present
    ac = issue.get("acceptance_criteria", "").strip()
    if ac:
        lines.append("")
        lines.append(f"## Acceptance Criteria")
        lines.append("")
        lines.append(ac)

    # Provenance footer (traceability back to beads/GitHub)
    ext_ref = issue.get("external_ref")
    provenance_parts = [f"beads: `{issue['id']}`"]
    if ext_ref:
        provenance_parts.append(f"github: {ext_ref}")
    lines.append("")
    lines.append(f"<!-- migrated from {' | '.join(provenance_parts)} -->")

    lines.append("")
    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #


def main():
    write_mode = "--write" in sys.argv
    open_only = "--open-only" in sys.argv
    stats_only = "--stats" in sys.argv

    # ---- Load beads data ---- #
    issues_file = BEADS_BACKUP / "issues.jsonl"
    deps_file = BEADS_BACKUP / "dependencies.jsonl"
    labels_file = BEADS_BACKUP / "labels.jsonl"

    if not issues_file.exists():
        print(f"ERROR: {issues_file} not found. Run from project root.")
        sys.exit(1)

    # Parse issues
    issues = {}
    with open(issues_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            issue = json.loads(line)
            issues[issue["id"]] = issue

    # Parse dependencies
    parent_map = {}      # child_id -> parent_id
    blocked_by_map = {}  # issue_id -> [blocker_ids]
    if deps_file.exists():
        with open(deps_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                dep = json.loads(line)
                child_id = dep["issue_id"]
                parent_id = dep["depends_on_id"]
                dep_type = dep["type"]

                if dep_type == "parent-child":
                    parent_map[child_id] = parent_id
                elif dep_type == "blocks":
                    # In beads: issue_id is blocked by depends_on_id
                    blocked_by_map.setdefault(child_id, []).append(parent_id)

    # Parse labels -> tags
    label_map = {}  # issue_id -> [tag_strings]
    if labels_file.exists():
        with open(labels_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                lbl = json.loads(line)
                issue_id = lbl["issue_id"]
                label = lbl["label"]
                label_map.setdefault(issue_id, []).append(label)

    # ---- Stats ---- #
    total = len(issues)
    open_count = sum(1 for i in issues.values() if i["status"] == "open")
    closed_count = sum(1 for i in issues.values() if i["status"] == "closed")
    with_parent = len(parent_map)
    with_blockers = len(blocked_by_map)
    with_labels = len(label_map)

    print(f"Beads export: {total} issues ({open_count} open, {closed_count} closed)")
    print(f"  {with_parent} parent-child relationships")
    print(f"  {with_blockers} issues with blockers")
    print(f"  {with_labels} issues with labels")
    print()

    if stats_only:
        # Show type breakdown
        type_counts = {}
        for i in issues.values():
            t = i.get("issue_type", "unknown")
            type_counts[t] = type_counts.get(t, 0) + 1
        print("By type:")
        for t, c in sorted(type_counts.items()):
            print(f"  {t}: {c}")

        # Show priority breakdown
        pri_counts = {}
        for i in issues.values():
            p = i.get("priority", "?")
            pri_counts[p] = pri_counts.get(p, 0) + 1
        print("By priority:")
        for p, c in sorted(pri_counts.items()):
            print(f"  {p}: {c}")
        return

    # ---- Build ID mapping (beads_id -> beans short_id) ---- #
    id_map = {}
    used_ids = set()
    for beads_id in issues:
        sid = short_id(beads_id)
        # Handle collisions
        if sid in used_ids:
            counter = 2
            while f"{sid}{counter}" in used_ids:
                counter += 1
            sid = f"{sid}{counter}"
        used_ids.add(sid)
        id_map[beads_id] = sid

    # ---- Generate bean files ---- #
    to_write = []
    skipped = 0

    for beads_id, issue in issues.items():
        if open_only and issue["status"] != "open":
            skipped += 1
            continue

        bean_id = id_map[beads_id]
        slug = slugify(issue["title"])
        filename = f"{BEAN_PREFIX}{bean_id}--{slug}.md"

        # Resolve parent
        parent_beads_id = parent_map.get(beads_id)
        parent_bean_id = id_map.get(parent_beads_id) if parent_beads_id else None

        # Resolve blockers
        blocker_beads_ids = blocked_by_map.get(beads_id, [])
        blocker_bean_ids = [id_map[bid] for bid in blocker_beads_ids if bid in id_map]

        # Resolve tags from labels
        raw_labels = label_map.get(beads_id, [])
        # Convert beads labels to beans tags
        # e.g. "priority:high" -> skip (we have priority field)
        #      "area:server" -> "server"
        #      "bug" -> "bug" (but we have type field)
        tags = []
        for label in raw_labels:
            # Skip labels that duplicate structured fields
            if label.startswith("priority:") or label.startswith("complexity:") or label.startswith("impact:"):
                continue
            if label in ("bug", "enhancement"):
                continue
            # area:server -> server, source:pr-review -> pr-review
            if ":" in label:
                tags.append(label.split(":", 1)[1])
            else:
                tags.append(label)
        # Deduplicate
        tags = sorted(set(tags))

        content = build_bean_markdown(
            issue, parent_bean_id, blocker_bean_ids, tags
        )

        to_write.append((filename, content, issue["status"]))

    # ---- Output ---- #
    if open_only:
        print(f"Skipped {skipped} closed issues (--open-only)")
    print(f"Generated {len(to_write)} bean files")
    print()

    if not write_mode:
        # Dry run - show first 5 files
        print("=== DRY RUN (showing first 5 files) ===")
        print("Run with --write to create files.")
        print()
        for filename, content, status in to_write[:5]:
            print(f"--- {filename} [{status}] ---")
            # Show first 25 lines
            for line in content.split("\n")[:25]:
                print(f"  {line}")
            print(f"  ... ({len(content.split(chr(10)))} lines total)")
            print()
        return

    # Write mode
    beans_dir = BEANS_DIR
    if not beans_dir.exists():
        print(f"Creating {beans_dir}/")
        beans_dir.mkdir(parents=True)

    written = 0
    for filename, content, _ in to_write:
        filepath = beans_dir / filename
        filepath.write_text(content, encoding="utf-8")
        written += 1

    print(f"Wrote {written} bean files to {beans_dir}/")
    print()
    print("Next steps:")
    print("  1. Install beans: go install github.com/hmans/beans@latest")
    print("  2. Run: beans check            # validate the migrated data")
    print("  3. Run: beans list --ready      # see what's unblocked")
    print("  4. Review and adjust as needed")
    print("  5. Remove .beads/ when satisfied")


if __name__ == "__main__":
    main()
