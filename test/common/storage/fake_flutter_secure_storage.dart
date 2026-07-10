import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake keyed by (key, synchronizable) — mirrors how the macOS
/// keychain treats local-only and synchronizable items as distinct.
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> local = {};
  final Map<String, String> synced = {};

  Map<String, String> _bucket(AppleOptions? mOptions) {
    final isSynced = mOptions != null && mOptions.synchronizable;
    return isSynced ? synced : local;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _bucket(mOptions)[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _bucket(mOptions).remove(key);
    } else {
      _bucket(mOptions)[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _bucket(mOptions).remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _bucket(mOptions).containsKey(key);
}
