import 'package:flutter/foundation.dart';
import 'package:pinboard_wizard/src/common/storage/credential_keys.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Central keychain access for all credential storage.
///
/// Owns the macOS keychain `synchronizable` attribute (iCloud Keychain sync).
/// A keychain item is either local-only or synchronizable — the attribute is
/// part of the item's identity, so all reads and writes must agree on it.
/// This class is the single place that decides which set is active.
class AppSecureStorage {
  /// Local-only flag key. NEVER synchronizable (chicken-and-egg).
  static const String syncFlagKey = 'secrets_sync_enabled';

  /// Every keychain key that participates in iCloud sync migration.
  /// Add new credential keys here when introducing new secret types.
  static const List<String> syncedKeys = [
    CredentialKeys.pinboardCredentials,
    CredentialKeys.aiSettings,
    CredentialKeys.backupS3Config,
    CredentialKeys.githubNotesConfig,
    CredentialKeys.githubPatToken,
  ];

  static const MacOsOptions _localOptions = MacOsOptions();
  static const MacOsOptions _syncedOptions = MacOsOptions(synchronizable: true);

  final FlutterSecureStorage _storage;
  bool _syncEnabled = false;

  AppSecureStorage({this._storage = const FlutterSecureStorage()});

  /// Whether credentials are read from / written to the iCloud-synced set.
  bool get syncEnabled => _syncEnabled;

  MacOsOptions get _current => _syncEnabled ? _syncedOptions : _localOptions;

  /// Loads the persisted sync flag. Must be awaited during app setup before
  /// any dependent service reads credentials.
  Future<void> init() async {
    try {
      final value = await _storage.read(
        key: syncFlagKey,
        mOptions: _localOptions,
      );
      _syncEnabled = value == 'true';
    } catch (e) {
      debugPrint(
        'AppSecureStorage: failed to read sync flag, defaulting to local-only: $e',
      );
      _syncEnabled = false;
    }
  }

  Future<String?> read(String key) =>
      _storage.read(key: key, mOptions: _current);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, mOptions: _current);

  Future<void> delete(String key) =>
      _storage.delete(key: key, mOptions: _current);

  Future<bool> containsKey(String key) =>
      _storage.containsKey(key: key, mOptions: _current);

  /// Enables or disables iCloud sync, migrating all [syncedKeys].
  ///
  /// Enabling is ordered around a single commit point:
  ///
  /// 1. Every local-only value missing from the synced set is pushed up (an
  ///    existing synced value from another Mac wins).
  /// 2. COMMIT POINT: the sync flag is persisted and [syncEnabled] flips.
  ///    Any failure up to and including this write throws, leaves the flag
  ///    off and every local copy intact — the migration is idempotent, so
  ///    retry is safe.
  /// 3. The migrated local copies are deleted as best-effort cleanup. The
  ///    flag and the synced set are already consistent, so a failure here is
  ///    only logged, never thrown: a leftover local copy is dormant (all
  ///    reads and writes now target the synced set) and local deletes never
  ///    propagate.
  ///
  /// Disabling: synced values are snapshotted into local-only items, then
  /// the flag is persisted. The synchronizable originals are LEFT UNTOUCHED
  /// — deleting a synchronizable item propagates the deletion to every
  /// other Mac.
  Future<void> setSyncEnabled(bool enabled) async {
    if (enabled == _syncEnabled) {
      return;
    }
    final localKeys = <String>[];
    try {
      if (enabled) {
        // Phase 1: push every local-only value missing from the synced set.
        for (final key in syncedKeys) {
          final local = await _storage.read(key: key, mOptions: _localOptions);
          if (local == null) {
            continue;
          }
          localKeys.add(key);
          final synced = await _storage.read(
            key: key,
            mOptions: _syncedOptions,
          );
          if (synced == null) {
            await _storage.write(
              key: key,
              value: local,
              mOptions: _syncedOptions,
            );
          }
        }
      } else {
        for (final key in syncedKeys) {
          final synced = await _storage.read(
            key: key,
            mOptions: _syncedOptions,
          );
          if (synced != null) {
            await _storage.write(
              key: key,
              value: synced,
              mOptions: _localOptions,
            );
          }
        }
      }
      // Commit point: nothing before this line changed observable state.
      await _storage.write(
        key: syncFlagKey,
        value: enabled ? 'true' : 'false',
        mOptions: _localOptions,
      );
      _syncEnabled = enabled;
    } catch (e) {
      throw AppSecureStorageException(
        'Failed to ${enabled ? 'enable' : 'disable'} credential sync: $e',
      );
    }
    if (enabled) {
      // Phase 2: best-effort cleanup of the migrated local copies. The
      // enable already committed, so a failure here must not throw.
      try {
        for (final key in localKeys) {
          await _storage.delete(key: key, mOptions: _localOptions);
        }
      } catch (e) {
        debugPrint(
          'AppSecureStorage: failed to delete local copies after enabling '
          'sync (leftover copies are dormant): $e',
        );
      }
    }
  }
}

class AppSecureStorageException implements Exception {
  final String message;

  const AppSecureStorageException(this.message);

  @override
  String toString() => 'AppSecureStorageException: $message';
}
