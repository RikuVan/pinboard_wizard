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

    final stored =
        json.decode(fake.local['ai_settings']!) as Map<String, dynamic>;
    expect((stored['openai'] as Map<String, dynamic>)['apiKey'], 'sk-test-key');
    expect(service.openaiSettings.apiKey, 'sk-test-key');
  });

  test('persists Jina key via AppSecureStorage', () async {
    final service = AiSettingsService(storage: appStorage);
    await service.setJinaApiKey('jina-test-key-123');

    final stored =
        json.decode(fake.local['ai_settings']!) as Map<String, dynamic>;
    expect(
      (stored['webScraping'] as Map<String, dynamic>)['jinaApiKey'],
      'jina-test-key-123',
    );
  });

  test('loads previously stored settings on construction', () async {
    fake.local['ai_settings'] = json.encode({
      'isEnabled': true,
      'openai': {
        'apiKey': 'sk-existing',
        'descriptionMaxLength': 80,
        'maxTags': 3,
      },
      'webScraping': {'jinaApiKey': null},
    });

    final service = AiSettingsService(storage: appStorage);
    // _loadSettings is fire-and-forget in the constructor; let it complete.
    await Future<void>.delayed(Duration.zero);

    expect(service.settings.isEnabled, isTrue);
    expect(service.openaiSettings.apiKey, 'sk-existing');
  });
}
