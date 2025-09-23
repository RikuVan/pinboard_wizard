import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/ai/ai_settings.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_cubit.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_state.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';

class MockCredentialsService extends Mock implements CredentialsService {
  @override
  ValueNotifier<bool> get isAuthenticatedNotifier => super.noSuchMethod(
    Invocation.getter(#isAuthenticatedNotifier),
    returnValue: ValueNotifier<bool>(false),
  );

  @override
  Future<Credentials?> getCredentials() => super.noSuchMethod(
    Invocation.method(#getCredentials, []),
    returnValue: Future.value(null),
  );

  @override
  Future<void> saveCredentials(String apiKey) => super.noSuchMethod(
    Invocation.method(#saveCredentials, [apiKey]),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> clearCredentials() => super.noSuchMethod(
    Invocation.method(#clearCredentials, []),
    returnValue: Future<void>.value(),
  );

  @override
  bool isValidApiKey(String apiKey) => super.noSuchMethod(
    Invocation.method(#isValidApiKey, [apiKey]),
    returnValue: true,
  );
}

class MockPinboardService extends Mock implements PinboardService {
  @override
  Future<bool> testConnection() => super.noSuchMethod(
    Invocation.method(#testConnection, []),
    returnValue: Future.value(true),
  );

  @override
  void dispose() =>
      super.noSuchMethod(Invocation.method(#dispose, []), returnValue: null);
}

class MockAiSettingsService extends Mock implements AiSettingsService {
  @override
  AiSettings get settings => super.noSuchMethod(
    Invocation.getter(#settings),
    returnValue: const AiSettings(),
  );

  @override
  Future<void> setAiEnabled(bool enabled) => super.noSuchMethod(
    Invocation.method(#setAiEnabled, [enabled]),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> setOpenAiApiKey(String? apiKey) => super.noSuchMethod(
    Invocation.method(#setOpenAiApiKey, [apiKey]),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> setJinaApiKey(String? apiKey) => super.noSuchMethod(
    Invocation.method(#setJinaApiKey, [apiKey]),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> setDescriptionMaxLength(int length) => super.noSuchMethod(
    Invocation.method(#setDescriptionMaxLength, [length]),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> setMaxTags(int maxTags) => super.noSuchMethod(
    Invocation.method(#setMaxTags, [maxTags]),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> clearAllAiSettings() => super.noSuchMethod(
    Invocation.method(#clearAllAiSettings, []),
    returnValue: Future<void>.value(),
  );

  @override
  Future<OpenAiTestResult> testOpenAiConnection(String apiKey) =>
      super.noSuchMethod(
        Invocation.method(#testOpenAiConnection, [apiKey]),
        returnValue: Future.value(
          const OpenAiTestResult(
            isValid: true,
            message: 'Connection successful',
          ),
        ),
      );

  @override
  Future<JinaTestResult> testJinaConnection(String? apiKey) =>
      super.noSuchMethod(
        Invocation.method(#testJinaConnection, [apiKey]),
        returnValue: Future.value(
          const JinaTestResult(isValid: true, message: 'Connection successful'),
        ),
      );

  @override
  void addListener(VoidCallback listener) => super.noSuchMethod(
    Invocation.method(#addListener, [listener]),
    returnValue: null,
  );

  @override
  void removeListener(VoidCallback listener) => super.noSuchMethod(
    Invocation.method(#removeListener, [listener]),
    returnValue: null,
  );
}

class MockBackupService extends Mock implements BackupService {
  @override
  S3Config get s3Config => super.noSuchMethod(
    Invocation.getter(#s3Config),
    returnValue: const S3Config(),
  );

  @override
  Future<void> loadConfiguration() => super.noSuchMethod(
    Invocation.method(#loadConfiguration, []),
    returnValue: Future.value(),
  );

  @override
  Future<void> saveConfiguration(S3Config config) => super.noSuchMethod(
    Invocation.method(#saveConfiguration, [config]),
    returnValue: Future.value(),
  );

  @override
  Future<bool> validateConfiguration({
    S3VerificationMethod method = S3VerificationMethod.standard,
  }) => super.noSuchMethod(
    Invocation.method(#validateConfiguration, [], {#method: method}),
    returnValue: Future.value(true),
  );

  @override
  Future<bool> backupBookmarks() => super.noSuchMethod(
    Invocation.method(#backupBookmarks, []),
    returnValue: Future.value(true),
  );

  @override
  Future<void> clearConfiguration() => super.noSuchMethod(
    Invocation.method(#clearConfiguration, []),
    returnValue: Future.value(),
  );

  @override
  void addListener(VoidCallback listener) => super.noSuchMethod(
    Invocation.method(#addListener, [listener]),
    returnValue: null,
  );

  @override
  void removeListener(VoidCallback listener) => super.noSuchMethod(
    Invocation.method(#removeListener, [listener]),
    returnValue: null,
  );

  @override
  void dispose() =>
      super.noSuchMethod(Invocation.method(#dispose, []), returnValue: null);
}

void main() {
  group('SettingsCubit', () {
    late SettingsCubit settingsCubit;
    late MockCredentialsService mockCredentialsService;
    late MockPinboardService mockPinboardService;
    late MockAiSettingsService mockAiSettingsService;
    late MockBackupService mockBackupService;
    late ValueNotifier<bool> mockAuthNotifier;

    setUp(() {
      mockCredentialsService = MockCredentialsService();
      mockPinboardService = MockPinboardService();
      mockAiSettingsService = MockAiSettingsService();
      mockBackupService = MockBackupService();
      mockAuthNotifier = ValueNotifier<bool>(false);

      when(
        mockCredentialsService.isAuthenticatedNotifier,
      ).thenReturn(mockAuthNotifier);
      when(mockAiSettingsService.settings).thenReturn(const AiSettings());
      when(mockBackupService.s3Config).thenReturn(const S3Config());
      when(mockBackupService.loadConfiguration()).thenAnswer((_) async {});

      settingsCubit = SettingsCubit(
        credentialsService: mockCredentialsService,
        pinboardService: mockPinboardService,
        aiSettingsService: mockAiSettingsService,
        backupService: mockBackupService,
      );
    });

    tearDown(() {
      settingsCubit.close();
      mockAuthNotifier.dispose();
    });

    test('initial state is correct', () {
      expect(settingsCubit.state, equals(const SettingsState()));
    });

    group('loadSettings', () {
      blocTest<SettingsCubit, SettingsState>(
        'emits loaded state with credentials and AI settings',
        setUp: () {
          when(
            mockCredentialsService.getCredentials(),
          ).thenAnswer((_) async => const Credentials(apiKey: 'test:apikey'));
          when(mockAiSettingsService.settings).thenReturn(
            const AiSettings(
              isEnabled: true,
              openai: OpenAiSettings(
                apiKey: 'sk-test',
                descriptionMaxLength: 150,
                maxTags: 3,
              ),
              webScraping: WebScrapingSettings(jinaApiKey: 'jina-key'),
            ),
          );
          mockAuthNotifier.value = true;
          when(
            mockAiSettingsService.testOpenAiConnection('sk-test'),
          ).thenAnswer(
            (_) async =>
                const OpenAiTestResult(isValid: true, message: 'Valid'),
          );
          when(mockAiSettingsService.testJinaConnection('jina-key')).thenAnswer(
            (_) async => const JinaTestResult(isValid: true, message: 'Valid'),
          );
        },
        build: () => settingsCubit,
        act: (cubit) => cubit.loadSettings(),
        expect: () => [
          const SettingsState(
            status: SettingsStatus.loading,
            isPinboardAuthenticated: true,
          ),
          const SettingsState(
            status: SettingsStatus.loaded,
            pinboardApiKey: 'test:apikey',
            isPinboardAuthenticated: true,
            isAiEnabled: true,
            openAiApiKey: 'sk-test',
            jinaApiKey: 'jina-key',
            descriptionMaxLength: 150,
            maxTags: 3,
          ),
          const SettingsState(
            status: SettingsStatus.loaded,
            pinboardApiKey: 'test:apikey',
            isPinboardAuthenticated: true,
            isAiEnabled: true,
            openAiApiKey: 'sk-test',
            jinaApiKey: 'jina-key',
            descriptionMaxLength: 150,
            maxTags: 3,
            openAiValidationStatus: ValidationStatus.validating,
          ),
          const SettingsState(
            status: SettingsStatus.loaded,
            pinboardApiKey: 'test:apikey',
            isPinboardAuthenticated: true,
            isAiEnabled: true,
            openAiApiKey: 'sk-test',
            jinaApiKey: 'jina-key',
            descriptionMaxLength: 150,
            maxTags: 3,
            openAiValidationStatus: ValidationStatus.validating,
            jinaValidationStatus: ValidationStatus.validating,
          ),
          const SettingsState(
            status: SettingsStatus.loaded,
            pinboardApiKey: 'test:apikey',
            isPinboardAuthenticated: true,
            isAiEnabled: true,
            openAiApiKey: 'sk-test',
            jinaApiKey: 'jina-key',
            descriptionMaxLength: 150,
            maxTags: 3,
            openAiValidationStatus: ValidationStatus.valid,
            openAiValidationMessage: 'Valid API key - connection successful',
            jinaValidationStatus: ValidationStatus.validating,
          ),
          const SettingsState(
            status: SettingsStatus.loaded,
            pinboardApiKey: 'test:apikey',
            isPinboardAuthenticated: true,
            isAiEnabled: true,
            openAiApiKey: 'sk-test',
            jinaApiKey: 'jina-key',
            descriptionMaxLength: 150,
            maxTags: 3,
            openAiValidationStatus: ValidationStatus.valid,
            openAiValidationMessage: 'Valid API key - connection successful',
            jinaValidationStatus: ValidationStatus.valid,
            jinaValidationMessage: 'Valid',
          ),
        ],
      );

      blocTest<SettingsCubit, SettingsState>(
        'emits error state when loading fails',
        setUp: () {
          when(
            mockCredentialsService.getCredentials(),
          ).thenThrow(Exception('Failed to load'));
        },
        build: () => settingsCubit,
        act: (cubit) => cubit.loadSettings(),
        expect: () => [
          const SettingsState(status: SettingsStatus.loading),
          const SettingsState(
            status: SettingsStatus.error,
            errorMessage: 'Failed to load settings: Exception: Failed to load',
          ),
        ],
      );
    });

    group('updatePinboardApiKey', () {
      blocTest<SettingsCubit, SettingsState>(
        'updates pinboard API key in state',
        setUp: () {
          when(
            mockCredentialsService.isValidApiKey('test:key'),
          ).thenReturn(true);
        },
        build: () => settingsCubit,
        act: (cubit) => cubit.updatePinboardApiKey('test:key'),
        expect: () => [const SettingsState(pinboardApiKey: 'test:key')],
      );

      blocTest<SettingsCubit, SettingsState>(
        'resets validation status for invalid key',
        setUp: () {
          when(
            mockCredentialsService.isValidApiKey('invalid'),
          ).thenReturn(false);
        },
        build: () => settingsCubit,
        act: (cubit) => cubit.updatePinboardApiKey('invalid'),
        expect: () => [
          const SettingsState(
            pinboardApiKey: 'invalid',
            pinboardValidationStatus: ValidationStatus.initial,
          ),
        ],
      );
    });

    group('savePinboardApiKey', () {
      blocTest<SettingsCubit, SettingsState>(
        'saves valid API key and tests connection successfully',
        setUp: () {
          when(
            mockCredentialsService.isValidApiKey('test:key'),
          ).thenReturn(true);
          when(
            mockCredentialsService.saveCredentials('test:key'),
          ).thenAnswer((_) async {});
          when(
            mockPinboardService.testConnection(),
          ).thenAnswer((_) async => true);
        },
        build: () => settingsCubit,
        seed: () => const SettingsState(pinboardApiKey: 'test:key'),
        act: (cubit) => cubit.savePinboardApiKey(),
        expect: () => [
          const SettingsState(
            pinboardApiKey: 'test:key',
            status: SettingsStatus.saving,
          ),
          const SettingsState(
            pinboardApiKey: 'test:key',
            status: SettingsStatus.saving,
            isPinboardTesting: true,
          ),
          const SettingsState(
            pinboardApiKey: 'test:key',
            status: SettingsStatus.loaded,
            pinboardValidationStatus: ValidationStatus.valid,
            pinboardValidationMessage: 'Valid API key - connection successful',
          ),
        ],
      );

      blocTest<SettingsCubit, SettingsState>(
        'emits error for invalid API key',
        setUp: () {
          when(
            mockCredentialsService.isValidApiKey('invalid'),
          ).thenReturn(false);
        },
        build: () => settingsCubit,
        seed: () => const SettingsState(pinboardApiKey: 'invalid'),
        act: (cubit) => cubit.savePinboardApiKey(),
        expect: () => [
          const SettingsState(
            pinboardApiKey: 'invalid',
            errorMessage: 'Invalid API key. Expected: username:hexstring',
          ),
        ],
      );
    });

    group('clearPinboardApiKey', () {
      blocTest<SettingsCubit, SettingsState>(
        'clears API key successfully',
        setUp: () {
          when(
            mockCredentialsService.clearCredentials(),
          ).thenAnswer((_) async {});
        },
        build: () => settingsCubit,
        seed: () => const SettingsState(
          pinboardApiKey: 'test:key',
          pinboardValidationStatus: ValidationStatus.valid,
        ),
        act: (cubit) => cubit.clearPinboardApiKey(),
        expect: () => [
          const SettingsState(
            pinboardApiKey: '',
            pinboardValidationStatus: ValidationStatus.initial,
          ),
        ],
      );
    });

    group('AI settings', () {
      blocTest<SettingsCubit, SettingsState>(
        'setAiEnabled updates AI enabled state',
        setUp: () {
          when(
            mockAiSettingsService.setAiEnabled(true),
          ).thenAnswer((_) async {});
        },
        build: () => settingsCubit,
        act: (cubit) => cubit.setAiEnabled(true),
        expect: () => [const SettingsState(isAiEnabled: true)],
      );

      blocTest<SettingsCubit, SettingsState>(
        'saveOpenAiKey saves and validates key',
        setUp: () {
          when(
            mockAiSettingsService.setOpenAiApiKey('sk-test'),
          ).thenAnswer((_) async {});
          when(
            mockAiSettingsService.testOpenAiConnection('sk-test'),
          ).thenAnswer(
            (_) async =>
                const OpenAiTestResult(isValid: true, message: 'Valid'),
          );
        },
        build: () => settingsCubit,
        seed: () => const SettingsState(openAiApiKey: 'sk-test'),
        act: (cubit) => cubit.saveOpenAiKey(),
        expect: () => [
          const SettingsState(
            openAiApiKey: 'sk-test',
            openAiValidationStatus: ValidationStatus.validating,
          ),
          const SettingsState(
            openAiApiKey: 'sk-test',
            openAiValidationStatus: ValidationStatus.valid,
            openAiValidationMessage: 'Valid API key - connection successful',
          ),
        ],
      );

      blocTest<SettingsCubit, SettingsState>(
        'setDescriptionMaxLength updates setting',
        setUp: () {
          when(
            mockAiSettingsService.setDescriptionMaxLength(200),
          ).thenAnswer((_) async {});
        },
        build: () => settingsCubit,
        act: (cubit) => cubit.setDescriptionMaxLength(200),
        expect: () => [const SettingsState(descriptionMaxLength: 200)],
      );

      blocTest<SettingsCubit, SettingsState>(
        'setMaxTags updates setting',
        setUp: () {
          when(mockAiSettingsService.setMaxTags(8)).thenAnswer((_) async {});
        },
        build: () => settingsCubit,
        act: (cubit) => cubit.setMaxTags(8),
        expect: () => [const SettingsState(maxTags: 8)],
      );
    });

    group('validation', () {
      blocTest<SettingsCubit, SettingsState>(
        'testOpenAiConnection validates OpenAI key',
        setUp: () {
          when(
            mockAiSettingsService.testOpenAiConnection('sk-test'),
          ).thenAnswer(
            (_) async =>
                const OpenAiTestResult(isValid: false, message: 'Invalid key'),
          );
        },
        build: () => settingsCubit,
        seed: () => const SettingsState(openAiApiKey: 'sk-test'),
        act: (cubit) => cubit.testOpenAiConnection(),
        expect: () => [
          const SettingsState(
            openAiApiKey: 'sk-test',
            openAiValidationStatus: ValidationStatus.validating,
          ),
          const SettingsState(
            openAiApiKey: 'sk-test',
            openAiValidationStatus: ValidationStatus.invalid,
            openAiValidationMessage: 'Invalid key',
          ),
        ],
      );

      blocTest<SettingsCubit, SettingsState>(
        'testJinaConnection validates Jina key',
        setUp: () {
          when(mockAiSettingsService.testJinaConnection('jina-key')).thenAnswer(
            (_) async => const JinaTestResult(isValid: true, message: 'Valid'),
          );
        },
        build: () => settingsCubit,
        seed: () => const SettingsState(jinaApiKey: 'jina-key'),
        act: (cubit) => cubit.testJinaConnection(),
        expect: () => [
          const SettingsState(
            jinaApiKey: 'jina-key',
            jinaValidationStatus: ValidationStatus.validating,
          ),
          const SettingsState(
            jinaApiKey: 'jina-key',
            jinaValidationStatus: ValidationStatus.valid,
            jinaValidationMessage: 'Valid',
          ),
        ],
      );
    });

    group('clearError', () {
      blocTest<SettingsCubit, SettingsState>(
        'clears error message',
        build: () => settingsCubit,
        seed: () => const SettingsState(errorMessage: 'Test error'),
        act: (cubit) => cubit.clearError(),
        expect: () => [const SettingsState()],
      );
    });
  });
}
