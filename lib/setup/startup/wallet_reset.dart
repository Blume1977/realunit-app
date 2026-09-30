import 'package:shared_preferences/shared_preferences.dart';
import 'package:realunit_wallet/packages/repository/settings_repository.dart';
import 'package:realunit_wallet/packages/storage/database.dart';
import 'package:realunit_wallet/packages/storage/secure_storage.dart';
import 'package:realunit_wallet/setup/routing/boot_navigation.dart';
import 'package:realunit_wallet/setup/routing/referral_pending_code.dart';

/// Wipes local wallet data so the next start is a clean first boot.
///
/// The database is deleted last: a database without a key is the state that
/// leads back into this reset, so an interrupted run stays repeatable.
// @no-integration-test: touches FlutterSecureStorage, SharedPreferences and
// on-disk SQLCipher paths via injectable seams; unit tests cover the order and
// the absent-key gate without a real keystore or documents directory.
Future<void> resetWalletData({
  SecureStorage secureStorage = const SecureStorage(),
  Future<SharedPreferences> Function() preferences = SharedPreferences.getInstance,
  Future<void> Function() deleteDatabaseFiles = AppDatabase.deleteDatabaseFiles,
}) async {
  if (!await secureStorage.isEncryptionKeyAbsent()) return;

  final settings = SettingsRepository(await preferences());
  await settings.removeCurrentWalletId();
  settings.termsAccepted = false;

  clearPendingPaymentDeeplink();
  await clearPendingReferralCode();

  await secureStorage.deletePinHash();
  await secureStorage.deleteBiometricEnabled();
  await secureStorage.resetPinLockout();
  await secureStorage.deleteMnemonicKey();

  await deleteDatabaseFiles();
}
