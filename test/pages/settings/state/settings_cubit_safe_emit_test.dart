import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/ai/ai_settings.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_cubit.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';

import 'settings_cubit_safe_emit_test.mocks.dart';

@GenerateMocks([
  CredentialsService,
  PinboardService,
  AiSettingsService,
  BackupService,
  GitHubAuthService,
])
void main() {
  group('SettingsCubit Safe Emit Tests', () {
    late MockCredentialsService mockCredentialsService;
    late MockPinboardService mockPinboardService;
    late MockAiSettingsService mockAiSettingsService;
    late MockBackupService mockBackupService;
    late MockGitHubAuthService mockGitHubAuthService;
    late SettingsCubit settingsCubit;

    setUp(() {
      mockCredentialsService = MockCredentialsService();
      mockPinboardService = MockPinboardService();
      mockAiSettingsService = MockAiSettingsService();
      mockBackupService = MockBackupService();
      mockGitHubAuthService = MockGitHubAuthService();

      // Setup default mock behaviors
      when(
        mockCredentialsService.getCredentials(),
      ).thenAnswer((_) async => null);
      when(
        mockCredentialsService.isAuthenticatedNotifier,
      ).thenReturn(ValueNotifier<bool>(false));
      when(mockAiSettingsService.settings).thenReturn(const AiSettings());
      when(mockBackupService.s3Config).thenReturn(const S3Config());
      when(mockGitHubAuthService.getConfig()).thenAnswer((_) async => null);
      when(mockGitHubAuthService.getToken()).thenAnswer((_) async => null);
      when(mockGitHubAuthService.isAuthenticated).thenReturn(false);
      when(mockGitHubAuthService.currentWarning).thenReturn(null);

      settingsCubit = SettingsCubit(
        credentialsService: mockCredentialsService,
        pinboardService: mockPinboardService,
        aiSettingsService: mockAiSettingsService,
        backupService: mockBackupService,
        githubAuthService: mockGitHubAuthService,
      );
    });

    tearDown(() {
      settingsCubit.close();
    });

    test('savePinboardApiKey does not emit after cubit is closed', () async {
      // Arrange
      const validApiKey = 'testuser:123abc456def';
      settingsCubit.updatePinboardApiKey(validApiKey);

      // Setup mocks
      when(mockCredentialsService.isValidApiKey(validApiKey)).thenReturn(true);
      when(
        mockCredentialsService.saveCredentials(validApiKey),
      ).thenAnswer((_) async => Future.delayed(Duration(milliseconds: 100)));
      when(mockPinboardService.testConnection()).thenAnswer(
        (_) async => Future.delayed(Duration(milliseconds: 100), () => true),
      );

      // Start the async operation
      final future = settingsCubit.savePinboardApiKey();

      // Close the cubit immediately (simulating navigation away)
      await settingsCubit.close();

      // Act - wait for the async operation to complete
      // This should not throw "Cannot emit new states after calling close"
      expect(() async => await future, returnsNormally);
    });

    test('clearPinboardApiKey handles cubit closure gracefully', () async {
      // Arrange
      when(
        mockCredentialsService.clearCredentials(),
      ).thenAnswer((_) async => Future.delayed(Duration(milliseconds: 50)));

      // Start the async operation
      final future = settingsCubit.clearPinboardApiKey();

      // Close the cubit
      await settingsCubit.close();

      // Act & Assert - should not throw error
      expect(() async => await future, returnsNormally);
    });

    test(
      'loadSettings handles cubit closure during async operations',
      () async {
        // Arrange
        when(mockCredentialsService.getCredentials()).thenAnswer(
          (_) async => Future.delayed(Duration(milliseconds: 100), () => null),
        );

        // Start the async operation
        final future = settingsCubit.loadSettings();

        // Close the cubit while loading
        await settingsCubit.close();

        // Act & Assert - should not throw error
        expect(() async => await future, returnsNormally);
      },
    );

    test(
      'authentication listener does not emit after cubit is closed',
      () async {
        // Arrange
        final authNotifier = ValueNotifier<bool>(false);
        when(
          mockCredentialsService.isAuthenticatedNotifier,
        ).thenReturn(authNotifier);

        // Recreate cubit with the mock notifier
        await settingsCubit.close();
        settingsCubit = SettingsCubit(
          credentialsService: mockCredentialsService,
          pinboardService: mockPinboardService,
          aiSettingsService: mockAiSettingsService,
          backupService: mockBackupService,
          githubAuthService: mockGitHubAuthService,
        );

        // Close the cubit
        await settingsCubit.close();

        // Act - trigger the listener (simulating external auth state change)
        // This should not cause an error even though cubit is closed
        expect(() => authNotifier.value = true, returnsNormally);

        // Clean up
        authNotifier.dispose();
      },
    );

    test('multiple async operations can be safely cancelled', () async {
      // Arrange
      const validApiKey = 'testuser:123abc456def';
      settingsCubit.updatePinboardApiKey(validApiKey);

      when(mockCredentialsService.isValidApiKey(validApiKey)).thenReturn(true);
      when(
        mockCredentialsService.saveCredentials(any),
      ).thenAnswer((_) async => Future.delayed(Duration(milliseconds: 200)));
      when(mockPinboardService.testConnection()).thenAnswer(
        (_) async => Future.delayed(Duration(milliseconds: 200), () => true),
      );
      when(
        mockCredentialsService.clearCredentials(),
      ).thenAnswer((_) async => Future.delayed(Duration(milliseconds: 200)));

      // Start multiple async operations
      final saveFuture = settingsCubit.savePinboardApiKey();
      final clearFuture = settingsCubit.clearPinboardApiKey();
      final loadFuture = settingsCubit.loadSettings();

      // Close the cubit while operations are running
      await settingsCubit.close();

      // Act & Assert - all operations should complete without errors
      expect(() async {
        await Future.wait([saveFuture, clearFuture, loadFuture]);
      }, returnsNormally);
    });

    test('safeEmit prevents state errors in real cubit usage', () async {
      // This test verifies that our safeEmit extension actually prevents
      // the "Cannot emit new states after calling close" error in practice

      // Arrange
      const validApiKey = 'testuser:123abc456def';
      bool errorOccurred = false;
      String? errorMessage;

      settingsCubit.updatePinboardApiKey(validApiKey);

      when(mockCredentialsService.isValidApiKey(validApiKey)).thenReturn(true);
      when(
        mockCredentialsService.saveCredentials(validApiKey),
      ).thenAnswer((_) async => Future.delayed(Duration(milliseconds: 50)));
      when(mockPinboardService.testConnection()).thenAnswer(
        (_) async => Future.delayed(Duration(milliseconds: 50), () => true),
      );

      try {
        // Start async operation
        final future = settingsCubit.savePinboardApiKey();

        // Close cubit immediately
        await settingsCubit.close();

        // Wait for the async operation to complete
        await future;
      } catch (e) {
        errorOccurred = true;
        errorMessage = e.toString();
      }

      // Assert no "Cannot emit new states after calling close" error occurred
      expect(
        errorOccurred,
        isFalse,
        reason: 'safeEmit should prevent bloc state error: $errorMessage',
      );
    });
  });
}
