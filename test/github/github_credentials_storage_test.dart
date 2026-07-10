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
