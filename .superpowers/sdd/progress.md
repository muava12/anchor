# Local backup — progress ledger

Plan: docs/superpowers/plans/2026-11-14-local-backup.md
Branch: feat/local-backup
Base: 5414c19

Note: this host has no Flutter. Tests are run on box-03 over SSH:
  tar czf /tmp/sync.tgz -C mobile lib test pubspec.yaml
  scp to box-03:/data/workspace/anchor-dev/
  flutter analyze && flutter test

Task 1: complete (commits 5414c19..9b86a2e, tests pass on box-03)
  - archive 4.5.2 addFile drops the entry; writer uses addArchiveFile with bytes.
Task 2: complete (tests pass on box-03)
  - Formatting: run `dart format` on box-03 once at the end for all backup files.
