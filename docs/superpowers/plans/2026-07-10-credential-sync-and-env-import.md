# Credential Sync & Env Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Share all five credential groups across Macs via iCloud Keychain (opt-in toggle) and support one-time credential import from a `.env` file.

**Architecture:** A new `AppSecureStorage` centralizes all keychain access and owns the per-item `synchronizable` attribute plus enable/disable migration. The four credential services are refactored to inject it. A new `EnvImportService` parses `.env` content and applies recognized variables through the existing services. A new "Sync" tab in Settings hosts the toggle and import flow.

**Tech Stack:** Flutter 3.44.4 (via `fvm`), `flutter_secure_storage` 10.3.1 (already latest — verified on pub.dev 2026-07-10; no upgrade needed), new dep `file_selector` ^1.0.3, `bloc`/`flutter_bloc`, `mocktail`/`mockito` for tests.

**Spec:** `docs/superpowers/specs/2026-07-10-credential-sync-and-env-import-design.md`

## Global Constraints

- macOS desktop only; run tests with `fvm flutter test <path>`, analyze with `fvm flutter analyze`, format with `fvm dart format .`.
- Keychain keys (existing, MUST NOT change): `pinboard_credentials`, `ai_settings`, `backup_s3_config`, `github_notes_config`, `github_pat_token`.
- Sync flag keychain key: `secrets_sync_enabled` — ALWAYS stored local-only (never synchronizable).
- Sync toggle default OFF. Enabling: synced value wins over local; local-only copies deleted after adoption. Disabling: snapshot synced values to local-only; NEVER delete synchronizable items (deletion propagates to other Macs).
- Env import: explicit action only; env value always wins; keys absent from file are untouched; unrecognized lines ignored and counted.
- Recognized env variables (exact names): `PINBOARD_API_TOKEN`, `OPENAI_API_KEY`, `JINA_API_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET`, `S3_FILE_PATH`, `GITHUB_PAT`, `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_BRANCH`, `GITHUB_NOTES_PATH`.
- `flutter_secure_storage` 10.3.1 API (verified): `read`/`write`/`delete`/`containsKey` each take `mOptions: AppleOptions?`; `MacOsOptions extends AppleOptions` and has `synchronizable` (default `false`).
- Skip project-wide formatters/linters/test-suite during tasks; Task 10 runs them once.

---

### Task 1: `AppSecureStorage` core + migration tests

**Files:**
- Create: `lib/src/common/storage/app_secure_storage.dart`
- Create: `test/common/storage/fake_flutter_secure_storage.dart`
- Test: `test/common/storage/app_secure_storage_test.dart`

**Interfaces:**
- Consumes: `package:flutter_secure_storage/flutter_secure_storage.dart` (v10.3.1).
- Produces (later tasks rely on these exact members):
  - `class AppSecureStorage` with:
    - `AppSecureStorage({FlutterSecureStorage storage = const FlutterSecureStorage()})`
    - `Future<void> init()`
    - `bool get syncEnabled`
    - `Future<void> setSyncEnabled(bool enabled)`
    - `Future<String?> read(String key)`
    - `Future<void> write(String key, String value)`
    - `Future<void> delete(String key)`
    - `Future<bool> containsKey(String key)`
    - `static const List<String> syncedKeys`
  - `class AppSecureStorageException implements Exception` with `final String message`.
  - Test fake: `class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage` exposing `final Map<String, String> local` and `final Map<String, String> synced`.

- [ ] **Step 1: Write the failing tests**

Create `test/common/storage/fake_flutter_secure_storage.dart`:

```dart
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
```

Create `test/common/storage/app_secure_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';

import 'fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage storage;

  setUp(() {
    fake = FakeFlutterSecureStorage();
    storage = AppSecureStorage(storage: fake);
  });

  group('init', () {
    test('defaults to sync disabled when no flag stored', () async {
      await storage.init();
      expect(storage.syncEnabled, isFalse);
    });

    test('loads persisted sync flag from local-only entry', () async {
      fake.local['secrets_sync_enabled'] = 'true';
      await storage.init();
      expect(storage.syncEnabled, isTrue);
    });
  });

  group('read/write/delete with sync disabled', () {
    setUp(() async => storage.init());

    test('writes land in the local bucket only', () async {
      await storage.write('pinboard_credentials', 'secret');
      expect(fake.local['pinboard_credentials'], 'secret');
      expect(fake.synced.containsKey('pinboard_credentials'), isFalse);
    });

    test('reads ignore dormant synced items', () async {
      fake.synced['pinboard_credentials'] = 'from-other-mac';
      expect(await storage.read('pinboard_credentials'), isNull);
    });

    test('delete removes only the local item', () async {
      fake.local['ai_settings'] = 'a';
      fake.synced['ai_settings'] = 'b';
      await storage.delete('ai_settings');
      expect(fake.local.containsKey('ai_settings'), isFalse);
      expect(fake.synced['ai_settings'], 'b');
    });

    test('containsKey checks the active bucket', () async {
      fake.local['ai_settings'] = 'a';
      expect(await storage.containsKey('ai_settings'), isTrue);
      expect(await storage.containsKey('pinboard_credentials'), isFalse);
    });
  });

  group('enabling sync', () {
    setUp(() async => storage.init());

    test('pushes local-only values into the synced set', () async {
      fake.local['pinboard_credentials'] = 'mine';
      await storage.setSyncEnabled(true);
      expect(fake.synced['pinboard_credentials'], 'mine');
      expect(fake.local.containsKey('pinboard_credentials'), isFalse);
    });

    test('synced value wins when both exist', () async {
      fake.local['pinboard_credentials'] = 'mine';
      fake.synced['pinboard_credentials'] = 'from-other-mac';
      await storage.setSyncEnabled(true);
      expect(fake.synced['pinboard_credentials'], 'from-other-mac');
      expect(fake.local.containsKey('pinboard_credentials'), isFalse);
      expect(await storage.read('pinboard_credentials'), 'from-other-mac');
    });

    test('persists the flag local-only and flips reads to synced set', () async {
      await storage.setSyncEnabled(true);
      expect(storage.syncEnabled, isTrue);
      expect(fake.local['secrets_sync_enabled'], 'true');
      expect(fake.synced.containsKey('secrets_sync_enabled'), isFalse);
      await storage.write('ai_settings', 'x');
      expect(fake.synced['ai_settings'], 'x');
    });

    test('migrates every known key', () async {
      for (final key in AppSecureStorage.syncedKeys) {
        fake.local[key] = 'value-$key';
      }
      await storage.setSyncEnabled(true);
      for (final key in AppSecureStorage.syncedKeys) {
        expect(fake.synced[key], 'value-$key');
        expect(fake.local.containsKey(key), isFalse);
      }
    });
  });

  group('disabling sync', () {
    setUp(() async {
      await storage.init();
      await storage.setSyncEnabled(true);
    });

    test('snapshots synced values to local WITHOUT deleting synced items', () async {
      fake.synced['pinboard_credentials'] = 'shared';
      await storage.setSyncEnabled(false);
      expect(storage.syncEnabled, isFalse);
      expect(fake.local['pinboard_credentials'], 'shared');
      // CRITICAL: synced item must survive — deletion would propagate to
      // every other Mac via iCloud.
      expect(fake.synced['pinboard_credentials'], 'shared');
    });

    test('subsequent writes stay local and do not touch the synced set', () async {
      fake.synced['pinboard_credentials'] = 'shared';
      await storage.setSyncEnabled(false);
      await storage.write('pinboard_credentials', 'local-edit');
      expect(fake.local['pinboard_credentials'], 'local-edit');
      expect(fake.synced['pinboard_credentials'], 'shared');
    });
  });

  test('setSyncEnabled is a no-op when state already matches', () async {
    await storage.init();
    fake.local['pinboard_credentials'] = 'mine';
    await storage.setSyncEnabled(false);
    expect(fake.local['pinboard_credentials'], 'mine');
    expect(fake.synced, isEmpty);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fvm flutter test test/common/storage/app_secure_storage_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'pinboard_wizard/src/common/storage/app_secure_storage.dart'` (file does not exist yet).

- [ ] **Step 3: Implement `AppSecureStorage`**

Create `lib/src/common/storage/app_secure_storage.dart`:

```dart
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
    } catch (_) {
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fvm flutter test test/common/storage/app_secure_storage_test.dart`
Expected: PASS (all tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/src/common/storage/app_secure_storage.dart test/common/storage/
git commit -m "feat: add AppSecureStorage with iCloud keychain sync migration"
```

---

### Task 2: Register in locator; refactor `FlutterSecureSecretsStorage`

**Files:**
- Modify: `lib/src/service_locator.dart`
- Modify: `lib/src/pinboard/flutter_secure_secrets_storage.dart`
- Modify: `lib/src/pinboard/credentials_service.dart` (constructor only)
- Test: `test/pinboard/flutter_secure_secrets_storage_test.dart` (create)

**Interfaces:**
- Consumes: `AppSecureStorage` from Task 1 (`read(String)`, `write(String, String)`, `delete(String)`, `containsKey(String)`).
- Produces:
  - `FlutterSecureSecretsStorage({required AppSecureStorage storage})` implementing the existing `SecretStorage` interface (`read()`, `save(Credentials)`, `clear()`), plus `Future<bool> hasCredentials()`.
  - `CredentialsService({required SecretStorage storage})` (fallback default removed).
  - Locator registers `AppSecureStorage` (initialized) before dependents.

- [ ] **Step 1: Write the failing test**

Create `test/pinboard/flutter_secure_secrets_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/pinboard/flutter_secure_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';

import '../common/storage/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage appStorage;
  late FlutterSecureSecretsStorage storage;

  setUp(() async {
    fake = FakeFlutterSecureStorage();
    appStorage = AppSecureStorage(storage: fake);
    await appStorage.init();
    storage = FlutterSecureSecretsStorage(storage: appStorage);
  });

  test('save and read round-trips credentials as JSON', () async {
    await storage.save(const Credentials(apiKey: 'user:abcdef0123456789'));
    final result = await storage.read();
    expect(result, const Credentials(apiKey: 'user:abcdef0123456789'));
    expect(fake.local['pinboard_credentials'], contains('user:abcdef0123456789'));
  });

  test('read returns null when nothing stored', () async {
    expect(await storage.read(), isNull);
  });

  test('read returns null on corrupt JSON', () async {
    fake.local['pinboard_credentials'] = 'not-json';
    expect(await storage.read(), isNull);
  });

  test('clear removes stored credentials', () async {
    await storage.save(const Credentials(apiKey: 'user:abcdef0123456789'));
    await storage.clear();
    expect(await storage.read(), isNull);
    expect(await storage.hasCredentials(), isFalse);
  });

  test('hasCredentials reflects stored state', () async {
    expect(await storage.hasCredentials(), isFalse);
    await storage.save(const Credentials(apiKey: 'user:abcdef0123456789'));
    expect(await storage.hasCredentials(), isTrue);
  });

  test('credentials written while synced are read back through synced set', () async {
    await appStorage.setSyncEnabled(true);
    await storage.save(const Credentials(apiKey: 'user:abcdef0123456789'));
    expect(fake.synced.containsKey('pinboard_credentials'), isTrue);
    expect(await storage.read(), const Credentials(apiKey: 'user:abcdef0123456789'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/pinboard/flutter_secure_secrets_storage_test.dart`
Expected: FAIL — `FlutterSecureSecretsStorage` has no `storage` named parameter.

- [ ] **Step 3: Refactor `FlutterSecureSecretsStorage`**

Replace the entire contents of `lib/src/pinboard/flutter_secure_secrets_storage.dart` with:

```dart
import 'dart:convert';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

class FlutterSecureSecretsStorage implements SecretStorage {
  static const String _credentialsKey = 'pinboard_credentials';

  final AppSecureStorage _storage;

  FlutterSecureSecretsStorage({required AppSecureStorage storage})
    : _storage = storage;

  @override
  Future<Credentials?> read() async {
    try {
      final credentialsJson = await _storage.read(_credentialsKey);

      if (credentialsJson == null || credentialsJson.isEmpty) {
        return null;
      }

      final Map<String, dynamic> credentialsMap =
          json.decode(credentialsJson) as Map<String, dynamic>;

      return Credentials.fromJson(credentialsMap);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> save(Credentials credentials) async {
    try {
      final credentialsJson = json.encode(credentials.toJson());
      await _storage.write(_credentialsKey, credentialsJson);
    } catch (e) {
      throw SecureStorageException('Failed to save credentials: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(_credentialsKey);
    } catch (e) {
      throw SecureStorageException('Failed to clear credentials: $e');
    }
  }

  Future<bool> hasCredentials() async {
    try {
      final credentialsJson = await _storage.read(_credentialsKey);
      return credentialsJson != null && credentialsJson.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

class SecureStorageException implements Exception {
  final String message;

  const SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}
```

Note: the old `clearAll()` (which called `deleteAll()` — dangerous now that local and synced items coexist) and `readAll()` are deliberately removed. They have no callers (`grep -r "clearAll\|readAll" lib test` shows only unrelated `clearAllAiSettings`/`clearAllNotes`/GitHub `clearAll`).

- [ ] **Step 4: Remove the default-constructor fallback in `CredentialsService`**

In `lib/src/pinboard/credentials_service.dart`, replace:

```dart
  CredentialsService({SecretStorage? storage})
    : _storage = storage ?? FlutterSecureSecretsStorage() {
    _loadInitial();
  }
```

with:

```dart
  CredentialsService({required SecretStorage storage}) : _storage = storage {
    _loadInitial();
  }
```

The import of `flutter_secure_secrets_storage.dart` at the top of `credentials_service.dart` stays (the `hasCredentials()` cast still uses the type).

- [ ] **Step 5: Register `AppSecureStorage` in the locator**

In `lib/src/service_locator.dart`:

Add import:

```dart
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
```

At the top of `setup()`, before the `locator..registerLazySingleton` cascade, add:

```dart
  // Central keychain access — must be initialized before any service reads
  // credentials, because the sync flag decides which keychain set is active.
  final appSecureStorage = AppSecureStorage();
  await appSecureStorage.init();
  locator.registerSingleton<AppSecureStorage>(appSecureStorage);
```

Change the `SecretStorage` registration to:

```dart
    ..registerLazySingleton<SecretStorage>(
      () => FlutterSecureSecretsStorage(
        storage: locator.get<AppSecureStorage>(),
      ),
    )
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `fvm flutter test test/pinboard/`
Expected: PASS. If `credentials_service_test.dart` fails to compile because it constructs `CredentialsService()` with an optional storage, update those constructions to pass the existing `InMemorySecretsStorage` explicitly, e.g. `CredentialsService(storage: InMemorySecretsStorage())`.

- [ ] **Step 7: Commit**

```bash
git add lib/src/service_locator.dart lib/src/pinboard/ test/pinboard/
git commit -m "refactor: route pinboard credential storage through AppSecureStorage"
```

---

### Task 3: Refactor `AiSettingsService` to injected storage

**Files:**
- Modify: `lib/src/ai/ai_settings_service.dart`
- Modify: `lib/src/service_locator.dart`
- Test: `test/ai/ai_settings_service_test.dart` (create)

**Interfaces:**
- Consumes: `AppSecureStorage` (Task 1), `FakeFlutterSecureStorage` (Task 1).
- Produces: `AiSettingsService({required AppSecureStorage storage})`. All other public members unchanged (`settings`, `openaiSettings`, `setOpenAiApiKey`, `setJinaApiKey`, `clearAllAiSettings`, …).

- [ ] **Step 1: Write the failing test**

Create `test/ai/ai_settings_service_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';

import '../common/storage/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage appStorage;

  setUp(() async {
    fake = FakeFlutterSecureStorage();
    appStorage = AppSecureStorage(storage: fake);
    await appStorage.init();
  });

  test('persists OpenAI key under ai_settings via AppSecureStorage', () async {
    final service = AiSettingsService(storage: appStorage);
    await service.setOpenAiApiKey('sk-test-key');

    final stored = json.decode(fake.local['ai_settings']!) as Map<String, dynamic>;
    expect((stored['openai'] as Map<String, dynamic>)['apiKey'], 'sk-test-key');
    expect(service.openaiSettings.apiKey, 'sk-test-key');
  });

  test('persists Jina key via AppSecureStorage', () async {
    final service = AiSettingsService(storage: appStorage);
    await service.setJinaApiKey('jina-test-key-123');

    final stored = json.decode(fake.local['ai_settings']!) as Map<String, dynamic>;
    expect(
      (stored['webScraping'] as Map<String, dynamic>)['jinaApiKey'],
      'jina-test-key-123',
    );
  });

  test('loads previously stored settings on construction', () async {
    fake.local['ai_settings'] = json.encode({
      'isEnabled': true,
      'openai': {'apiKey': 'sk-existing', 'descriptionMaxLength': 80, 'maxTags': 3},
      'webScraping': {'jinaApiKey': null},
    });

    final service = AiSettingsService(storage: appStorage);
    // _loadSettings is fire-and-forget in the constructor; let it complete.
    await Future<void>.delayed(Duration.zero);

    expect(service.settings.isEnabled, isTrue);
    expect(service.openaiSettings.apiKey, 'sk-existing');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/ai/ai_settings_service_test.dart`
Expected: FAIL — `AiSettingsService` has no `storage` named parameter.

- [ ] **Step 3: Refactor `AiSettingsService`**

In `lib/src/ai/ai_settings_service.dart`:

Replace the import of `flutter_secure_storage` with:

```dart
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
```

Replace:

```dart
  static const String _aiSettingsKey = 'ai_settings';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  AiSettings _settings = const AiSettings();
```
and the existing constructor:
```dart
  AiSettingsService() {
    _loadSettings();
  }
```

with:

```dart
  static const String _aiSettingsKey = 'ai_settings';

  final AppSecureStorage _secureStorage;

  AiSettings _settings = const AiSettings();

  AiSettingsService({required AppSecureStorage storage})
    : _secureStorage = storage {
    _loadSettings();
  }
```

Then update the three call sites (keeping surrounding logic identical):
- `_loadSettings`: `_secureStorage.read(key: _aiSettingsKey)` → `_secureStorage.read(_aiSettingsKey)`
- `_saveSettings`: `_secureStorage.write(key: _aiSettingsKey, value: settingsJson)` → `_secureStorage.write(_aiSettingsKey, settingsJson)`
- `clearAllAiSettings`: `_secureStorage.delete(key: _aiSettingsKey)` → `_secureStorage.delete(_aiSettingsKey)`

- [ ] **Step 4: Update the locator registration**

In `lib/src/service_locator.dart`, change:

```dart
    ..registerLazySingleton<AiSettingsService>(() => AiSettingsService())
```

to:

```dart
    ..registerLazySingleton<AiSettingsService>(
      () => AiSettingsService(storage: locator.get<AppSecureStorage>()),
    )
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm flutter test test/ai/`
Expected: PASS (mockito-generated mocks of `AiSettingsService` are constructor-agnostic; if any test constructs the real service directly, inject `AppSecureStorage(storage: FakeFlutterSecureStorage())`).

- [ ] **Step 6: Commit**

```bash
git add lib/src/ai/ai_settings_service.dart lib/src/service_locator.dart test/ai/
git commit -m "refactor: route AI settings storage through AppSecureStorage"
```

---

### Task 4: Refactor `BackupService` to injected storage

**Files:**
- Modify: `lib/src/backup/backup_service.dart`
- Modify: `lib/src/service_locator.dart`
- Test: `test/backup/backup_service_storage_test.dart` (create)

**Interfaces:**
- Consumes: `AppSecureStorage` (Task 1).
- Produces: `BackupService({required AppSecureStorage storage})`. All other public members unchanged (`s3Config`, `loadConfiguration`, `saveConfiguration`, `clearConfiguration`, …).

- [ ] **Step 1: Write the failing test**

Create `test/backup/backup_service_storage_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';

import '../common/storage/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage appStorage;
  late BackupService service;

  setUp(() async {
    fake = FakeFlutterSecureStorage();
    appStorage = AppSecureStorage(storage: fake);
    await appStorage.init();
    service = BackupService(storage: appStorage);
  });

  test('saveConfiguration persists under backup_s3_config', () async {
    const config = S3Config(
      accessKey: 'AKIA123',
      secretKey: 'shhh',
      region: 'eu-west-1',
      bucketName: 'my-bucket',
      filePath: 'backups/',
    );

    await service.saveConfiguration(config);

    final stored =
        json.decode(fake.local['backup_s3_config']!) as Map<String, dynamic>;
    expect(stored['accessKey'], 'AKIA123');
    expect(stored['secretKey'], 'shhh');
    expect(service.s3Config, config);
  });

  test('loadConfiguration restores a stored config', () async {
    fake.local['backup_s3_config'] = json.encode(const S3Config(
      accessKey: 'AKIA123',
      secretKey: 'shhh',
      region: 'eu-west-1',
      bucketName: 'my-bucket',
    ).toJson());

    await service.loadConfiguration();
    expect(service.s3Config.accessKey, 'AKIA123');
    expect(service.s3Config.bucketName, 'my-bucket');
  });

  test('clearConfiguration deletes the stored entry', () async {
    fake.local['backup_s3_config'] = json.encode(const S3Config(
      accessKey: 'AKIA123',
      secretKey: 'shhh',
      region: 'eu-west-1',
      bucketName: 'my-bucket',
    ).toJson());

    await service.clearConfiguration();
    expect(fake.local.containsKey('backup_s3_config'), isFalse);
    expect(service.s3Config.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/backup/backup_service_storage_test.dart`
Expected: FAIL — `BackupService` has no `storage` named parameter.

- [ ] **Step 3: Refactor `BackupService`**

In `lib/src/backup/backup_service.dart`:

Replace the `flutter_secure_storage` import with:

```dart
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
```

Replace:

```dart
  static const String _s3ConfigKey = 'backup_s3_config';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
```

with:

```dart
  static const String _s3ConfigKey = 'backup_s3_config';

  final AppSecureStorage _secureStorage;

  BackupService({required AppSecureStorage storage}) : _secureStorage = storage;
```

Update the three call sites:
- `loadConfiguration`: `_secureStorage.read(key: _s3ConfigKey)` → `_secureStorage.read(_s3ConfigKey)`
- `saveConfiguration`: `_secureStorage.write(key: _s3ConfigKey, value: configJson)` → `_secureStorage.write(_s3ConfigKey, configJson)`
- `clearConfiguration`: `_secureStorage.delete(key: _s3ConfigKey)` → `_secureStorage.delete(_s3ConfigKey)`

- [ ] **Step 4: Update the locator registration**

In `lib/src/service_locator.dart`, change:

```dart
    ..registerLazySingleton<BackupService>(() => BackupService())
```

to:

```dart
    ..registerLazySingleton<BackupService>(
      () => BackupService(storage: locator.get<AppSecureStorage>()),
    )
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm flutter test test/backup/backup_service_storage_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/backup/backup_service.dart lib/src/service_locator.dart test/backup/
git commit -m "refactor: route S3 backup config storage through AppSecureStorage"
```

---

### Task 5: Refactor `GitHubCredentialsStorage` to injected storage

**Files:**
- Modify: `lib/src/github/github_credentials_storage.dart`
- Modify: `lib/src/service_locator.dart`
- Test: `test/github/github_credentials_storage_test.dart` (create)

**Interfaces:**
- Consumes: `AppSecureStorage` (Task 1).
- Produces: `GitHubCredentialsStorage({required AppSecureStorage storage})`. All other public members unchanged (`readConfig`, `readToken`, `saveConfig`, `saveToken`, `saveAll`, `isConfigured`, `clearConfig`, `clearToken`, `clearAll`).

- [ ] **Step 1: Write the failing test**

Create `test/github/github_credentials_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/github/models/github_notes_config.dart';

import '../common/storage/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage appStorage;
  late GitHubCredentialsStorage storage;

  const config = GitHubNotesConfig(
    owner: 'octocat',
    repo: 'notes',
    deviceId: 'device-1',
    isConfigured: true,
  );

  setUp(() async {
    fake = FakeFlutterSecureStorage();
    appStorage = AppSecureStorage(storage: fake);
    await appStorage.init();
    storage = GitHubCredentialsStorage(storage: appStorage);
  });

  test('saveAll persists config and token under their keychain keys', () async {
    await storage.saveAll(config: config, token: 'ghp_token123');

    expect(fake.local['github_notes_config'], contains('octocat'));
    expect(fake.local['github_pat_token'], 'ghp_token123');
  });

  test('readConfig and readToken round-trip', () async {
    await storage.saveAll(config: config, token: 'ghp_token123');

    final readBack = await storage.readConfig();
    expect(readBack?.owner, 'octocat');
    expect(readBack?.repo, 'notes');
    expect(await storage.readToken(), 'ghp_token123');
    expect(await storage.isConfigured(), isTrue);
  });

  test('clearAll removes both entries', () async {
    await storage.saveAll(config: config, token: 'ghp_token123');
    await storage.clearAll();

    expect(await storage.readConfig(), isNull);
    expect(await storage.readToken(), isNull);
    expect(await storage.isConfigured(), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/github/github_credentials_storage_test.dart`
Expected: FAIL — `GitHubCredentialsStorage` has no `storage` named parameter.

- [ ] **Step 3: Refactor `GitHubCredentialsStorage`**

In `lib/src/github/github_credentials_storage.dart`:

Replace the `flutter_secure_storage` import with:

```dart
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
```

Replace:

```dart
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
```

with:

```dart
  final AppSecureStorage _secureStorage;

  GitHubCredentialsStorage({required AppSecureStorage storage})
    : _secureStorage = storage;
```

Update the five call sites:
- `readConfig`: `_secureStorage.read(key: _configKey)` → `_secureStorage.read(_configKey)`
- `readToken`: `_secureStorage.read(key: _tokenKey)` → `_secureStorage.read(_tokenKey)`
- `saveConfig`: `_secureStorage.write(key: _configKey, value: configJson)` → `_secureStorage.write(_configKey, configJson)`
- `saveToken`: `_secureStorage.write(key: _tokenKey, value: token)` → `_secureStorage.write(_tokenKey, token)`
- `clearConfig` / `clearToken`: `_secureStorage.delete(key: …)` → `_secureStorage.delete(…)`

- [ ] **Step 4: Update the locator registration**

In `lib/src/service_locator.dart`, change:

```dart
    ..registerLazySingleton<GitHubCredentialsStorage>(
      () => GitHubCredentialsStorage(),
    )
```

to:

```dart
    ..registerLazySingleton<GitHubCredentialsStorage>(
      () => GitHubCredentialsStorage(storage: locator.get<AppSecureStorage>()),
    )
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm flutter test test/github/`
Expected: PASS — `github_auth_service_test.dart` uses mockito-generated mocks of `GitHubCredentialsStorage`, which don't call the real constructor. If mock regeneration is needed: `fvm dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 6: Commit**

```bash
git add lib/src/github/github_credentials_storage.dart lib/src/service_locator.dart test/github/
git commit -m "refactor: route GitHub credential storage through AppSecureStorage"
```

---

### Task 6: `.env` file parser

**Files:**
- Create: `lib/src/env_import/env_file_parser.dart`
- Test: `test/env_import/env_file_parser_test.dart`

**Interfaces:**
- Consumes: nothing project-specific.
- Produces:
  - `class ParsedEnvFile { final Map<String, String> variables; final int ignoredLines; const ParsedEnvFile({required this.variables, required this.ignoredLines}); }`
  - `class EnvFileParser { ParsedEnvFile parse(String contents); }`

- [ ] **Step 1: Write the failing test**

Create `test/env_import/env_file_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/env_import/env_file_parser.dart';

void main() {
  final parser = EnvFileParser();

  test('parses simple KEY=VALUE lines', () {
    final result = parser.parse('PINBOARD_API_TOKEN=user:abc123\n');
    expect(result.variables, {'PINBOARD_API_TOKEN': 'user:abc123'});
    expect(result.ignoredLines, 0);
  });

  test('strips export prefix', () {
    final result = parser.parse('export OPENAI_API_KEY=sk-123');
    expect(result.variables, {'OPENAI_API_KEY': 'sk-123'});
  });

  test('strips matching single and double quotes', () {
    final result = parser.parse(
      'A="double quoted"\nB=\'single quoted\'\nC="unbalanced\'',
    );
    expect(result.variables['A'], 'double quoted');
    expect(result.variables['B'], 'single quoted');
    expect(result.variables['C'], '"unbalanced\''); // mismatched quotes kept
  });

  test('skips blank lines and comments without counting them as ignored', () {
    final result = parser.parse('\n# a comment\n\nKEY=value\n');
    expect(result.variables, {'KEY': 'value'});
    expect(result.ignoredLines, 0);
  });

  test('counts unparseable lines as ignored', () {
    final result = parser.parse('not a var line\nKEY=value\n:::\n');
    expect(result.variables, {'KEY': 'value'});
    expect(result.ignoredLines, 2);
  });

  test('tolerates CRLF line endings', () {
    final result = parser.parse('A=1\r\nB=2\r\n');
    expect(result.variables, {'A': '1', 'B': '2'});
  });

  test('later duplicate keys win', () {
    final result = parser.parse('A=first\nA=second\n');
    expect(result.variables['A'], 'second');
  });

  test('keeps = signs inside values', () {
    final result = parser.parse('TOKEN=abc=def==');
    expect(result.variables['TOKEN'], 'abc=def==');
  });

  test('trims whitespace around key and value', () {
    final result = parser.parse('  KEY  =  value  ');
    expect(result.variables, {'KEY': 'value'});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/env_import/env_file_parser_test.dart`
Expected: FAIL — package import cannot be resolved (file does not exist).

- [ ] **Step 3: Implement the parser**

Create `lib/src/env_import/env_file_parser.dart`:

```dart
/// Result of parsing a `.env`-style file.
class ParsedEnvFile {
  /// Variable name → value (quotes stripped). Later duplicates win.
  final Map<String, String> variables;

  /// Number of non-empty, non-comment lines that could not be parsed.
  final int ignoredLines;

  const ParsedEnvFile({required this.variables, required this.ignoredLines});
}

/// Minimal `.env` parser: `KEY=VALUE` lines, optional `export ` prefix,
/// surrounding single/double quotes stripped, `#` comment lines and blank
/// lines skipped. Anything else is counted as ignored, never an error.
class EnvFileParser {
  static final RegExp _linePattern = RegExp(
    r'^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$',
  );

  ParsedEnvFile parse(String contents) {
    final variables = <String, String>{};
    var ignored = 0;

    for (final rawLine in contents.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final match = _linePattern.firstMatch(line);
      if (match == null) {
        ignored++;
        continue;
      }

      variables[match.group(1)!] = _unquote(match.group(2)!.trim());
    }

    return ParsedEnvFile(variables: variables, ignoredLines: ignored);
  }

  String _unquote(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/env_import/env_file_parser_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/env_import/env_file_parser.dart test/env_import/env_file_parser_test.dart
git commit -m "feat: add .env file parser"
```

---

### Task 7: `EnvImportService`

**Files:**
- Create: `lib/src/env_import/env_import_service.dart`
- Modify: `lib/src/service_locator.dart`
- Test: `test/env_import/env_import_service_test.dart`

**Interfaces:**
- Consumes: `EnvFileParser`/`ParsedEnvFile` (Task 6), `CredentialsService.saveCredentials(String)`, `AiSettingsService.setOpenAiApiKey(String?)` / `setJinaApiKey(String?)`, `BackupService.loadConfiguration()` / `saveConfiguration(S3Config)` / `s3Config`, `GitHubCredentialsStorage.readConfig()` / `readToken()` / `saveConfig(GitHubNotesConfig)` / `saveToken(String)`, `GitHubAuthService.initialize()`, `Uuid().v4()`.
- Produces:
  - `class EnvImportPreview { final Map<String, String> recognized; final int ignoredLines; final List<String> unrecognized; }`
  - `class EnvImportResult { final List<String> applied; final Map<String, String> failed; }`
  - `class EnvImportService` with:
    - constructor `EnvImportService({required CredentialsService credentialsService, required AiSettingsService aiSettingsService, required BackupService backupService, required GitHubCredentialsStorage githubStorage, required GitHubAuthService githubAuthService})`
    - `static const Set<String> recognizedVariables`
    - `EnvImportPreview preview(String contents)`
    - `Future<EnvImportResult> apply(Map<String, String> variables)`

- [ ] **Step 1: Write the failing test**

Create `test/env_import/env_import_service_test.dart`. Uses real services over `FakeFlutterSecureStorage` (no HTTP is triggered by any code path used here); `GitHubAuthService` is real too — its `initialize()` only reads storage.

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/github/models/github_notes_config.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/flutter_secure_secrets_storage.dart';

import '../common/storage/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage appStorage;
  late CredentialsService credentialsService;
  late AiSettingsService aiSettingsService;
  late BackupService backupService;
  late GitHubCredentialsStorage githubStorage;
  late GitHubAuthService githubAuthService;
  late EnvImportService service;

  setUp(() async {
    fake = FakeFlutterSecureStorage();
    appStorage = AppSecureStorage(storage: fake);
    await appStorage.init();
    credentialsService = CredentialsService(
      storage: FlutterSecureSecretsStorage(storage: appStorage),
    );
    aiSettingsService = AiSettingsService(storage: appStorage);
    backupService = BackupService(storage: appStorage);
    githubStorage = GitHubCredentialsStorage(storage: appStorage);
    githubAuthService = GitHubAuthService(storage: githubStorage);
    service = EnvImportService(
      credentialsService: credentialsService,
      aiSettingsService: aiSettingsService,
      backupService: backupService,
      githubStorage: githubStorage,
      githubAuthService: githubAuthService,
    );
  });

  group('preview', () {
    test('splits recognized from unrecognized variables', () {
      final preview = service.preview(
        'PINBOARD_API_TOKEN=user:abc\nAPPLE_ID=someone@example.com\njunk line\n',
      );
      expect(preview.recognized, {'PINBOARD_API_TOKEN': 'user:abc'});
      expect(preview.unrecognized, ['APPLE_ID']);
      expect(preview.ignoredLines, 1);
    });
  });

  group('apply', () {
    test('imports pinboard token and authenticates', () async {
      final result = await service.apply({'PINBOARD_API_TOKEN': 'user:abc123def'});

      expect(result.applied, contains('PINBOARD_API_TOKEN'));
      expect(result.failed, isEmpty);
      final creds = await credentialsService.getCredentials();
      expect(creds?.apiKey, 'user:abc123def');
    });

    test('env value wins over an existing stored value', () async {
      await credentialsService.saveCredentials('old:0000000000');
      await service.apply({'PINBOARD_API_TOKEN': 'new:1111111111'});
      final creds = await credentialsService.getCredentials();
      expect(creds?.apiKey, 'new:1111111111');
    });

    test('imports AI keys', () async {
      final result = await service.apply({
        'OPENAI_API_KEY': 'sk-abc',
        'JINA_API_KEY': 'jina-abc',
      });

      expect(result.applied, containsAll(['OPENAI_API_KEY', 'JINA_API_KEY']));
      expect(aiSettingsService.openaiSettings.apiKey, 'sk-abc');
      expect(aiSettingsService.settings.webScraping.jinaApiKey, 'jina-abc');
    });

    test('partial S3 import merges with the existing config', () async {
      await backupService.saveConfiguration(const S3Config(
        accessKey: 'OLD_ACCESS',
        secretKey: 'OLD_SECRET',
        region: 'us-east-1',
        bucketName: 'old-bucket',
      ));

      await service.apply({'AWS_SECRET_ACCESS_KEY': 'NEW_SECRET'});

      expect(backupService.s3Config.secretKey, 'NEW_SECRET');
      expect(backupService.s3Config.accessKey, 'OLD_ACCESS');
      expect(backupService.s3Config.bucketName, 'old-bucket');
    });

    test('creates a GitHub config with generated deviceId when none exists', () async {
      final result = await service.apply({
        'GITHUB_PAT': 'ghp_secret123',
        'GITHUB_OWNER': 'octocat',
        'GITHUB_REPO': 'notes',
      });

      expect(result.failed, isEmpty);
      final config = await githubStorage.readConfig();
      expect(config?.owner, 'octocat');
      expect(config?.repo, 'notes');
      expect(config?.branch, 'main');
      expect(config?.deviceId, isNotEmpty);
      expect(config?.isConfigured, isTrue);
      expect(await githubStorage.readToken(), 'ghp_secret123');
    });

    test('merges GitHub fields into an existing config', () async {
      await githubStorage.saveAll(
        config: const GitHubNotesConfig(
          owner: 'octocat',
          repo: 'old-repo',
          deviceId: 'device-1',
          isConfigured: true,
        ),
        token: 'ghp_old',
      );

      await service.apply({'GITHUB_REPO': 'new-repo'});

      final config = await githubStorage.readConfig();
      expect(config?.repo, 'new-repo');
      expect(config?.owner, 'octocat');
      expect(config?.deviceId, 'device-1');
      expect(await githubStorage.readToken(), 'ghp_old');
    });

    test('GitHub config without token is saved but not marked configured', () async {
      await service.apply({'GITHUB_OWNER': 'octocat', 'GITHUB_REPO': 'notes'});

      final config = await githubStorage.readConfig();
      expect(config?.owner, 'octocat');
      expect(config?.isConfigured, isFalse);
    });

    test('unknown variables are not applied', () async {
      final result = await service.apply({'TOTALLY_UNKNOWN': 'x'});
      expect(result.applied, isEmpty);
      expect(result.failed, isEmpty);
    });

    test('a failing group is reported without blocking others', () async {
      // Empty pinboard token makes CredentialsService.saveCredentials throw.
      final result = await service.apply({
        'PINBOARD_API_TOKEN': '   ',
        'OPENAI_API_KEY': 'sk-abc',
      });

      expect(result.failed.keys, contains('PINBOARD_API_TOKEN'));
      expect(result.applied, contains('OPENAI_API_KEY'));
      expect(aiSettingsService.openaiSettings.apiKey, 'sk-abc');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/env_import/env_import_service_test.dart`
Expected: FAIL — `env_import_service.dart` does not exist.

- [ ] **Step 3: Implement `EnvImportService`**

Create `lib/src/env_import/env_import_service.dart`:

```dart
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/env_import/env_file_parser.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/github/models/github_notes_config.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:uuid/uuid.dart';

/// Preview of a parsed `.env` file, split into variables the app understands
/// and everything else.
class EnvImportPreview {
  final Map<String, String> recognized;
  final int ignoredLines;
  final List<String> unrecognized;

  const EnvImportPreview({
    required this.recognized,
    required this.ignoredLines,
    required this.unrecognized,
  });

  bool get isEmpty => recognized.isEmpty;
}

/// Outcome of applying an import: which variables were written, and which
/// failed with what message.
class EnvImportResult {
  final List<String> applied;
  final Map<String, String> failed;

  const EnvImportResult({required this.applied, required this.failed});
}

/// One-time import of credentials from `.env` file contents.
///
/// Env values always win over stored values; variables absent from the file
/// are never touched. Writes go through the existing services so listeners
/// (auth state, settings UI) update immediately.
class EnvImportService {
  static const Set<String> recognizedVariables = {
    'PINBOARD_API_TOKEN',
    'OPENAI_API_KEY',
    'JINA_API_KEY',
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_REGION',
    'S3_BUCKET',
    'S3_FILE_PATH',
    'GITHUB_PAT',
    'GITHUB_OWNER',
    'GITHUB_REPO',
    'GITHUB_BRANCH',
    'GITHUB_NOTES_PATH',
  };

  static const _s3Variables = {
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_REGION',
    'S3_BUCKET',
    'S3_FILE_PATH',
  };

  static const _githubVariables = {
    'GITHUB_PAT',
    'GITHUB_OWNER',
    'GITHUB_REPO',
    'GITHUB_BRANCH',
    'GITHUB_NOTES_PATH',
  };

  final CredentialsService _credentialsService;
  final AiSettingsService _aiSettingsService;
  final BackupService _backupService;
  final GitHubCredentialsStorage _githubStorage;
  final GitHubAuthService _githubAuthService;
  final EnvFileParser _parser = EnvFileParser();
  final Uuid _uuid = const Uuid();

  EnvImportService({
    required CredentialsService credentialsService,
    required AiSettingsService aiSettingsService,
    required BackupService backupService,
    required GitHubCredentialsStorage githubStorage,
    required GitHubAuthService githubAuthService,
  }) : _credentialsService = credentialsService,
       _aiSettingsService = aiSettingsService,
       _backupService = backupService,
       _githubStorage = githubStorage,
       _githubAuthService = githubAuthService;

  EnvImportPreview preview(String contents) {
    final parsed = _parser.parse(contents);
    final recognized = <String, String>{};
    final unrecognized = <String>[];

    for (final entry in parsed.variables.entries) {
      if (recognizedVariables.contains(entry.key)) {
        recognized[entry.key] = entry.value;
      } else {
        unrecognized.add(entry.key);
      }
    }

    return EnvImportPreview(
      recognized: recognized,
      ignoredLines: parsed.ignoredLines,
      unrecognized: unrecognized,
    );
  }

  Future<EnvImportResult> apply(Map<String, String> variables) async {
    final applied = <String>[];
    final failed = <String, String>{};

    // Pinboard
    final pinboardToken = variables['PINBOARD_API_TOKEN'];
    if (pinboardToken != null) {
      try {
        await _credentialsService.saveCredentials(pinboardToken);
        applied.add('PINBOARD_API_TOKEN');
      } catch (e) {
        failed['PINBOARD_API_TOKEN'] = '$e';
      }
    }

    // OpenAI / Jina
    final openAiKey = variables['OPENAI_API_KEY'];
    if (openAiKey != null) {
      try {
        await _aiSettingsService.setOpenAiApiKey(openAiKey);
        applied.add('OPENAI_API_KEY');
      } catch (e) {
        failed['OPENAI_API_KEY'] = '$e';
      }
    }
    final jinaKey = variables['JINA_API_KEY'];
    if (jinaKey != null) {
      try {
        await _aiSettingsService.setJinaApiKey(jinaKey);
        applied.add('JINA_API_KEY');
      } catch (e) {
        failed['JINA_API_KEY'] = '$e';
      }
    }

    // S3 backup — merge into the existing config.
    final s3Keys = variables.keys.where(_s3Variables.contains).toList();
    if (s3Keys.isNotEmpty) {
      try {
        await _backupService.loadConfiguration();
        final merged = _backupService.s3Config.copyWith(
          accessKey: variables['AWS_ACCESS_KEY_ID'],
          secretKey: variables['AWS_SECRET_ACCESS_KEY'],
          region: variables['AWS_REGION'],
          bucketName: variables['S3_BUCKET'],
          filePath: variables['S3_FILE_PATH'],
        );
        await _backupService.saveConfiguration(merged);
        applied.addAll(s3Keys);
      } catch (e) {
        for (final key in s3Keys) {
          failed[key] = '$e';
        }
      }
    }

    // GitHub — merge into the existing config, or create one.
    final githubKeys = variables.keys.where(_githubVariables.contains).toList();
    if (githubKeys.isNotEmpty) {
      try {
        final existing = await _githubStorage.readConfig();
        final token = variables['GITHUB_PAT'] ?? await _githubStorage.readToken();

        final base = existing ??
            GitHubNotesConfig(
              owner: '',
              repo: '',
              deviceId: _uuid.v4(),
            );
        final owner = variables['GITHUB_OWNER'] ?? base.owner;
        final repo = variables['GITHUB_REPO'] ?? base.repo;
        final merged = base.copyWith(
          owner: owner,
          repo: repo,
          branch: variables['GITHUB_BRANCH'] ?? base.branch,
          notesPath: variables['GITHUB_NOTES_PATH'] ?? base.notesPath,
          isConfigured:
              owner.isNotEmpty && repo.isNotEmpty && (token?.isNotEmpty ?? false),
        );

        await _githubStorage.saveConfig(merged);
        final importedToken = variables['GITHUB_PAT'];
        if (importedToken != null) {
          await _githubStorage.saveToken(importedToken);
        }
        await _githubAuthService.initialize();
        applied.addAll(githubKeys);
      } catch (e) {
        for (final key in githubKeys) {
          failed[key] = '$e';
        }
      }
    }

    return EnvImportResult(applied: applied, failed: failed);
  }
}
```

Note: `GitHubNotesConfig.copyWith` must include `owner`, `repo`, `branch`, and `notesPath` parameters — verify in `lib/src/github/models/github_notes_config.dart` (they exist; the model's copyWith covers all fields).

- [ ] **Step 4: Register in the locator**

In `lib/src/service_locator.dart`, add import:

```dart
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
```

and add to the cascade (after `GitHubConfigValidator`):

```dart
    ..registerLazySingleton<EnvImportService>(
      () => EnvImportService(
        credentialsService: locator.get<CredentialsService>(),
        aiSettingsService: locator.get<AiSettingsService>(),
        backupService: locator.get<BackupService>(),
        githubStorage: locator.get<GitHubCredentialsStorage>(),
        githubAuthService: locator.get<GitHubAuthService>(),
      ),
    )
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm flutter test test/env_import/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/env_import/ lib/src/service_locator.dart test/env_import/
git commit -m "feat: add EnvImportService applying .env credentials through services"
```

---

### Task 8: `SettingsState` + `SettingsCubit` additions

**Files:**
- Modify: `lib/src/pages/settings/state/settings_state.dart`
- Modify: `lib/src/pages/settings/state/settings_cubit.dart`
- Modify: `lib/src/pages/settings/settings_page.dart` (cubit construction only — the tab UI is Task 9)
- Test: `test/pages/settings/state/settings_cubit_sync_test.dart` (create)

**Interfaces:**
- Consumes: `AppSecureStorage.syncEnabled` / `setSyncEnabled(bool)` (Task 1); `EnvImportService.preview` / `apply` (Task 7).
- Produces:
  - `SettingsState` gains: `final bool secretsSyncEnabled;` (default `false`) and `final String? envImportMessage;` (sentinel-nullable in `copyWith`, like `errorMessage`).
  - `SettingsCubit` gains constructor params `required AppSecureStorage appSecureStorage, required EnvImportService envImportService` and methods:
    - `Future<void> setSecretsSyncEnabled(bool enabled)`
    - `EnvImportPreview previewEnvImport(String contents)`
    - `Future<void> importEnvVariables(Map<String, String> variables)`

- [ ] **Step 1: Write the failing test**

Create `test/pages/settings/state/settings_cubit_sync_test.dart`:

Note on real services: `loadSettings()` fire-and-forgets
`_validateJinaKey`/`_validateOpenAiKey`, which call
`AiSettingsService.testJinaConnection`/`testOpenAiConnection` →
`locator.get<JinaService>()`/`locator.get<OpenAiService>()`. The locator is
empty in this test, so those calls throw internally and are caught, leaving
`jinaValidationStatus`/`openAiValidationStatus` as `invalid`. That is expected
here — no network is touched, and none of these assertions read validation
state. Do not "fix" it by registering services.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_cubit.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/flutter_secure_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

import '../../../common/storage/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage appStorage;
  late SettingsCubit cubit;
  late SecretStorage secretStorage;
  late CredentialsService credentialsService;
  late AiSettingsService aiSettingsService;
  late BackupService backupService;
  late GitHubCredentialsStorage githubStorage;
  late GitHubAuthService githubAuthService;

  setUp(() async {
    fake = FakeFlutterSecureStorage();
    appStorage = AppSecureStorage(storage: fake);
    await appStorage.init();
    secretStorage = FlutterSecureSecretsStorage(storage: appStorage);
    credentialsService = CredentialsService(storage: secretStorage);
    aiSettingsService = AiSettingsService(storage: appStorage);
    backupService = BackupService(storage: appStorage);
    githubStorage = GitHubCredentialsStorage(storage: appStorage);
    githubAuthService = GitHubAuthService(storage: githubStorage);
    cubit = SettingsCubit(
      credentialsService: credentialsService,
      pinboardService: PinboardService(secretStorage: secretStorage),
      aiSettingsService: aiSettingsService,
      backupService: backupService,
      githubAuthService: githubAuthService,
      appSecureStorage: appStorage,
      envImportService: EnvImportService(
        credentialsService: credentialsService,
        aiSettingsService: aiSettingsService,
        backupService: backupService,
        githubStorage: githubStorage,
        githubAuthService: githubAuthService,
      ),
    );
  });

  tearDown(() => cubit.close());

  test('loadSettings surfaces the persisted sync flag', () async {
    fake.local['secrets_sync_enabled'] = 'true';
    await appStorage.init();
    await cubit.loadSettings();
    expect(cubit.state.secretsSyncEnabled, isTrue);
  });

  test('setSecretsSyncEnabled(true) migrates and updates state', () async {
    fake.local['pinboard_credentials'] = '{"apiKey":"user:abc"}';

    await cubit.setSecretsSyncEnabled(true);

    expect(cubit.state.secretsSyncEnabled, isTrue);
    expect(fake.synced['pinboard_credentials'], '{"apiKey":"user:abc"}');
  });

  test('previewEnvImport reports recognized variables', () {
    final preview = cubit.previewEnvImport('OPENAI_API_KEY=sk-1\nRANDOM=2\n');
    expect(preview.recognized.keys, ['OPENAI_API_KEY']);
    expect(preview.unrecognized, ['RANDOM']);
  });

  test('importEnvVariables applies values and sets a summary message', () async {
    await cubit.importEnvVariables({'OPENAI_API_KEY': 'sk-1'});

    expect(cubit.state.envImportMessage, contains('1'));
    expect(aiSettingsService.openaiSettings.apiKey, 'sk-1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/pages/settings/state/settings_cubit_sync_test.dart`
Expected: FAIL — `SettingsCubit` has no `appSecureStorage` parameter.

- [ ] **Step 3: Add state fields**

In `lib/src/pages/settings/state/settings_state.dart`:

Add to the constructor parameter list (after `this.tokenExpiryWarning,`):

```dart
    // Credential sync & import
    this.secretsSyncEnabled = false,
    this.envImportMessage,
```

Add fields (after `final TokenExpiryWarning? tokenExpiryWarning;`):

```dart
  // Credential sync & import
  final bool secretsSyncEnabled;
  final String? envImportMessage;
```

Add to `copyWith` parameters:

```dart
    bool? secretsSyncEnabled,
    Object? envImportMessage = _sentinel,
```

Add to the `copyWith` body's `SettingsState(...)` construction:

```dart
      secretsSyncEnabled: secretsSyncEnabled ?? this.secretsSyncEnabled,
      envImportMessage: envImportMessage == _sentinel
          ? this.envImportMessage
          : envImportMessage as String?,
```

Add both fields to the `props` list at the bottom of the class:

```dart
    secretsSyncEnabled,
    envImportMessage,
```

- [ ] **Step 4: Extend `SettingsCubit`**

In `lib/src/pages/settings/state/settings_cubit.dart`:

Add imports:

```dart
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
```

The existing constructor (lines 16-25) uses private named parameters
(`required this._credentialsService,` — supported by this project's Dart
version). Extend it in the same style — the full replacement:

```dart
  SettingsCubit({
    required this._credentialsService,
    required this._pinboardService,
    required this._aiSettingsService,
    required this._backupService,
    required this._githubAuthService,
    required this._appSecureStorage,
    required this._envImportService,
    GitHubConfigValidator? githubConfigValidator,
  }) : _githubConfigValidator =
           githubConfigValidator ?? GitHubConfigValidator(),
       super(const SettingsState()) {
    // Listen to authentication changes
    _credentialsService.isAuthenticatedNotifier.addListener(_onAuthChanged);
    // Listen to AI settings changes
    _aiSettingsService.addListener(_onAiSettingsChanged);
    // Listen to backup service changes
    _backupService.addListener(_onBackupServiceChanged);
    // Listen to GitHub auth changes
    _githubAuthService.addListener(_onGitHubAuthChanged);
  }
```

Add the two fields next to the existing service fields (after
`final GitHubConfigValidator _githubConfigValidator;`):

```dart
  final AppSecureStorage _appSecureStorage;
  final EnvImportService _envImportService;
```

In `loadSettings()`, include the flag in the loaded-state emit by adding to the `state.copyWith(...)` arguments:

```dart
          secretsSyncEnabled: _appSecureStorage.syncEnabled,
```

Add the three methods at the end of the class (before `close()` override if present):

```dart
  /// Enable or disable iCloud Keychain sync for all credentials.
  Future<void> setSecretsSyncEnabled(bool enabled) async {
    try {
      await _appSecureStorage.setSyncEnabled(enabled);
      _safeEmit(state.copyWith(secretsSyncEnabled: _appSecureStorage.syncEnabled));
      // Reload so values adopted from the synced set appear in the UI.
      await loadSettings();
    } catch (e) {
      _safeEmit(
        state.copyWith(
          errorMessage: 'Failed to ${enabled ? 'enable' : 'disable'} sync: $e',
        ),
      );
    }
  }

  /// Parse .env contents into recognized/unrecognized variables.
  EnvImportPreview previewEnvImport(String contents) =>
      _envImportService.preview(contents);

  /// Apply recognized env variables. Env values always win.
  Future<void> importEnvVariables(Map<String, String> variables) async {
    final result = await _envImportService.apply(variables);
    final buffer = StringBuffer('Imported ${result.applied.length} value(s).');
    if (result.failed.isNotEmpty) {
      buffer.write(' Failed: ${result.failed.keys.join(', ')}.');
    }
    _safeEmit(state.copyWith(envImportMessage: buffer.toString()));
    await loadSettings();
  }
```

- [ ] **Step 5: Update `SettingsPage` cubit construction**

In `lib/src/pages/settings/settings_page.dart`, extend the `BlocProvider` create:

```dart
      create: (context) => SettingsCubit(
        credentialsService: locator.get<CredentialsService>(),
        pinboardService: locator.get<PinboardService>(),
        aiSettingsService: locator.get<AiSettingsService>(),
        backupService: locator.get<BackupService>(),
        githubAuthService: locator.get<GitHubAuthService>(),
        appSecureStorage: locator.get<AppSecureStorage>(),
        envImportService: locator.get<EnvImportService>(),
      )..loadSettings(),
```

with imports:

```dart
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
```

- [ ] **Step 6: Fix existing cubit tests' constructor calls**

`test/pages/settings/state/settings_cubit_test.dart` and `test/pages/settings/state/settings_cubit_safe_emit_test.dart` construct `SettingsCubit` directly. For each construction site, add the two new arguments, backed by a fake storage per test file:

```dart
// at top of file
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
import '../../../common/storage/fake_flutter_secure_storage.dart';
```

In `setUp`, build real instances over the fake (they are cheap and side-effect-free):

```dart
final appSecureStorage = AppSecureStorage(storage: FakeFlutterSecureStorage());
```

and pass:

```dart
  appSecureStorage: appSecureStorage,
  envImportService: EnvImportService(
    credentialsService: mockCredentialsService,
    aiSettingsService: mockAiSettingsService,
    backupService: mockBackupService,
    githubStorage: GitHubCredentialsStorage(storage: appSecureStorage),
    githubAuthService: mockGitHubAuthService,
  ),
```

(using each file's existing mock instances — names may differ per file; keep their existing mocks.)

- [ ] **Step 7: Run tests to verify they pass**

Run: `fvm flutter test test/pages/settings/`
Expected: PASS (new sync test plus both existing cubit test files).

- [ ] **Step 8: Commit**

```bash
git add lib/src/pages/settings/ test/pages/settings/
git commit -m "feat: expose credential sync toggle and env import in SettingsCubit"
```

---

### Task 9: Settings UI "Sync" tab, `file_selector` dep, entitlements

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/src/pages/settings/settings_page.dart`
- Modify: `macos/Runner/DebugProfile.entitlements`
- Modify: `macos/Runner/Release.entitlements`

**Interfaces:**
- Consumes: `SettingsCubit.setSecretsSyncEnabled` / `previewEnvImport` / `importEnvVariables` (Task 8), `state.secretsSyncEnabled` / `state.envImportMessage`; UI kit: `AppTabView`, `AppTab`, `AppTabController`, `AppSwitch(value:, onChanged:)`, `AppButton(size:, secondary:, onPressed:, child:)`, `showAppAlertDialog` / `AppAlertDialog`, `context.appTypography`, `AppColors.separator`.
- Produces: fifth Settings tab labeled `Sync`; no programmatic interface for later tasks.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml` under `dependencies:`, after `url_launcher: ^6.2.5`, add:

```yaml
  file_selector: ^1.0.3
```

Run: `fvm flutter pub get`
Expected: resolves cleanly; `file_selector_macos` appears as a transitive (endorsed) dependency in `pubspec.lock`.

- [ ] **Step 2: Add the sandbox entitlement for user-selected files**

In `macos/Runner/DebugProfile.entitlements`, add inside the `<dict>`:

```xml
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
```

Same addition in `macos/Runner/Release.entitlements`.

- [ ] **Step 3: Extend the tab bar**

In `lib/src/pages/settings/settings_page.dart`:

Change `AppTabController(length: 4)` to `AppTabController(length: 5)` in `initState`.

In the `AppTabView`, append to `tabs`:

```dart
                    AppTab(label: 'Sync'),
```

and to `children`:

```dart
                    _buildSyncTab(context, state),
```

- [ ] **Step 4: Implement the tab body and flows**

Add imports to `settings_page.dart`:

```dart
import 'package:file_selector/file_selector.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
```

Add these members to `_SettingsPageViewState`:

```dart
  Widget _buildSyncTab(BuildContext context, SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('iCloud Sync', style: context.appTypography.headline),
          const SizedBox(height: 8),
          Text(
            'Sync your Pinboard, AI, backup, and GitHub credentials across '
            'your Macs using iCloud Keychain. Requires iCloud Keychain to be '
            'enabled in System Settings, and must be switched on separately '
            'on each Mac.',
            style: context.appTypography.body,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppSwitch(
                value: state.secretsSyncEnabled,
                onChanged: (value) => _onSyncToggleChanged(context, value),
              ),
              const SizedBox(width: 8),
              Text(
                'Sync credentials across devices',
                style: context.appTypography.body,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: AppColors.separator),
          const SizedBox(height: 16),
          Text('Import from .env', style: context.appTypography.headline),
          const SizedBox(height: 8),
          Text(
            'Import credentials from a .env file instead of entering them '
            'manually. Values in the file replace existing ones; anything '
            'not in the file is left unchanged. The file is read once — you '
            'can delete it afterwards.',
            style: context.appTypography.body,
          ),
          const SizedBox(height: 12),
          AppButton(
            size: AppButtonSize.large,
            onPressed: () => _importEnvFile(context),
            child: const Text('Import from .env…'),
          ),
          if (state.envImportMessage != null) ...[
            const SizedBox(height: 12),
            Text(state.envImportMessage!, style: context.appTypography.body),
          ],
        ],
      ),
    );
  }

  Future<void> _onSyncToggleChanged(BuildContext context, bool value) async {
    final cubit = context.read<SettingsCubit>();
    if (!value) {
      await cubit.setSecretsSyncEnabled(false);
      return;
    }
    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Enable iCloud sync?'),
        message: const Text(
          'Your credentials will sync across Macs signed into the same '
          'iCloud account. Where a synced value already exists, it replaces '
          'this Mac\'s value.',
        ),
        primaryButton: AppAlertDialogAction(
          label: 'Enable',
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        secondaryButton: AppAlertDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
    );
    if (confirmed == true) {
      await cubit.setSecretsSyncEnabled(true);
    }
  }

  String _maskSecret(String value) {
    if (value.length <= 8) return '••••';
    return '${value.substring(0, 4)}…${value.substring(value.length - 4)}';
  }

  Future<void> _importEnvFile(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final file = await openFile(
      acceptedTypeGroups: const [XTypeGroup(label: 'env files')],
    );
    if (file == null) return;

    final String contents;
    try {
      contents = await file.readAsString();
    } catch (e) {
      if (!mounted) return;
      await showAppAlertDialog<void>(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('Could not read file'),
          message: Text('$e'),
          primaryButton: AppAlertDialogAction(
            label: 'OK',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
      return;
    }

    final preview = cubit.previewEnvImport(contents);
    if (!mounted) return;

    if (preview.isEmpty) {
      await showAppAlertDialog<void>(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('Nothing to import'),
          message: Text(
            'No recognized variables found. '
            '${preview.unrecognized.isNotEmpty ? 'Unrecognized: ${preview.unrecognized.join(', ')}.' : ''}',
          ),
          primaryButton: AppAlertDialogAction(
            label: 'OK',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
      return;
    }

    final lines = preview.recognized.entries
        .map((e) => '${e.key} = ${_maskSecret(e.value)}')
        .join('\n');
    final extra = <String>[
      if (preview.unrecognized.isNotEmpty)
        '${preview.unrecognized.length} unrecognized variable(s) ignored.',
      if (preview.ignoredLines > 0)
        '${preview.ignoredLines} unparseable line(s) ignored.',
    ].join(' ');

    final confirmed = await showAppAlertDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Import credentials?'),
        message: Text(
          'The following values will be imported and will REPLACE any '
          'existing values:\n\n$lines${extra.isNotEmpty ? '\n\n$extra' : ''}',
        ),
        primaryButton: AppAlertDialogAction(
          label: 'Import',
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        secondaryButton: AppAlertDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
    );

    if (confirmed == true) {
      await cubit.importEnvVariables(preview.recognized);
    }
  }
```

**API-accuracy note:** `AppAlertDialog` / `showAppAlertDialog` / `AppAlertDialogAction` parameter names above follow the pattern visible in the GitHub tab (`settings_page.dart` ~line 1259). Before wiring the dialogs, open `lib/src/ui/overlays/` and match the real constructor signatures exactly (e.g. the action/button parameter names). Adjust the calls — not the flow — if names differ.

- [ ] **Step 5: Build and smoke-test manually**

Run: `fvm flutter build macos --debug`
Expected: builds cleanly.

Run: `make run`, then in the app:
1. Settings → Sync tab renders; toggle is OFF.
2. Click "Import from .env…", pick a scratch file containing `OPENAI_API_KEY=sk-test-123` and `APPLE_ID=x@y.z` → dialog lists `OPENAI_API_KEY = sk-t…-123`-style masked value and reports 1 unrecognized variable → Import → summary message appears, AI Settings tab shows the key.
3. Flip the sync toggle ON → confirmation dialog → enable succeeds (verify in Keychain Access: the items appear in the iCloud keychain).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/pages/settings/settings_page.dart macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements
git commit -m "feat: add Sync settings tab with iCloud toggle and .env import"
```

---

### Task 10: README, full test suite, analyzer

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above; no new code.

- [ ] **Step 1: Add README sections**

In `README.md`, add a features/documentation section (place near the existing Settings/Backup documentation, matching the file's heading style):

```markdown
## Syncing credentials across Macs (iCloud)

Pinboard Wizard can sync all of its credentials — Pinboard API token, OpenAI
and Jina keys, S3 backup configuration, and GitHub notes credentials — across
your Macs using iCloud Keychain.

- Open **Settings → Sync** and enable **Sync credentials across devices**.
- Sync is **off by default** and must be enabled on **each Mac** that should
  participate. It requires iCloud Keychain (System Settings → Apple ID →
  iCloud → Passwords & Keychain).
- When you enable sync on a Mac and a synced value already exists (from
  another Mac), the synced value replaces the local one.
- Disabling sync keeps a local snapshot of the current values and never
  affects your other Macs.
- Apple end-to-end encrypts iCloud Keychain data; no credential ever touches
  a third-party server.

## Importing credentials from a .env file

Instead of typing each credential into Settings, you can import them once from
a `.env` file via **Settings → Sync → Import from .env…**.

Recognized variables:

| Variable | Maps to |
|---|---|
| `PINBOARD_API_TOKEN` | Pinboard API token (`username:hex`) |
| `OPENAI_API_KEY` | OpenAI API key |
| `JINA_API_KEY` | Jina AI key |
| `AWS_ACCESS_KEY_ID` | S3 backup access key |
| `AWS_SECRET_ACCESS_KEY` | S3 backup secret key |
| `AWS_REGION` | S3 backup region |
| `S3_BUCKET` | S3 backup bucket name |
| `S3_FILE_PATH` | S3 backup file path |
| `GITHUB_PAT` | GitHub personal access token |
| `GITHUB_OWNER` | GitHub repository owner |
| `GITHUB_REPO` | GitHub repository name |
| `GITHUB_BRANCH` | GitHub branch (default `main`) |
| `GITHUB_NOTES_PATH` | Notes folder inside the repository |

Rules:

- Import is **one-time**: the app reads the file only when you click Import,
  never at launch. You can delete the file afterwards.
- Values from the file **replace** existing stored values ("env wins").
  Variables not present in the file are left untouched.
- Unrecognized variables and unparseable lines are ignored and reported.
- Standard `.env` syntax is supported: `KEY=VALUE`, optional `export `
  prefix, `#` comments, single or double quotes.
```

- [ ] **Step 2: Run the full verification suite**

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```

Expected: format makes no unexpected changes, analyzer reports no new issues, full test suite passes.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document credential sync and .env import"
```

---

## Manual cross-Mac smoke checklist (not CI-testable — include in PR description)

1. Mac A: configure Pinboard token, enable Settings → Sync. Confirm items in Keychain Access show as iCloud keychain items.
2. Mac B (same iCloud account, iCloud Keychain on): install build, open Settings → Sync, enable. Pinboard token appears; app authenticates.
3. Mac B: change the OpenAI key. Mac A: relaunch → sees the new key.
4. Mac B: disable sync, change the Jina key. Mac A: key unchanged (divergence is expected and local to B).
5. Mac B: re-enable sync → Mac B adopts A's synced values again.
