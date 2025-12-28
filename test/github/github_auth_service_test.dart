import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/github/models/models.dart';

import 'github_auth_service_test.mocks.dart';

@GenerateMocks([GitHubCredentialsStorage])
void main() {
  late MockGitHubCredentialsStorage mockStorage;
  late GitHubAuthService authService;

  setUp(() {
    mockStorage = MockGitHubCredentialsStorage();
    authService = GitHubAuthService(storage: mockStorage);
  });

  group('GitHubAuthService', () {
    group('initialize', () {
      test('sets isAuthenticated to true when configured', () async {
        // Arrange
        when(mockStorage.isConfigured()).thenAnswer((_) async => true);
        when(mockStorage.readConfig()).thenAnswer((_) async => null);

        // Act
        await authService.initialize();

        // Assert
        expect(authService.isAuthenticated, true);
      });

      test('sets isAuthenticated to false when not configured', () async {
        // Arrange
        when(mockStorage.isConfigured()).thenAnswer((_) async => false);
        when(mockStorage.readConfig()).thenAnswer((_) async => null);

        // Act
        await authService.initialize();

        // Assert
        expect(authService.isAuthenticated, false);
      });
    });

    group('isTokenExpiringSoon', () {
      test('returns false when tokenExpiry is null', () {
        // Arrange
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: null,
        );

        // Act
        final result = authService.isTokenExpiringSoon(config);

        // Assert
        expect(result, false);
      });

      test('returns true when token expires in 7 days', () {
        // Arrange
        final expiryDate = DateTime.now().add(const Duration(days: 7));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
        );

        // Act
        final result = authService.isTokenExpiringSoon(config);

        // Assert
        expect(result, true);
      });

      test('returns true when token expires in less than 7 days', () {
        // Arrange
        final expiryDate = DateTime.now().add(const Duration(days: 3));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
        );

        // Act
        final result = authService.isTokenExpiringSoon(config);

        // Assert
        expect(result, true);
      });

      test('returns false when token expires in more than 7 days', () {
        // Arrange
        final expiryDate = DateTime.now().add(const Duration(days: 14));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
        );

        // Act
        final result = authService.isTokenExpiringSoon(config);

        // Assert
        expect(result, false);
      });
    });

    group('isTokenExpired', () {
      test('returns false when tokenExpiry is null', () {
        // Arrange
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: null,
        );

        // Act
        final result = authService.isTokenExpired(config);

        // Assert
        expect(result, false);
      });

      test('returns true when token is expired', () {
        // Arrange
        final expiryDate = DateTime.now().subtract(const Duration(days: 1));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
        );

        // Act
        final result = authService.isTokenExpired(config);

        // Assert
        expect(result, true);
      });

      test('returns false when token is not expired', () {
        // Arrange
        final expiryDate = DateTime.now().add(const Duration(days: 30));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
        );

        // Act
        final result = authService.isTokenExpired(config);

        // Assert
        expect(result, false);
      });
    });

    group('getDaysUntilExpiry', () {
      test('returns null when tokenExpiry is null', () {
        // Arrange
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: null,
        );

        // Act
        final result = authService.getDaysUntilExpiry(config);

        // Assert
        expect(result, null);
      });

      test('returns correct number of days', () {
        // Arrange
        final now = DateTime.now();
        final expiryDate = now.add(const Duration(days: 15));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
        );

        // Act
        final result = authService.getDaysUntilExpiry(config);

        // Assert
        expect(result, greaterThanOrEqualTo(14));
        expect(result, lessThanOrEqualTo(15));
      });

      test('returns negative days for expired token', () {
        // Arrange
        final expiryDate = DateTime.now().subtract(const Duration(days: 5));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
        );

        // Act
        final result = authService.getDaysUntilExpiry(config);

        // Assert
        expect(result, -5);
      });
    });

    group('checkTokenExpiry', () {
      test('clears warning when config is null', () async {
        // Arrange
        when(mockStorage.readConfig()).thenAnswer((_) async => null);

        // Act
        await authService.checkTokenExpiry();

        // Assert
        expect(authService.currentWarning, null);
      });

      test('clears warning when token expiry is null', () async {
        // Arrange
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: null,
          isConfigured: true,
        );
        when(mockStorage.readConfig()).thenAnswer((_) async => config);

        // Act
        await authService.checkTokenExpiry();

        // Assert
        expect(authService.currentWarning, null);
      });

      test('creates high severity warning when token is expired', () async {
        // Arrange
        final expiryDate = DateTime.now().subtract(const Duration(days: 1));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
          isConfigured: true,
        );
        when(mockStorage.readConfig()).thenAnswer((_) async => config);

        // Act
        await authService.checkTokenExpiry();

        // Assert
        expect(authService.currentWarning, isNotNull);
        expect(authService.currentWarning!.severity, WarningSeverity.high);
        expect(authService.currentWarning!.daysRemaining, 0);
        expect(authService.isAuthenticated, false);
      });

      test('creates warning when token expires within 7 days', () async {
        // Arrange
        final expiryDate = DateTime.now().add(const Duration(days: 5));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
          isConfigured: true,
        );
        when(mockStorage.readConfig()).thenAnswer((_) async => config);

        // Act
        await authService.checkTokenExpiry();

        // Assert
        expect(authService.currentWarning, isNotNull);
        expect(
          authService.currentWarning!.daysRemaining,
          greaterThanOrEqualTo(4),
        );
        expect(authService.currentWarning!.daysRemaining, lessThanOrEqualTo(5));
      });

      test('clears warning when token expires in more than 7 days', () async {
        // Arrange
        final expiryDate = DateTime.now().add(const Duration(days: 30));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
          isConfigured: true,
        );
        when(mockStorage.readConfig()).thenAnswer((_) async => config);

        // Act
        await authService.checkTokenExpiry();

        // Assert
        expect(authService.currentWarning, null);
      });
    });

    group('handleAuthError', () {
      test('returns true and sets warning for 401 status', () async {
        // Act
        final result = await authService.handleAuthError(401);

        // Assert
        expect(result, true);
        expect(authService.isAuthenticated, false);
        expect(authService.currentWarning, isNotNull);
        expect(authService.currentWarning!.severity, WarningSeverity.high);
      });

      test('returns true and sets warning for 403 status', () async {
        // Act
        final result = await authService.handleAuthError(403);

        // Assert
        expect(result, true);
        expect(authService.isAuthenticated, false);
        expect(authService.currentWarning, isNotNull);
      });

      test('returns false for non-auth errors', () async {
        // Act
        final result = await authService.handleAuthError(404);

        // Assert
        expect(result, false);
      });

      test('uses custom message when provided', () async {
        // Arrange
        const customMessage = 'Custom error message';

        // Act
        await authService.handleAuthError(401, message: customMessage);

        // Assert
        expect(authService.currentWarning!.message, customMessage);
      });
    });

    group('saveCredentials', () {
      test('saves config and token, sets authenticated', () async {
        // Arrange
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          isConfigured: true,
        );
        const token = 'test_token';

        when(
          mockStorage.saveAll(config: config, token: token),
        ).thenAnswer((_) async => {});
        when(mockStorage.readConfig()).thenAnswer((_) async => config);

        // Act
        await authService.saveCredentials(config: config, token: token);

        // Assert
        verify(mockStorage.saveAll(config: config, token: token)).called(1);
        expect(authService.isAuthenticated, true);
      });
    });

    group('updateToken', () {
      test('updates token and checks expiry', () async {
        // Arrange
        const token = 'new_token';
        when(mockStorage.saveToken(token)).thenAnswer((_) async => {});
        when(mockStorage.readConfig()).thenAnswer((_) async => null);

        // Act
        await authService.updateToken(token);

        // Assert
        verify(mockStorage.saveToken(token)).called(1);
        expect(authService.isAuthenticated, true);
      });

      test('updates token expiry when provided', () async {
        // Arrange
        const token = 'new_token';
        final newExpiry = DateTime.now().add(const Duration(days: 180));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          isConfigured: true,
        );
        when(mockStorage.saveToken(token)).thenAnswer((_) async => {});
        when(mockStorage.readConfig()).thenAnswer((_) async => config);
        when(mockStorage.saveConfig(any)).thenAnswer((_) async => {});

        // Act
        await authService.updateToken(token, newExpiry: newExpiry);

        // Assert
        verify(mockStorage.saveToken(token)).called(1);
        verify(
          mockStorage.saveConfig(
            argThat(
              predicate<GitHubNotesConfig>((c) => c.tokenExpiry == newExpiry),
            ),
          ),
        ).called(1);
      });
    });

    group('clearCredentials', () {
      test('clears storage and resets state', () async {
        // Arrange
        when(mockStorage.clearAll()).thenAnswer((_) async => {});

        // Act
        await authService.clearCredentials();

        // Assert
        verify(mockStorage.clearAll()).called(1);
        expect(authService.isAuthenticated, false);
        expect(authService.currentWarning, null);
      });
    });

    group('dismissTokenWarning', () {
      test('clears current warning', () async {
        // Arrange
        final expiryDate = DateTime.now().add(const Duration(days: 5));
        final config = GitHubNotesConfig(
          owner: 'testuser',
          repo: 'testrepo',
          deviceId: 'device123',
          tokenExpiry: expiryDate,
          isConfigured: true,
        );
        when(mockStorage.readConfig()).thenAnswer((_) async => config);
        await authService.checkTokenExpiry();
        expect(authService.currentWarning, isNotNull);

        // Act
        authService.dismissTokenWarning();

        // Assert
        expect(authService.currentWarning, null);
      });
    });
  });
}
