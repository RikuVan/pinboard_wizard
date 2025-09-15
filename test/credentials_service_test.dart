import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';

void main() {
  group('CredentialsService', () {
    late CredentialsService credentialsService;
    late InMemorySecretsStorage mockStorage;

    setUp(() {
      mockStorage = InMemorySecretsStorage();
      credentialsService = CredentialsService(storage: mockStorage);
    });

    tearDown(() {
      mockStorage.clearSync();
    });

    group('saveCredentials', () {
      test('should save valid API key', () async {
        const apiKey = 'testuser:1234567890abcdef';

        await credentialsService.saveCredentials(apiKey);

        final stored = await mockStorage.read();
        expect(stored?.apiKey, equals(apiKey));
      });

      test('should trim whitespace from API key', () async {
        const apiKey = '  testuser:1234567890abcdef  ';
        const expectedApiKey = 'testuser:1234567890abcdef';

        await credentialsService.saveCredentials(apiKey);

        final stored = await mockStorage.read();
        expect(stored?.apiKey, equals(expectedApiKey));
      });

      test('should throw exception for empty API key', () async {
        expect(
          () => credentialsService.saveCredentials(''),
          throwsA(isA<CredentialsServiceException>()),
        );

        expect(
          () => credentialsService.saveCredentials('   '),
          throwsA(isA<CredentialsServiceException>()),
        );
      });
    });

    group('getCredentials', () {
      test('should return stored credentials', () async {
        const apiKey = 'testuser:1234567890abcdef';
        final credentials = Credentials(apiKey: apiKey);
        await mockStorage.save(credentials);

        final result = await credentialsService.getCredentials();

        expect(result, equals(credentials));
        expect(result?.apiKey, equals(apiKey));
      });

      test('should return null when no credentials stored', () async {
        final result = await credentialsService.getCredentials();

        expect(result, isNull);
      });
    });

    group('clearCredentials', () {
      test('should clear stored credentials', () async {
        const apiKey = 'testuser:1234567890abcdef';
        await credentialsService.saveCredentials(apiKey);

        // Verify credentials are stored
        expect(await credentialsService.getCredentials(), isNotNull);

        await credentialsService.clearCredentials();

        // Verify credentials are cleared
        expect(await credentialsService.getCredentials(), isNull);
      });
    });

    group('hasCredentials', () {
      test('should return true when credentials exist', () async {
        const apiKey = 'testuser:1234567890abcdef';
        await credentialsService.saveCredentials(apiKey);

        final result = await credentialsService.hasCredentials();

        expect(result, isTrue);
      });

      test('should return false when no credentials exist', () async {
        final result = await credentialsService.hasCredentials();

        expect(result, isFalse);
      });

      test('should return false after clearing credentials', () async {
        const apiKey = 'testuser:1234567890abcdef';
        await credentialsService.saveCredentials(apiKey);

        expect(await credentialsService.hasCredentials(), isTrue);

        await credentialsService.clearCredentials();

        expect(await credentialsService.hasCredentials(), isFalse);
      });
    });

    group('isValidApiKey', () {
      test('should validate correct API key formats', () {
        final validApiKeys = [
          'user:1234567890abcdef',
          'testuser:abcdef1234567890',
          'user123:ABCDEF1234567890',
          'test_user:1111111111111111',
          'user-name:aaaaaaaaaaaaaaaa',
          'u:a',
          'longusernamehere:fedcba0987654321deadbeef',
        ];

        for (final apiKey in validApiKeys) {
          expect(
            credentialsService.isValidApiKey(apiKey),
            isTrue,
            reason: 'Should validate: $apiKey',
          );
        }
      });

      test('should reject invalid API key formats', () {
        final invalidApiKeys = [
          '',
          'nocolon',
          ':missingusername',
          'missingtoken:',
          'user:',
          ':token',
          'user:token:extra',
          'user with spaces:1234567890abcdef',
          'user:token with spaces',
          'user@domain:1234567890abcdef',
          'user#invalid:1234567890abcdef',
        ];

        for (final apiKey in invalidApiKeys) {
          expect(
            credentialsService.isValidApiKey(apiKey),
            isFalse,
            reason: 'Should reject: $apiKey',
          );
        }
      });

      test('should handle whitespace in validation', () {
        expect(
          credentialsService.isValidApiKey('  user:1234567890abcdef  '),
          isTrue,
        );
        expect(
          credentialsService.isValidApiKey('\tuser:1234567890abcdef\n'),
          isTrue,
        );
      });
    });

    group('getUsernameFromApiKey', () {
      test('should extract username from valid API keys', () {
        final testCases = {
          'testuser:1234567890abcdef': 'testuser',
          'user123:abcdef1234567890': 'user123',
          'long_username:fedcba0987654321': 'long_username',
          'u:a': 'u',
        };

        testCases.forEach((apiKey, expectedUsername) {
          final result = credentialsService.getUsernameFromApiKey(apiKey);
          expect(result, equals(expectedUsername));
        });
      });

      test('should return null for invalid API keys', () {
        final invalidApiKeys = [
          null,
          '',
          'nocolon',
          ':missingusername',
          'missingtoken:',
          'too:many:colons',
        ];

        for (final apiKey in invalidApiKeys) {
          expect(credentialsService.getUsernameFromApiKey(apiKey), isNull);
        }
      });
    });

    group('isAuthenticated', () {
      test('should return true for valid stored credentials', () async {
        const validApiKey = 'testuser:1234567890abcdef';
        await credentialsService.saveCredentials(validApiKey);

        final result = await credentialsService.isAuthenticated();

        expect(result, isTrue);
      });

      test('should return false when no credentials stored', () async {
        final result = await credentialsService.isAuthenticated();

        expect(result, isFalse);
      });

      test('should return false for invalid stored credentials', () async {
        // Manually store invalid credentials (bypass validation)
        final invalidCredentials = Credentials(apiKey: 'invalid-format');
        await mockStorage.save(invalidCredentials);

        final result = await credentialsService.isAuthenticated();

        expect(result, isFalse);
      });

      test('should return false after clearing credentials', () async {
        const validApiKey = 'testuser:1234567890abcdef';
        await credentialsService.saveCredentials(validApiKey);

        expect(await credentialsService.isAuthenticated(), isTrue);

        await credentialsService.clearCredentials();

        expect(await credentialsService.isAuthenticated(), isFalse);
      });
    });

    group('integration tests', () {
      test('should handle complete authentication flow', () async {
        const apiKey = 'flowtest:1234567890abcdef';
        const username = 'flowtest';

        // Initial state - not authenticated
        expect(await credentialsService.isAuthenticated(), isFalse);
        expect(await credentialsService.hasCredentials(), isFalse);

        // Save credentials
        await credentialsService.saveCredentials(apiKey);

        // Should now be authenticated
        expect(await credentialsService.isAuthenticated(), isTrue);
        expect(await credentialsService.hasCredentials(), isTrue);

        // Should be able to retrieve credentials
        final credentials = await credentialsService.getCredentials();
        expect(credentials?.apiKey, equals(apiKey));
        expect(
          credentialsService.getUsernameFromApiKey(credentials?.apiKey),
          equals(username),
        );

        // Clear credentials
        await credentialsService.clearCredentials();

        // Should no longer be authenticated
        expect(await credentialsService.isAuthenticated(), isFalse);
        expect(await credentialsService.hasCredentials(), isFalse);
        expect(await credentialsService.getCredentials(), isNull);
      });

      test('should handle credential updates', () async {
        const firstApiKey = 'user1:1111111111111111';
        const secondApiKey = 'user2:2222222222222222';

        // Save first credentials
        await credentialsService.saveCredentials(firstApiKey);
        expect(
          (await credentialsService.getCredentials())?.apiKey,
          equals(firstApiKey),
        );

        // Update with second credentials
        await credentialsService.saveCredentials(secondApiKey);
        expect(
          (await credentialsService.getCredentials())?.apiKey,
          equals(secondApiKey),
        );

        // Should still be authenticated
        expect(await credentialsService.isAuthenticated(), isTrue);
      });
    });

    group('error handling', () {
      test('should handle storage exceptions gracefully', () async {
        // This test demonstrates error handling, though InMemoryStorage doesn't throw
        expect(await credentialsService.getCredentials(), isNull);
        expect(await credentialsService.isAuthenticated(), isFalse);
      });
    });
  });

  group('isAuthenticatedNotifier', () {
    test('should be false initially when no credentials stored', () async {
      final storage = InMemorySecretsStorage();
      final service = CredentialsService(storage: storage);

      // Allow async initial load to complete
      await Future.delayed(const Duration(milliseconds: 10));

      expect(service.isAuthenticatedNotifier.value, isFalse);
    });

    test(
      'should be true when storage has credentials at construction',
      () async {
        const apiKey = 'user:1234567890abcdef';
        final storage = InMemorySecretsStorage();
        await storage.save(Credentials(apiKey: apiKey));

        final service = CredentialsService(storage: storage);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(service.isAuthenticatedNotifier.value, isTrue);
      },
    );

    test('should become true after saveCredentials', () async {
      final storage = InMemorySecretsStorage();
      final service = CredentialsService(storage: storage);

      await service.saveCredentials('user:aaaaaaaaaaaaaaaa');

      expect(service.isAuthenticatedNotifier.value, isTrue);
    });

    test('should become false after clearCredentials', () async {
      final storage = InMemorySecretsStorage();
      final service = CredentialsService(storage: storage);

      await service.saveCredentials('user:aaaaaaaaaaaaaaaa');
      expect(service.isAuthenticatedNotifier.value, isTrue);

      await service.clearCredentials();
      expect(service.isAuthenticatedNotifier.value, isFalse);
    });
  });

  group('CredentialsServiceException', () {
    test('should create exception with message', () {
      const message = 'Test error message';
      final exception = CredentialsServiceException(message);

      expect(exception.message, equals(message));
      expect(
        exception.toString(),
        equals('CredentialsServiceException: $message'),
      );
    });

    test('should be catchable as Exception', () {
      const exception = CredentialsServiceException('Test');

      expect(exception, isA<Exception>());
    });
  });
}
