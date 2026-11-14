# Task 3 report — Optional password (BackupCipher)

Status: DONE_WITH_CONCERNS

## Files created

- `mobile/lib/features/backup/data/backup_cipher.dart` — written verbatim from the brief (Step 3).
- `mobile/test/backup/backup_cipher_test.dart` — written verbatim from the brief (Step 1).

## Files changed

- `mobile/pubspec.yaml` — added `cryptography: ^2.7.0` under `dependencies:`, inside the existing `# Backup` block, directly after `archive: ^4.5.2` (Step 4).

No other file touched. Nothing committed.

## Brief steps followed

- Step 1 (test): done, code copied exactly.
- Step 3 (cipher): done, code copied exactly.
- Step 4 (dependency): done.
- Step 2, 5 (run `flutter test`): NOT run. This host has no Flutter/Dart toolchain, per the task rules.
- Step 6 (commit): NOT done, per the task rules. The controller commits.

## Concerns

1. **Tests not executed.** No Flutter toolchain on this host, so the 4 tests are unverified. The controller must run `cd mobile && flutter pub get && flutter test test/backup/backup_cipher_test.dart` on the remote host.
2. **`mobile/pubspec.lock` is not updated.** `cryptography` is not in the lock file and not in the local pub cache, so `flutter pub get` must run before the commit. The brief's Step 6 `git add` lists `mobile/pubspec.lock`; that file will only exist in the commit if the controller runs `pub get` first.
3. **`cryptography` 2.7.0 API not verified against the real package.** The local pub cache has no copy of the package, so `SecretBox.fromConcatenation(...)`, `MacAlgorithm.macLength`, `Pbkdf2(...).deriveKeyFromPassword(...)` and `SecretBoxAuthenticationError` are used as the brief specifies but were not checked against the resolved source. If the resolved version differs, the compile step will show it.
4. **`decrypt` on malformed input throws `RangeError`, not `WrongPasswordException`.** `sealed.sublist(saltStart, bodyStart)` and `SecretBox.fromConcatenation` fail on a truncated or non-encrypted buffer. The brief does not cover this case, so I did not add handling. Callers should check `isEncrypted` first.
5. **PBKDF2 cost.** 100000 iterations of PBKDF2-HMAC-SHA256 in pure Dart may be slow on low-end Android devices. The brief fixes this value, so I did not change it. If it is too slow in practice, `cryptography_flutter` (native implementation) is the usual fix — out of scope here.
