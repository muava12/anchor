#!/usr/bin/env python3
"""Send a converted NotallyX backup to an Anchor server.

Reads `notes.json` and `attachments/` made by `convert.py`, signs in to Anchor,
posts the notes in batches, then uploads each note's pictures.

Usage:
  python3 import_to_anchor.py --dir ./anchor --url https://anchor.example \\
      --email you@example.com --password '…'

Add --dry-run to print what would be sent and stop.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

# The server takes at most 50 notes in one call.
BATCH = 50


def request(
    url: str,
    method: str = "GET",
    token: str | None = None,
    body: dict | None = None,
    timeout: int = 120,
) -> dict:
    data = None
    headers: dict[str, str] = {}
    if body is not None:
        data = json.dumps(body).encode()
        headers["content-type"] = "application/json"
    if token:
        headers["authorization"] = f"Bearer {token}"
    call = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(call, timeout=timeout) as answer:
            payload = answer.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:400]
        raise SystemExit(f"{method} {url} failed: {error.code} {detail}") from error


def upload(url: str, token: str, note_id: str, path: Path, position: int) -> None:
    boundary = f"----anchor{uuid.uuid4().hex}"
    head = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="position"\r\n\r\n'
        f"{position}\r\n"
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
        f"Content-Type: {mimetypes.guess_type(path.name)[0] or 'application/octet-stream'}\r\n\r\n"
    ).encode()
    tail = f"\r\n--{boundary}--\r\n".encode()
    body = head + path.read_bytes() + tail
    call = urllib.request.Request(
        f"{url}/api/import/notes/{note_id}/attachments",
        data=body,
        method="POST",
        headers={
            "authorization": f"Bearer {token}",
            "content-type": f"multipart/form-data; boundary={boundary}",
        },
    )
    try:
        with urllib.request.urlopen(call, timeout=180) as answer:
            answer.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:300]
        print(f"  picture {path.name} failed: {error.code} {detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True, type=Path)
    parser.add_argument("--url", required=True)
    parser.add_argument("--email", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    url = args.url.rstrip("/")
    payload = json.loads((args.dir / "notes.json").read_text(encoding="utf-8"))
    notes = payload["notes"]

    if args.dry_run:
        print(f"would send {len(notes)} notes to {url}")
        for note in notes[:3]:
            print(f"  {note['ref']}: {note.get('title')!r}")
        return 0

    session = request(
        f"{url}/api/auth/login",
        method="POST",
        body={"email": args.email, "password": args.password},
    )
    token = session.get("access_token") or session.get("accessToken")
    if not token:
        raise SystemExit(f"No token in the sign-in answer: {sorted(session)}")

    created: dict[str, str] = {}
    for start in range(0, len(notes), BATCH):
        batch = notes[start : start + BATCH]
        answer = request(
            f"{url}/api/import/notes", method="POST", token=token, body={"notes": batch}
        )
        for result in answer.get("results", []):
            status = result.get("status")
            if status in {"created", "remapped"} and result.get("noteId"):
                created[result["ref"]] = result["noteId"]
            else:
                print(f"  {result.get('ref')}: {status} {result.get('error') or ''}")
        print(f"sent {start + len(batch)} of {len(notes)}")

    pictures = 0
    for ref, note_id in created.items():
        folder = args.dir / "attachments" / ref
        if not folder.is_dir():
            continue
        for position, path in enumerate(sorted(folder.iterdir())):
            upload(url, token, note_id, path, position)
            pictures += 1

    print(f"notes imported: {len(created)}")
    print(f"pictures uploaded: {pictures}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
