#!/usr/bin/env python3
"""Generate the packaged QIDI profile catalog from a pinned Orca source tree."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def load_profiles(root: Path):
    records = []
    for path in sorted(root.rglob("*.json")):
        try:
            values = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            continue
        if not isinstance(values, dict):
            continue
        name = values.get("name")
        profile_type = values.get("type")
        if not name or not profile_type:
            continue
        records.append((path, values))
    return records


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: generate_qidi_profile_catalog.py "
            "<orcaslicer-source-root> <output-json>",
            file=sys.stderr,
        )
        return 2

    source_root = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    profiles_root = source_root / "resources" / "profiles"
    qidi_root = profiles_root / "Qidi"
    if not qidi_root.is_dir():
        raise SystemExit(f"missing pinned Orca QIDI profiles: {qidi_root}")

    records = load_profiles(profiles_root)
    by_name = {}
    for path, values in records:
        by_name.setdefault(str(values["name"]), []).append((path, values))

    included = {}
    pending = []
    for path, values in records:
        try:
            path.relative_to(qidi_root)
        except ValueError:
            continue
        included[path] = values
        pending.append(values)

    while pending:
        values = pending.pop()
        parent_name = values.get("inherits")
        if not isinstance(parent_name, str) or not parent_name:
            continue
        for path, parent in by_name.get(parent_name, []):
            if path in included:
                continue
            included[path] = parent
            pending.append(parent)

    entries = []
    for path in sorted(included):
        relative = path.relative_to(profiles_root).as_posix()
        entries.append(
            {
                "assetPath": "pinned-orca/resources/profiles/" + relative,
                "values": included[path],
            }
        )

    types = {}
    for entry in entries:
        profile_type = str(entry["values"].get("type", "unknown"))
        types[profile_type] = types.get(profile_type, 0) + 1

    machine_names = [
        str(entry["values"].get("name", ""))
        for entry in entries
        if entry["values"].get("type") == "machine"
    ]
    process_names = [
        str(entry["values"].get("name", ""))
        for entry in entries
        if entry["values"].get("type") == "process"
    ]
    filament_names = [
        str(entry["values"].get("name", ""))
        for entry in entries
        if entry["values"].get("type") == "filament"
    ]
    if not any("X-Plus 4" in name for name in machine_names):
        raise SystemExit("generated catalog has no QIDI X-Plus 4 machine")
    if not any("0.20" in name for name in process_names):
        raise SystemExit("generated catalog has no 0.20 QIDI process")
    if not any("PLA" in name for name in filament_names):
        raise SystemExit("generated catalog has no QIDI PLA filament")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(entries, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "profiles": len(entries),
                "types": types,
                "output": str(output),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
