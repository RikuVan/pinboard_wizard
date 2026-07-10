import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    test(
      'persists the flag local-only and flips reads to synced set',
      () async {
        await storage.setSyncEnabled(true);
        expect(storage.syncEnabled, isTrue);
        expect(fake.local['secrets_sync_enabled'], 'true');
        expect(fake.synced.containsKey('secrets_sync_enabled'), isFalse);
        await storage.write('ai_settings', 'x');
        expect(fake.synced['ai_settings'], 'x');
      },
    );

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

    test(
      'a failed write leaves every local copy intact (two-phase migration)',
      () async {
        // 'ai_settings' migrates after 'pinboard_credentials' in
        // AppSecureStorage.syncedKeys, so the failure hits the SECOND write.
        final throwing = _ThrowingSecureStorage(throwOnWriteOf: 'ai_settings');
        final failingStorage = AppSecureStorage(storage: throwing);
        await failingStorage.init();
        throwing.local['pinboard_credentials'] = 'creds';
        throwing.local['ai_settings'] = 'ai';

        await expectLater(
          failingStorage.setSyncEnabled(true),
          throwsA(isA<AppSecureStorageException>()),
        );

        expect(failingStorage.syncEnabled, isFalse);
        // No local copy may be deleted before every write succeeded —
        // otherwise a partial failure leaves a credential invisible in
        // both sets.
        expect(throwing.local['pinboard_credentials'], 'creds');
        expect(throwing.local['ai_settings'], 'ai');

        // The migration is idempotent: a retry once the keychain cooperates
        // completes the migration.
        throwing.throwOnWriteOf = null;
        await failingStorage.setSyncEnabled(true);
        expect(failingStorage.syncEnabled, isTrue);
        expect(throwing.synced['pinboard_credentials'], 'creds');
        expect(throwing.synced['ai_settings'], 'ai');
        expect(throwing.local.containsKey('pinboard_credentials'), isFalse);
        expect(throwing.local.containsKey('ai_settings'), isFalse);
      },
    );

    test(
      'a failed flag write throws and leaves every local copy intact',
      () async {
        final throwing = _ThrowingSecureStorage(
          throwOnWriteOf: AppSecureStorage.syncFlagKey,
        );
        final failingStorage = AppSecureStorage(storage: throwing);
        await failingStorage.init();
        throwing.local['pinboard_credentials'] = 'creds';
        throwing.local['ai_settings'] = 'ai';

        await expectLater(
          failingStorage.setSyncEnabled(true),
          throwsA(isA<AppSecureStorageException>()),
        );

        // The flag write is the commit point: nothing may flip and no local
        // copy may be deleted when it fails — that is the safe retry state.
        expect(failingStorage.syncEnabled, isFalse);
        expect(throwing.local.containsKey('secrets_sync_enabled'), isFalse);
        expect(throwing.local['pinboard_credentials'], 'creds');
        expect(throwing.local['ai_settings'], 'ai');

        // Retry once the keychain cooperates completes the migration.
        throwing.throwOnWriteOf = null;
        await failingStorage.setSyncEnabled(true);
        expect(failingStorage.syncEnabled, isTrue);
        expect(throwing.synced['pinboard_credentials'], 'creds');
        expect(throwing.synced['ai_settings'], 'ai');
      },
    );

    test(
      'a failed local delete does not fail the enable (best-effort cleanup)',
      () async {
        final throwing = _ThrowingSecureStorage(
          throwOnDeleteOf: 'pinboard_credentials',
        );
        final failingStorage = AppSecureStorage(storage: throwing);
        await failingStorage.init();
        throwing.local['pinboard_credentials'] = 'creds';
        throwing.local['ai_settings'] = 'ai';

        // Must NOT throw: flag and synced set are already consistent.
        await failingStorage.setSyncEnabled(true);

        expect(failingStorage.syncEnabled, isTrue);
        expect(throwing.local['secrets_sync_enabled'], 'true');
        expect(throwing.synced['pinboard_credentials'], 'creds');
        expect(throwing.synced['ai_settings'], 'ai');
        // The leftover local copy is tolerated — it is dormant because all
        // reads and writes now target the synced set.
        expect(throwing.local['pinboard_credentials'], 'creds');
        expect(await failingStorage.read('pinboard_credentials'), 'creds');
      },
    );
  });

  group('disabling sync', () {
    setUp(() async {
      await storage.init();
      await storage.setSyncEnabled(true);
    });

    test(
      'snapshots synced values to local WITHOUT deleting synced items',
      () async {
        fake.synced['pinboard_credentials'] = 'shared';
        await storage.setSyncEnabled(false);
        expect(storage.syncEnabled, isFalse);
        expect(fake.local['pinboard_credentials'], 'shared');
        // CRITICAL: synced item must survive — deletion would propagate to
        // every other Mac via iCloud.
        expect(fake.synced['pinboard_credentials'], 'shared');
      },
    );

    test(
      'subsequent writes stay local and do not touch the synced set',
      () async {
        fake.synced['pinboard_credentials'] = 'shared';
        await storage.setSyncEnabled(false);
        await storage.write('pinboard_credentials', 'local-edit');
        expect(fake.local['pinboard_credentials'], 'local-edit');
        expect(fake.synced['pinboard_credentials'], 'shared');
      },
    );
  });

  test('setSyncEnabled is a no-op when state already matches', () async {
    await storage.init();
    fake.local['pinboard_credentials'] = 'mine';
    await storage.setSyncEnabled(false);
    expect(fake.local['pinboard_credentials'], 'mine');
    expect(fake.synced, isEmpty);
  });
}

/// Throws on writes and/or deletes of one configurable key; everything else
/// behaves normally.
class _ThrowingSecureStorage extends FakeFlutterSecureStorage {
  _ThrowingSecureStorage({this.throwOnWriteOf, this.throwOnDeleteOf});

  String? throwOnWriteOf;
  String? throwOnDeleteOf;

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
    if (key == throwOnWriteOf) {
      throw Exception('keychain write denied');
    }
    return super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
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
    if (key == throwOnDeleteOf) {
      throw Exception('keychain delete denied');
    }
    return super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}
