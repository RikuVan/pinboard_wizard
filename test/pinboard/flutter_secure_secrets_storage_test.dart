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
    expect(
      fake.local['pinboard_credentials'],
      contains('user:abcdef0123456789'),
    );
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

  test(
    'credentials written while synced are read back through synced set',
    () async {
      await appStorage.setSyncEnabled(true);
      await storage.save(const Credentials(apiKey: 'user:abcdef0123456789'));
      expect(fake.synced.containsKey('pinboard_credentials'), isTrue);
      expect(
        await storage.read(),
        const Credentials(apiKey: 'user:abcdef0123456789'),
      );
    },
  );
}
