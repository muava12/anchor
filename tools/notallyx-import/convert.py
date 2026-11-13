#!/usr/bin/env python3
"""Convert a NotallyX backup into the files Anchor's import API takes.

Input: a folder holding the unzipped NotallyX backup — `NotallyDatabase`
(SQLite), `Images/`, `Files/`.

Output, in the folder given by --out:
  notes.json                 the body of POST /api/import/notes
  attachments/<ref>/<name>   one folder per note that has pictures

NotallyX keeps two kinds of note: a NOTE is one text body, a LIST is a JSON
array of checklist items with optional children. Anchor's editor is one Delta
document, so a NOTE becomes plain lines and a LIST becomes checklist lines.

Usage:
  python3 convert.py --backup ./out --out ./anchor
"""

from __future__ import annotations

import argparse
import json
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

# Anchor takes image and audio attachments only, so other files are left out.
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic"}


def delta_for_text(body: str) -> list[dict]:
    """Every line as its own insert, each closed by a newline."""
    text = (body or "").replace("\r\n", "\n").replace("\r", "\n")
    if not text.strip():
        return [{"insert": "\n"}]
    ops: list[dict] = []
    for line in text.rstrip("\n").split("\n"):
        ops.append({"insert": line})
        ops.append({"insert": "\n"})
    return ops


def delta_for_items(items_json: str) -> list[dict]:
    """Checklist lines, with children indented one level."""
    try:
        items = json.loads(items_json or "[]")
    except json.JSONDecodeError:
        items = []
    if not items:
        return [{"insert": "\n"}]

    def order_of(item: dict, fallback: int) -> float:
        order = item.get("order")
        return order if isinstance(order, (int, float)) else fallback

    ordered = sorted(
        enumerate(items), key=lambda pair: (order_of(pair[1], pair[0]), pair[0])
    )
    ops: list[dict] = []
    for _, item in ordered:
        attributes: dict[str, object] = {
            "list": "checked" if item.get("checked") else "unchecked",
        }
        if item.get("isChild"):
            attributes["indent"] = 1
        body = item.get("body") or ""
        ops.append({"insert": body})
        ops.append({"insert": "\n", "attributes": attributes})
    return ops


def iso(ms: object) -> str | None:
    if not isinstance(ms, (int, float)) or ms <= 0:
        return None
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).isoformat()


def label_names(labels_json: str) -> list[str]:
    try:
        labels = json.loads(labels_json or "[]")
    except json.JSONDecodeError:
        return []
    return [name for name in labels if isinstance(name, str) and name.strip()]


def pictures(images_json: str) -> list[str]:
    try:
        images = json.loads(images_json or "[]")
    except json.JSONDecodeError:
        return []
    names = []
    for image in images:
        if isinstance(image, dict):
            name = image.get("localName")
            if isinstance(name, str) and name:
                names.append(name)
    return names


def convert(backup: Path, out: Path) -> dict:
    database = backup / "NotallyDatabase"
    if not database.exists():
        raise SystemExit(f"No NotallyDatabase in {backup}")

    connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    rows = connection.execute("select * from BaseNote order by id").fetchall()

    notes: list[dict] = []
    attachments_root = out / "attachments"
    if attachments_root.exists():
        shutil.rmtree(attachments_root)
    attachments_root.mkdir(parents=True, exist_ok=True)

    skipped_files: list[str] = []
    missing_images: list[str] = []
    picture_count = 0

    for row in rows:
        note = dict(row)
        ref = f"nx-{note['id']}"
        is_list = (note.get("type") or "").upper() == "LIST"
        ops = delta_for_items(note.get("items")) if is_list else delta_for_text(note.get("body"))

        entry: dict = {
            "ref": ref,
            "title": (note.get("title") or "").strip(),
            "content": json.dumps({"ops": ops}, ensure_ascii=False),
        }
        if note.get("pinned"):
            entry["isPinned"] = True
        folder = (note.get("folder") or "NOTES").upper()
        if folder == "ARCHIVED":
            entry["isArchived"] = True
        if folder == "DELETED":
            entry["isTrashed"] = True
        names = label_names(note.get("labels"))
        if names:
            entry["tagNames"] = names
        created = iso(note.get("timestamp"))
        updated = iso(note.get("modifiedTimestamp"))
        if created:
            entry["createdAt"] = created
        if updated:
            entry["updatedAt"] = updated

        note_dir = attachments_root / ref
        for name in pictures(note.get("images")):
            suffix = Path(name).suffix.lower()
            source = backup / "Images" / name
            if suffix not in IMAGE_SUFFIXES:
                skipped_files.append(f"{ref}: {name}")
                continue
            if not source.exists():
                missing_images.append(f"{ref}: {name}")
                continue
            note_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, note_dir / name)
            picture_count += 1

        notes.append(entry)

    out.mkdir(parents=True, exist_ok=True)
    (out / "notes.json").write_text(
        json.dumps({"notes": notes}, ensure_ascii=False, indent=1), encoding="utf-8"
    )

    return {
        "notes": len(notes),
        "pictures": picture_count,
        "skipped_files": skipped_files,
        "missing_images": missing_images,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    summary = convert(args.backup, args.out)
    print(f"notes: {summary['notes']}")
    print(f"pictures copied: {summary['pictures']}")
    for line in summary["skipped_files"]:
        print(f"skipped, not an image: {line}")
    for line in summary["missing_images"]:
        print(f"missing in the backup: {line}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
