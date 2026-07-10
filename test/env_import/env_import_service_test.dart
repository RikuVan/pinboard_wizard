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
