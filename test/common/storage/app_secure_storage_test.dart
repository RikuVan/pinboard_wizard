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
