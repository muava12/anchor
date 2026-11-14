import 'dart:convert';

import 'package:anchor/features/backup/data/backup_cipher.dart';
import 'package:anchor/features/backup/data/backup_reader.dart';
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

  test('a truncated encrypted file is refused as damaged', () async {
    final sealed = await BackupCipher.encrypt(utf8.encode('x'), 'mantab');
    expect(
      () => BackupCipher.decrypt(sealed.sublist(0, 20), 'mantab'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a wrong password is refused', () async {
    final sealed = await BackupCipher.encrypt(utf8.encode('x'), 'mantab');
    expect(
      () => BackupCipher.decrypt(sealed, 'salah'),
      throwsA(isA<WrongPasswordException>()),
    );
  });
}
