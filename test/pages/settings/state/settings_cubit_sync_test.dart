import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Future<void> initWith(FakeFlutterSecureStorage storageFake) async {
    fake = storageFake;
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
  }

  setUp(() => initWith(FakeFlutterSecureStorage()));

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

  test(
    'setSecretsSyncEnabled failure keeps the flag off and surfaces the error',
    () async {
      await cubit.close();
      final throwing = _ThrowingSyncStorage(
        throwOnWriteOf: 'pinboard_credentials',
      );
      await initWith(throwing);
      throwing.local['pinboard_credentials'] = '{"apiKey":"user:abc"}';

      await cubit.setSecretsSyncEnabled(true);

      expect(cubit.state.secretsSyncEnabled, isFalse);
      expect(cubit.state.syncErrorMessage, isNotNull);
      expect(cubit.state.syncErrorMessage, contains('enable'));

      // Retry once the keychain cooperates: succeeds and clears the error.
      throwing.throwOnWriteOf = null;
      await cubit.setSecretsSyncEnabled(true);
      expect(cubit.state.secretsSyncEnabled, isTrue);
      expect(cubit.state.syncErrorMessage, isNull);
    },
  );

  test('previewEnvImport reports recognized variables', () {
    final preview = cubit.previewEnvImport('OPENAI_API_KEY=sk-1\nRANDOM=2\n');
    expect(preview.recognized.keys, ['OPENAI_API_KEY']);
    expect(preview.unrecognized, ['RANDOM']);
  });

  test(
    'importEnvVariables applies values and sets a summary message',
    () async {
      await cubit.importEnvVariables({'OPENAI_API_KEY': 'sk-1'});

      expect(cubit.state.envImportMessage, contains('1'));
      expect(aiSettingsService.openaiSettings.apiKey, 'sk-1');
    },
  );

  test(
    'importEnvVariables clears the stale message before a new import',
    () async {
      await cubit.importEnvVariables({'OPENAI_API_KEY': 'sk-1'});
      expect(cubit.state.envImportMessage, isNotNull);

      final messages = <String?>[];
      final subscription = cubit.stream.listen(
        (state) => messages.add(state.envImportMessage),
      );
      await cubit.importEnvVariables({'JINA_API_KEY': 'jina-1'});
      await subscription.cancel();

      // The very first emission of the second import clears the old banner.
      expect(messages.first, isNull);
      expect(cubit.state.envImportMessage, contains('1'));
    },
  );

  test('clearEnvImportMessage dismisses the banner', () async {
    await cubit.importEnvVariables({'OPENAI_API_KEY': 'sk-1'});
    expect(cubit.state.envImportMessage, isNotNull);

    cubit.clearEnvImportMessage();

    expect(cubit.state.envImportMessage, isNull);
  });
}

/// Throws on writes of one configurable key; everything else behaves normally.
class _ThrowingSyncStorage extends FakeFlutterSecureStorage {
  _ThrowingSyncStorage({required this.throwOnWriteOf});

  String? throwOnWriteOf;

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
}
