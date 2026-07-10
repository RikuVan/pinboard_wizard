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
