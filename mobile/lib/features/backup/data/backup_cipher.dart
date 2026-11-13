import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_reader.dart' show BackupFormatException;

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
    final shortest =
        bodyStart + _algorithm.nonceLength + _algorithm.macAlgorithm.macLength;
    if (sealed.length < shortest) {
      throw const BackupFormatException('This backup is damaged.');
    }

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
