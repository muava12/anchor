# Local backup and restore — design

Date: 2026-11-14
Status: approved for planning

## Problem

Anchor keeps every note on a server. If the server is unreachable, gone, or the
account is lost, the phone holds the only copy and there is no way to move it
anywhere. NotallyX solves this with a ZIP backup the person owns.

## Goal

A backup file the person controls, and a restore that puts it back:

- One ZIP holding every note, tag and attachment.
- The folder is chosen by the person, like NotallyX.
- Manual backup shows no dialog: a spinner in the row, a toast when it ends.
- Automatic backup runs silently.
- Optional password.
- Restore works on the same account and on a different one.

## What already exists

- Drift tables `Notes`, `NoteAttachments`, `NoteRevisions`, `Tags`, `NoteTags`.
- `Notes` carries sync state: `isSynced`, `version`, `localRev`,
  `syncedTitle`, `syncedContent`, `syncedBackground`, `syncedState`.
- `NoteAttachments` carries `localPath`, `syncStatus`, `serverAttachmentId`.
- `archive` is already a transitive dependency; `file_picker`, `share_plus`
  and `path_provider` are direct dependencies.
- Kotlin plugins follow one pattern: `PhotoConverterPlugin`, `ShareFolderPlugin`.
- Settings has sections Appearance, Editor, Security.

## How the server treats a pushed note

From `server/src/sync/sync-apply.service.ts`, `applyNote`:

| Note id on server | `baseVersion` sent | Result |
| --- | --- | --- |
| no | absent | created |
| no | present | `denied` — a purged note is not resurrected |
| yes | absent | `conflict` |
| yes | different from `version` | `conflict` |
| yes | equal to `version` | applied |

A conflict keeps the server copy and records the pushed text as a conflict
revision, so nothing is lost. `Note.id` is a global primary key, so a note id
that belongs to another account is `denied`, not duplicated.

This is why the backup must carry `version`, and why a restore into a
different account needs new ids.

## Design

### File

```
anchor-backup-2026-11-14_0530.zip
├── manifest.json
├── notes.json
└── attachments/<attachmentId>.<ext>
```

`manifest.json`:

```json
{
  "format": 1,
  "app": "anchor",
  "appVersion": "0.22.2",
  "createdAt": "2026-11-14T05:30:00Z",
  "notes": 61,
  "attachments": 6
}
```

No account email, no server URL. The file carries nothing that names the
person.

`notes.json` is one object holding the tags and the notes. It is written one
note at a time, so memory stays flat however many notes there are:

```json
{
  "tags": [{"id": "uuid", "name": "molagis", "color": "#aabbcc"}],
  "notes": [
    {
      "id": "uuid",
      "title": "…",
      "content": "{\"ops\":[…]}",
      "isPinned": false,
      "isArchived": false,
      "background": null,
      "state": "active",
      "updatedAt": "2026-11-13T10:44:43.093Z",
      "version": 7,
      "reminderAt": null,
      "reminderRecurrence": null,
      "tagIds": ["uuid"],
      "attachments": [
        {
          "id": "uuid",
          "type": "image",
          "originalFilename": "photo.jpg",
          "mimeType": "image/jpeg",
          "fileSize": 70877,
          "position": 0,
          "file": "attachments/uuid.jpg"
        }
      ]
    }
  ]
}
```

Tags come first because a note may only reference a tag the server already
knows.

### What is not backed up

| Left out | Why |
| --- | --- |
| `NoteRevisions` | Server history; would double the file |
| Shares and permissions | Per account, meaningless elsewhere |
| `isSynced`, `localRev`, `synced*` | Rebuilt on restore |
| `reminderSlot` | An OS notification id, valid on one phone only |

### Restore

Two modes, chosen by the person on the restore screen. The file does not say
which account it came from, so the app cannot choose.

**Pulihkan** — the same account. Ids and `version` are kept. The server's own
rules then decide: an unchanged note applies, a note edited after the backup
conflicts and the server copy wins, a note deleted on the server stays deleted.
A note the server has never seen is `denied` and dropped, because a kept
`version` says the server once had it.

**Impor salinan** — any account, any server. Every note and attachment gets a
fresh UUID and `version` is cleared, so the server creates them. Nothing can
collide, and nothing is denied.

Both modes, in one transaction:

1. Delete every local note, tag and attachment row.
2. Insert the backup's rows.
3. Set `isSynced = false`, `localRev = 0`, `serverAttachmentId = null`,
   `syncStatus = 'pending_upload'`.
4. Write attachment bytes to the app's attachment folder and set `localPath`.

The confirmation dialog names the mode and the counts, and says that local
notes not in the backup are removed.

Restore does not preserve the original creation date. The server stamps
`createdAt` and `updatedAt` when it creates a note, so every restored note
shows the day of the restore until it is edited. The backup keeps `updatedAt`
for the local row, so the list order on the phone is right before the first
sync.

### Encryption

Optional. AES-256-GCM over the finished ZIP.

- Key: PBKDF2-HMAC-SHA256, 100 000 iterations, 16-byte random salt.
- The file starts with a 16-byte magic header so restore knows to ask for a
  password before reading anything.
- A wrong password fails the GCM tag check and reports "Password salah" without
  touching local data.

### Backup folder

A new Kotlin plugin, `BackupFolderPlugin`, follows `ShareFolderPlugin`:

- `pickFolder` → `ACTION_OPEN_DOCUMENT_TREE`, then
  `takePersistableUriPermission`.
- `writeFile(uri, name, bytes)` → `DocumentFile.createFile`.
- `listFiles(uri)` and `deleteFile(uri)` for the retention rule.

The chosen URI is stored in preferences and stays valid across restarts. No new
Dart dependency.

### Manual backup

- The row shows a spinner and "Membuat backup…" in place. No dialog, no sheet.
- The job lives in an app-scoped provider, so leaving Settings does not stop it.
- It does not survive the app being killed. A foreground service would, and is
  not worth the weight.
- On success a toast names the file. On failure a toast names the reason.

### Automatic backup

- Checked when the app opens: if the last backup is older than the period, run.
- Period 1–31 days, default 7. Kept files 1–10, default 3.
- Retention only counts files the app wrote itself, named `anchor-auto-*`.
  A manual backup is never deleted by the retention rule.
- Silent: no toast, no spinner. A failure is written to the log only.
- Skipped when the library is empty and a previous backup exists, so an empty
  library never overwrites a good file.

### Performance

- No compression. Notes are small text and attachments are already compressed;
  deflate would burn CPU for nothing.
- Attachments are copied with `File.copy` into the ZIP stream, never read whole
  into memory.
- The whole job runs in a background isolate, so the UI never stutters.

### Settings

A new **Backup** section:

- `Backup sekarang` — spinner in the row while it runs.
- `Pulihkan` — file picker, then a mode choice, then a confirmation.
- `Backup otomatis` toggle, period, kept files.
- `Password` — optional, with a confirm field.
- `Folder` — shows the chosen folder, tap to change.
- The newest local backups, each with a share button.

## Testing

- Round trip: export, import, every field equal.
- Restore in "Pulihkan" mode keeps ids and versions.
- Restore in "Impor salinan" mode gives new ids and clears versions.
- Encrypted round trip; wrong password leaves local data untouched.
- A corrupt ZIP reports an error and changes nothing.
- An empty library exports a valid file.
- 1 000 notes export without the isolate's memory growing with the note count.
- Retention deletes the oldest file and keeps the newest N.

## Dependencies

- `archive` — already present transitively, promoted to a direct dependency.
- `cryptography` — new, pure Dart, used only when a password is set.

## Out of scope

- Backing up note revisions.
- Restoring into a server that already holds notes with the same ids under
  another account — "Impor salinan" covers it by using new ids.
- Surviving an app kill during a manual backup.
