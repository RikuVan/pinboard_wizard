import 'package:flutter/foundation.dart';
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
    'pinboard_credentials',
    'ai_settings',
    'backup_s3_config',
    'github_notes_config',
    'github_pat_token',
  ];

  static const MacOsOptions _localOptions = MacOsOptions();
  static const MacOsOptions _syncedOptions = MacOsOptions(synchronizable: true);

  final FlutterSecureStorage _storage;
  bool _syncEnabled = false;

  AppSecureStorage({FlutterSecureStorage storage = const FlutterSecureStorage()})
    : _storage = storage;

  /// Whether credentials are read from / written to the iCloud-synced set.
  bool get syncEnabled => _syncEnabled;

  MacOsOptions get _current => _syncEnabled ? _syncedOptions : _localOptions;

  /// Loads the persisted sync flag. Must be awaited during app setup before
  /// any dependent service reads credentials.
  Future<void> init() async {
    try {
      final value = await _storage.read(key: syncFlagKey, mOptions: _localOptions);
      _syncEnabled = value == 'true';
    } catch (e) {
      debugPrint(
        'AppSecureStorage: failed to read sync flag, defaulting to local-only: $e',
      );
      _syncEnabled = false;
    }
  }

  Future<String?> read(String key) => _storage.read(key: key, mOptions: _current);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, mOptions: _current);

  Future<void> delete(String key) => _storage.delete(key: key, mOptions: _current);

  Future<bool> containsKey(String key) =>
      _storage.containsKey(key: key, mOptions: _current);

  /// Enables or disables iCloud sync, migrating all [syncedKeys].
  ///
  /// Enabling: an existing synced value (from another Mac) wins over the
  /// local one; otherwise the local value is pushed up. Local-only copies are
  /// deleted afterwards (safe: local deletes never propagate).
  ///
  /// Disabling: synced values are snapshotted into local-only items. The
  /// synchronizable originals are LEFT UNTOUCHED — deleting a synchronizable
  /// item propagates the deletion to every other Mac.
  ///
  /// The flag flips only after every key migrates; the migration is
  /// idempotent, so a partial failure leaves the toggle unchanged and retry
  /// is safe.
  Future<void> setSyncEnabled(bool enabled) async {
    if (enabled == _syncEnabled) {
      return;
    }
    try {
      if (enabled) {
        for (final key in syncedKeys) {
          final synced = await _storage.read(key: key, mOptions: _syncedOptions);
          final local = await _storage.read(key: key, mOptions: _localOptions);
          if (synced == null && local != null) {
            await _storage.write(key: key, value: local, mOptions: _syncedOptions);
          }
          if (local != null) {
            await _storage.delete(key: key, mOptions: _localOptions);
          }
        }
      } else {
        for (final key in syncedKeys) {
          final synced = await _storage.read(key: key, mOptions: _syncedOptions);
          if (synced != null) {
            await _storage.write(key: key, value: synced, mOptions: _localOptions);
          }
        }
      }
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
  }
}

class AppSecureStorageException implements Exception {
  final String message;

  const AppSecureStorageException(this.message);

  @override
  String toString() => 'AppSecureStorageException: $message';
}
