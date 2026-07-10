import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    test('skips recognized variables with empty values', () {
      final preview = service.preview(
        'OPENAI_API_KEY=\nPINBOARD_API_TOKEN=user:abc\n',
      );
      expect(preview.recognized, {'PINBOARD_API_TOKEN': 'user:abc'});
      expect(preview.unrecognized, isEmpty);
      // The empty assignment counts as an ignored line — importing it
      // would clear the stored credential.
      expect(preview.ignoredLines, 1);
    });
  });

  group('apply', () {
    test('imports pinboard token and authenticates', () async {
      final result = await service.apply({
        'PINBOARD_API_TOKEN': 'user:abc123def',
      });

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
      await backupService.saveConfiguration(
        const S3Config(
          accessKey: 'OLD_ACCESS',
          secretKey: 'OLD_SECRET',
          region: 'us-east-1',
          bucketName: 'old-bucket',
        ),
      );

      await service.apply({'AWS_SECRET_ACCESS_KEY': 'NEW_SECRET'});

      expect(backupService.s3Config.secretKey, 'NEW_SECRET');
      expect(backupService.s3Config.accessKey, 'OLD_ACCESS');
      expect(backupService.s3Config.bucketName, 'old-bucket');
    });

    test(
      'creates a GitHub config with generated deviceId when none exists',
      () async {
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
      },
    );

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

    test(
      'GitHub config without token is saved but not marked configured',
      () async {
        await service.apply({
          'GITHUB_OWNER': 'octocat',
          'GITHUB_REPO': 'notes',
        });

        final config = await githubStorage.readConfig();
        expect(config?.owner, 'octocat');
        expect(config?.isConfigured, isFalse);
      },
    );

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

    test('S3 save failure is reported as failed, not applied', () async {
      // BackupService.saveConfiguration swallows storage errors into
      // status/lastError instead of throwing; apply() must still report them.
      final throwingFake = _ThrowingBackupStorage();
      final throwingAppStorage = AppSecureStorage(storage: throwingFake);
      await throwingAppStorage.init();
      final failingBackupService = BackupService(storage: throwingAppStorage);
      final failingService = EnvImportService(
        credentialsService: credentialsService,
        aiSettingsService: aiSettingsService,
        backupService: failingBackupService,
        githubStorage: githubStorage,
        githubAuthService: githubAuthService,
      );

      final result = await failingService.apply({
        'AWS_SECRET_ACCESS_KEY': 'X',
        'OPENAI_API_KEY': 'sk-ok',
      });

      expect(result.failed.keys, contains('AWS_SECRET_ACCESS_KEY'));
      expect(result.applied, isNot(contains('AWS_SECRET_ACCESS_KEY')));
      expect(result.applied, contains('OPENAI_API_KEY'));
    });

    test('S3 load failure fails the S3 keys and skips the save', () async {
      // A failed load must not be merged into (and overwrite) whatever the
      // real stored config is.
      final throwingFake = _ThrowingReadBackupStorage();
      final throwingAppStorage = AppSecureStorage(storage: throwingFake);
      await throwingAppStorage.init();
      final failingBackupService = BackupService(storage: throwingAppStorage);
      final failingService = EnvImportService(
        credentialsService: credentialsService,
        aiSettingsService: aiSettingsService,
        backupService: failingBackupService,
        githubStorage: githubStorage,
        githubAuthService: githubAuthService,
      );

      final result = await failingService.apply({
        'AWS_ACCESS_KEY_ID': 'AKIA123',
        'AWS_SECRET_ACCESS_KEY': 'X',
        'OPENAI_API_KEY': 'sk-ok',
      });

      expect(
        result.failed.keys,
        containsAll(['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']),
      );
      expect(result.applied, isNot(contains('AWS_ACCESS_KEY_ID')));
      expect(result.applied, isNot(contains('AWS_SECRET_ACCESS_KEY')));
      expect(result.applied, contains('OPENAI_API_KEY'));
      // Nothing was saved.
      expect(throwingFake.local.containsKey('backup_s3_config'), isFalse);
      expect(throwingFake.synced.containsKey('backup_s3_config'), isFalse);
    });

    test('a stale backup error does not fail a later S3 import', () async {
      final flakyFake = _ThrowingBackupStorage();
      final flakyAppStorage = AppSecureStorage(storage: flakyFake);
      await flakyAppStorage.init();
      final flakyBackupService = BackupService(storage: flakyAppStorage);
      // Drive the service into an error state with a failed save…
      await flakyBackupService.saveConfiguration(const S3Config());
      expect(flakyBackupService.status, BackupStatus.error);

      // …then let the storage work again: apply() must not mistake the
      // stale error for a load failure.
      flakyFake.throwing = false;
      final workingService = EnvImportService(
        credentialsService: credentialsService,
        aiSettingsService: aiSettingsService,
        backupService: flakyBackupService,
        githubStorage: githubStorage,
        githubAuthService: githubAuthService,
      );

      final result = await workingService.apply({'AWS_REGION': 'eu-west-1'});

      expect(result.applied, ['AWS_REGION']);
      expect(result.failed, isEmpty);
      expect(flakyBackupService.s3Config.region, 'eu-west-1');
    });

    test(
      'GitHub token save failure fails only GITHUB_PAT; config persists',
      () async {
        final throwingFake = _ThrowingTokenStorage();
        final throwingAppStorage = AppSecureStorage(storage: throwingFake);
        await throwingAppStorage.init();
        final failingGithubStorage = GitHubCredentialsStorage(
          storage: throwingAppStorage,
        );
        final failingService = EnvImportService(
          credentialsService: credentialsService,
          aiSettingsService: aiSettingsService,
          backupService: backupService,
          githubStorage: failingGithubStorage,
          githubAuthService: GitHubAuthService(storage: failingGithubStorage),
        );

        final result = await failingService.apply({
          'GITHUB_OWNER': 'octocat',
          'GITHUB_REPO': 'notes',
          'GITHUB_PAT': 'ghp_secret123',
        });

        expect(result.applied, containsAll(['GITHUB_OWNER', 'GITHUB_REPO']));
        expect(result.failed.keys, ['GITHUB_PAT']);
        final config = await failingGithubStorage.readConfig();
        expect(config?.owner, 'octocat');
        expect(config?.repo, 'notes');
        expect(await failingGithubStorage.readToken(), isNull);
      },
    );
  });
}

/// Fails writes of the S3 backup config key while [throwing] is set;
/// everything else behaves normally.
class _ThrowingBackupStorage extends FakeFlutterSecureStorage {
  bool throwing = true;
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
    if (throwing && key == 'backup_s3_config') {
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
}

/// Fails reads of the S3 backup config key; everything else behaves normally.
class _ThrowingReadBackupStorage extends FakeFlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == 'backup_s3_config') {
      throw Exception('keychain read denied');
    }
    return super.read(
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

/// Fails writes of the GitHub PAT key; everything else behaves normally.
class _ThrowingTokenStorage extends FakeFlutterSecureStorage {
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
    if (key == 'github_pat_token') {
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
}
