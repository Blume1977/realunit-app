import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:web3dart/crypto.dart';

/// Outcome of a [SecureStorage.verifyPin] check.
///
/// [verifyPin] used to return a bare `bool`, which conflated "the entered PIN
/// is wrong" with "no PIN hash/salt is stored, so no input can ever match".
/// The latter is a storage fault, not a wrong guess — counting it as a failed
/// attempt would drive the user into the lockout cascade for a PIN they could
/// never enter correctly. [notVerifiable] lets the caller offer a recovery path
/// instead of penalising the user.
enum PinVerificationResult {
  /// The entered PIN matched the stored hash (possibly after a legacy rehash).
  correct,

  /// A hash and salt are stored but the entered PIN did not match — a real
  /// failed attempt.
  wrong,

  /// No hash and/or salt is stored, so the PIN cannot be checked at all. Not a
  /// wrong guess; must not count towards the lockout cascade.
  notVerifiable,
}

class SecureStorage {
  static const _databaseEncryptionKey = 'drift.encryption.password';
  static const _mnemonicEncryptionKey = 'wallet.mnemonic.encryption.key';
  // Atomic combined salt+hash entry ('saltHex:hash'). Preferred over the legacy
  // split [_pinHashKey]/[_pinSaltKey] pair, which a torn write could leave
  // inconsistent (see [setPinCredential]).
  static const _pinCredentialKey = 'pin.credential';
  static const _pinHashKey = 'pin.hash';
  static const _pinSaltKey = 'pin.salt';
  static const _biometricEnabledKey = 'biometric.enabled';
  static const _pinFailedAttemptsKey = 'pin.failedAttempts';
  static const _pinLockedUntilKey = 'pin.lockedUntil';

  final FlutterSecureStorage _secureStorage;

  const SecureStorage() : _secureStorage = const FlutterSecureStorage();

  /// Test-only constructor that injects a [FlutterSecureStorage] (typically a
  /// mock or the platform-interface-backed `TestFlutterSecureStoragePlatform`).
  /// Lets unit tests exercise every instance method without booting a real
  /// platform channel — the production code path stays untouched.
  @visibleForTesting
  const SecureStorage.withStorage(this._secureStorage);

  // Database

  static String getNewEncryptionKey({int keySize = 32}) {
    final keyBytes = _secureRandomBytes(keySize);
    return bytesToHex(keyBytes);
  }

  Future<String?> getEncryptionKey() => _secureStorage.read(key: _databaseEncryptionKey);

  Future<void> setEncryptionKey(String key) =>
      _secureStorage.write(key: _databaseEncryptionKey, value: key);

  /// Whether protected data is currently available on Apple platforms; `null` on
  /// platforms without the concept.
  // @no-integration-test: the difference between an absent entry and a failed
  // keychain query can only be observed on a real device; the unit tests mock
  // the plugin.
  Future<bool?> isProtectedDataAvailable() => _secureStorage.isCupertinoProtectedDataAvailable();

  /// Whether the database encryption key is verifiably absent from secure storage.
  ///
  /// A `null` read is not enough: on Apple platforms the plugin can return
  /// `null` both when the item is missing and when a keychain query failed
  /// (for example while the device is locked). This method therefore also
  /// consults protected-data availability and `containsKey`; an exception from
  /// `containsKey` propagates so the caller can treat it as unreadable.
  // @no-integration-test: the difference between an absent entry and a failed
  // keychain query can only be observed on a real device; the unit tests mock
  // the plugin.
  Future<bool> isEncryptionKeyAbsent() async {
    if (await getEncryptionKey() != null) return false;
    if (await isProtectedDataAvailable() == false) return false;
    return !await _secureStorage.containsKey(key: _databaseEncryptionKey);
  }

  // Pin

  static Uint8List generatePinSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  }

  // PIN-hash iteration count, picked for sub-second verification on mid-range
  // phones. The PIN hash + salt live in [FlutterSecureStorage] (Android Keystore
  // / iOS Keychain), so an offline brute-force first requires breaking that
  // hardware-backed boundary. Online brute-force against the app UI is bounded
  // by the lockout cascade in `verify_pin_cubit.dart`. The stronger guarantee
  // for the actual private key comes from the OS-keystore-managed mnemonic
  // encryption key — not from this hash. 250k roughly doubles the offline
  // brute-force cost vs. 100k while staying perceptibly sub-second on the
  // median target phone. Earlier 100k / 600k / 10k hashes are still accepted
  // and transparently rehashed to [_pinHashIterations].
  static const _pinHashIterations = 250000;
  static const _legacyIterationCandidates = <int>[600000, 100000, 10000];

  // Validates the salt half of a combined PIN credential before hex-decoding it,
  // so a corrupt (non-hex) value resolves to notVerifiable instead of throwing.
  static final _hexSaltPattern = RegExp(r'^[0-9a-fA-F]+$');

  static String hashPin(String pin, Uint8List salt, {int iterations = _pinHashIterations}) {
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = Pbkdf2Parameters(salt, iterations, 32);
    derivator.init(params);
    return bytesToHex(derivator.process(utf8.encode(pin)));
  }

  /// Off-main-thread variant of [hashPin]. Even at the reduced iteration count
  /// PBKDF2 dominates the visible unlock latency, so any caller reachable from
  /// the UI should await this instead of running it synchronously.
  static Future<String> hashPinAsync(
    String pin,
    Uint8List salt, {
    int iterations = _pinHashIterations,
  }) => compute(
    _hashPinIsolate,
    (pin: pin, salt: salt, iterations: iterations),
  );

  Future<String?> getPinHash() => _secureStorage.read(key: _pinHashKey);

  Future<bool> hasPinHash() async =>
      await _secureStorage.read(key: _pinCredentialKey) != null ||
      await _secureStorage.read(key: _pinHashKey) != null;

  Future<void> deletePinHash() => Future.wait([
    _secureStorage.delete(key: _pinCredentialKey),
    _secureStorage.delete(key: _pinHashKey),
    _secureStorage.delete(key: _pinSaltKey),
  ]);

  Future<Uint8List?> getPinSalt() async {
    final hex = await _secureStorage.read(key: _pinSaltKey);
    if (hex == null) return null;
    return hexToBytes(hex);
  }

  /// Writes the PIN salt+hash as a single atomic keychain entry.
  ///
  /// A PIN change over pre-existing credentials used to write hash and salt as
  /// two separate keychain round-trips; a process kill between them left a new
  /// hash paired with the old salt — both keys non-null, so [verifyPin] returned
  /// [PinVerificationResult.wrong] for every entry and drove the user into the
  /// lockout cascade with no recovery. Storing both in one value makes the write
  /// atomic: it either lands in full or not at all, so the pair can never be
  /// torn (audit F-09). The legacy split keys are cleared afterwards; if that
  /// cleanup is interrupted the combined key still takes precedence in
  /// [verifyPin] and [hasPinHash], so a leftover legacy key is never consulted
  /// and never re-opens a PIN-less state.
  Future<void> setPinCredential(Uint8List salt, String hash) async {
    await _secureStorage.write(
      key: _pinCredentialKey,
      value: '${bytesToHex(salt)}:$hash',
    );
    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _pinSaltKey);
  }

  /// Reads the stored (salt, hash) pair, preferring the atomic combined key and
  /// falling back to the legacy split keys. Returns null when neither yields a
  /// complete, well-formed pair — a storage fault the caller maps to
  /// [PinVerificationResult.notVerifiable].
  Future<(Uint8List, String)?> _readPinCredential() async {
    final combined = await _secureStorage.read(key: _pinCredentialKey);
    if (combined != null) {
      final separator = combined.indexOf(':');
      if (separator <= 0 || separator == combined.length - 1) return null;
      final saltHex = combined.substring(0, separator);
      final hash = combined.substring(separator + 1);
      // A structurally split but corrupt credential (non-hex salt) is a storage
      // fault, not a wrong guess: reject it to null so the caller steers the user
      // to recovery instead of an unbreakable retry loop.
      if (saltHex.length.isOdd || !_hexSaltPattern.hasMatch(saltHex)) return null;
      return (hexToBytes(saltHex), hash);
    }
    final hash = await getPinHash();
    final salt = await getPinSalt();
    if (hash == null || salt == null) return null;
    return (salt, hash);
  }

  Future<PinVerificationResult> verifyPin(String pin) async {
    final credential = await _readPinCredential();
    // No complete salt+hash pair stored means no entered PIN could ever match —
    // a storage fault, not a wrong guess. Report it distinctly so the caller can
    // steer the user to recovery instead of counting a lockout attempt.
    if (credential == null) return PinVerificationResult.notVerifiable;
    final (salt, hash) = credential;

    if (await hashPinAsync(pin, salt) == hash) return PinVerificationResult.correct;

    // Transparent rehash: any earlier iteration count we ever shipped is still
    // accepted exactly once, then upgraded to the current target (and migrated
    // onto the atomic credential key) so subsequent unlocks pay the fast path.
    for (final legacy in _legacyIterationCandidates) {
      if (await hashPinAsync(pin, salt, iterations: legacy) == hash) {
        final newHash = await hashPinAsync(pin, salt);
        await setPinCredential(salt, newHash);
        return PinVerificationResult.correct;
      }
    }

    return PinVerificationResult.wrong;
  }

  // Pin lockout

  Future<int> getPinFailedAttempts() async {
    final value = await _secureStorage.read(key: _pinFailedAttemptsKey);
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<void> setPinFailedAttempts(int count) =>
      _secureStorage.write(key: _pinFailedAttemptsKey, value: count.toString());

  Future<DateTime?> getPinLockedUntil() async {
    final value = await _secureStorage.read(key: _pinLockedUntilKey);
    return value != null ? DateTime.tryParse(value) : null;
  }

  Future<void> setPinLockedUntil(DateTime? until) => until != null
      ? _secureStorage.write(key: _pinLockedUntilKey, value: until.toIso8601String())
      : _secureStorage.delete(key: _pinLockedUntilKey);

  Future<void> resetPinLockout() => Future.wait([
    _secureStorage.delete(key: _pinFailedAttemptsKey),
    _secureStorage.delete(key: _pinLockedUntilKey),
  ]);

  // Biometric

  Future<bool> getIsBiometricEnabled() async =>
      await _secureStorage.read(key: _biometricEnabledKey) == 'true';

  Future<void> setIsBiometricEnabled({required bool enabled}) =>
      _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());

  Future<void> deleteBiometricEnabled() => _secureStorage.delete(key: _biometricEnabledKey);

  // Mnemonic

  Future<Uint8List> getOrCreateMnemonicKey() async {
    final existing = await _secureStorage.read(key: _mnemonicEncryptionKey);
    if (existing != null) return base64.decode(existing);
    final key = _secureRandomBytes(32);
    await _secureStorage.write(key: _mnemonicEncryptionKey, value: base64.encode(key));
    return key;
  }

  /// Removes the AES-GCM key that decrypts stored seeds. Once gone, any
  /// surviving encrypted seed is permanently undecryptable; a fresh key is
  /// lazily minted on next creation.
  // @no-integration-test: forwards to FlutterSecureStorage (Android Keystore /
  // iOS Keychain) over a platform channel; real keystore removal is only
  // verifiable on-device — the unit test mocks the plugin.
  Future<void> deleteMnemonicKey() => _secureStorage.delete(key: _mnemonicEncryptionKey);

  static String encryptSeed(Uint8List key, String plaintext) {
    final iv = _secureRandomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final ciphertext = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    return '${base64.encode(iv)}:${base64.encode(ciphertext)}';
  }

  /// Decrypts a seed produced by [encryptSeed].
  ///
  /// Every malformed / tampered input is surfaced as a typed
  /// [SeedDecryptionException] instead of the raw failure it wraps:
  ///  * a missing `:` separator (previously an uncaught [RangeError] from
  ///    `substring(0, -1)`),
  ///  * a non-base64 IV / ciphertext or non-UTF-8 plaintext (a
  ///    [FormatException]),
  ///  * a wrong key, a tampered ciphertext, or a truncated GCM tag (an
  ///    [InvalidCipherTextException]).
  ///
  /// This lets the unlock path catch one known type and show a controlled
  /// error rather than crashing on a corrupted `walletInfos.seed` row.
  /// AES-GCM rejecting a tampered ciphertext stays fully intact — this only
  /// makes the rejection *typed*, it does not weaken authentication.
  static String decryptSeed(Uint8List key, String encoded) {
    final colonIndex = encoded.indexOf(':');
    if (colonIndex < 0) {
      throw const SeedDecryptionException('missing IV separator');
    }
    try {
      final iv = base64.decode(encoded.substring(0, colonIndex));
      final ciphertext = base64.decode(encoded.substring(colonIndex + 1));
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
      return utf8.decode(cipher.process(ciphertext));
    } on InvalidCipherTextException catch (e) {
      throw SeedDecryptionException('authentication failed: ${e.message}');
    } on FormatException catch (e) {
      throw SeedDecryptionException('malformed ciphertext: ${e.message}');
    }
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }
}

String _hashPinIsolate(({String pin, Uint8List salt, int iterations}) args) =>
    SecureStorage.hashPin(args.pin, args.salt, iterations: args.iterations);

/// Thrown by [SecureStorage.decryptSeed] when the stored ciphertext cannot be
/// decrypted — because it is structurally malformed (missing separator, invalid
/// base64), was tampered with, or was written under a different key (GCM tag
/// mismatch). Lets callers on the unlock path distinguish "the stored seed is
/// corrupt" from an unrelated crash and react with a controlled recovery flow.
class SeedDecryptionException implements Exception {
  const SeedDecryptionException(this.message);

  final String message;

  @override
  String toString() => 'SeedDecryptionException: $message';
}
