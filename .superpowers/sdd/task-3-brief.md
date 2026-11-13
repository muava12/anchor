### Task 3: Optional password

**Files:**
- Create: `lib/features/backup/data/backup_cipher.dart`
- Test: `test/backup/backup_cipher_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `abstract final class BackupCipher { static bool isEncrypted(List<int> bytes); static Future<List<int>> encrypt(List<int> plain, String password); static Future<List<int>> decrypt(List<int> sealed, String password); }`
  - `class WrongPasswordException implements Exception {}`

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_cipher_test.dart
import 'dart:convert';

import 'package:anchor/features/backup/data/backup_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a plain file is not encrypted', () {
    expect(BackupCipher.isEncrypted(utf8.encode('PK')), isFalse);
  });

  test('an encrypted file round trips', () async {
    final plain = utf8.encode('the notes');
    final sealed = await BackupCipher.encrypt(plain, 'mantab');

    expect(BackupCipher.isEncrypted(sealed), isTrue);
    expect(sealed, isNot(plain));
    expect(await BackupCipher.decrypt(sealed, 'mantab'), plain);
  });

  test('the same input encrypts differently each time', () async {
    final plain = utf8.encode('the notes');
    final first = await BackupCipher.encrypt(plain, 'mantab');
    final second = await BackupCipher.encrypt(plain, 'mantab');
    expect(first, isNot(second));
  });

  test('a wrong password is refused', () async {
    final sealed = await BackupCipher.encrypt(utf8.encode('x'), 'mantab');
    expect(
      () => BackupCipher.decrypt(sealed, 'salah'),
      throwsA(isA<WrongPasswordException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_cipher_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the cipher**

```dart
// lib/features/backup/data/backup_cipher.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

/// AES-256-GCM over the finished zip, with the key stretched from the password.
///
/// Layout: 16-byte magic, 16-byte salt, then nonce + ciphertext + tag.
abstract final class BackupCipher {
  static final List<int> _magic = utf8.encode('ANCHORBK') + List.filled(8, 0);
  static const int _saltLength = 16;
  static const int _iterations = 100000;

  static final _algorithm = AesGcm.with256bits();

  static bool isEncrypted(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  static Future<List<int>> encrypt(List<int> plain, String password) async {
    final salt = _randomBytes(_saltLength);
    final key = await _keyFrom(password, salt);
    final box = await _algorithm.encrypt(plain, secretKey: key);
    return [..._magic, ...salt, ...box.concatenation()];
  }

  static Future<List<int>> decrypt(List<int> sealed, String password) async {
    final saltStart = _magic.length;
    final bodyStart = saltStart + _saltLength;
    final salt = sealed.sublist(saltStart, bodyStart);
    final key = await _keyFrom(password, salt);

    final box = SecretBox.fromConcatenation(
      sealed.sublist(bodyStart),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    try {
      return await _algorithm.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    }
  }

  static Future<SecretKey> _keyFrom(String password, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
```

- [ ] **Step 4: Add the dependency**

In `mobile/pubspec.yaml`, under `dependencies:`, add `cryptography: ^2.7.0`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd mobile && flutter pub get && flutter test test/backup/backup_cipher_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/features/backup/data/backup_cipher.dart mobile/test/backup/backup_cipher_test.dart
git commit -m "feat: seal a backup with a password"
```

---

