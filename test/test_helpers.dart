import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';
import 'package:pinboard_wizard/src/services/credentials_service.dart';

/// Test helpers for creating test instances and mock data
class TestHelpers {
  // Common test API keys
  static const String validApiKey = 'testuser:1234567890abcdef';
  static const String validApiKey2 = 'testuser2:abcdef1234567890';
  static const String invalidApiKey = 'invalid-format';
  static const String emptyApiKey = '';

  // Common test usernames
  static const String testUsername = 'testuser';
  static const String testUsername2 = 'testuser2';

  /// Create a clean in-memory storage for testing
  static InMemorySecretsStorage createInMemoryStorage() {
    return InMemorySecretsStorage();
  }

  /// Create a credentials service with in-memory storage for testing
  static CredentialsService createCredentialsService() {
    return CredentialsService(storage: createInMemoryStorage());
  }

  /// Create test credentials with default valid API key
  static Credentials createTestCredentials({String? apiKey}) {
    return Credentials(apiKey: apiKey ?? validApiKey);
  }

  /// Create test credentials with the second valid API key
  static Credentials createTestCredentials2() {
    return Credentials(apiKey: validApiKey2);
  }

  /// Create invalid test credentials (for testing error cases)
  static Credentials createInvalidCredentials() {
    return Credentials(apiKey: invalidApiKey);
  }

  /// Set up a credentials service with pre-stored credentials
  static Future<CredentialsService> createAuthenticatedCredentialsService({
    String? apiKey,
  }) async {
    final service = createCredentialsService();
    await service.saveCredentials(apiKey ?? validApiKey);
    return service;
  }

  /// Set up an in-memory storage with pre-stored credentials
  static Future<InMemorySecretsStorage> createStorageWithCredentials({
    String? apiKey,
  }) async {
    final storage = createInMemoryStorage();
    final credentials = createTestCredentials(apiKey: apiKey);
    await storage.save(credentials);
    return storage;
  }

  /// Verify that storage is empty
  static void expectStorageEmpty(InMemorySecretsStorage storage) {
    expect(storage.isEmpty, isTrue);
    expect(storage.credentials, isNull);
  }

  /// Verify that storage contains specific credentials
  static void expectStorageContains(
    InMemorySecretsStorage storage,
    String expectedApiKey,
  ) {
    expect(storage.isNotEmpty, isTrue);
    expect(storage.credentials?.apiKey, equals(expectedApiKey));
  }

  /// Verify that credentials service is authenticated
  static Future<void> expectServiceAuthenticated(
    CredentialsService service,
  ) async {
    expect(await service.isAuthenticated(), isTrue);
    expect(await service.hasCredentials(), isTrue);
    expect(await service.getCredentials(), isNotNull);
  }

  /// Verify that credentials service is not authenticated
  static Future<void> expectServiceNotAuthenticated(
    CredentialsService service,
  ) async {
    expect(await service.isAuthenticated(), isFalse);
    expect(await service.hasCredentials(), isFalse);
    expect(await service.getCredentials(), isNull);
  }

  /// Generate a random valid API key for testing
  static String generateRandomApiKey({String username = 'testuser'}) {
    final random = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return '$username:$random';
  }

  /// Create a list of valid test API keys
  static List<String> createValidApiKeyList() {
    return [
      'user1:1111111111111111',
      'user2:2222222222222222',
      'longusername:abcdef1234567890',
      'test_user:fedcba0987654321',
      'user-123:aaaaaaaaaaaaaaaa',
    ];
  }

  /// Create a list of invalid test API keys
  static List<String> createInvalidApiKeyList() {
    return [
      '',
      'nocolon',
      ':missingusername',
      'missingtoken:',
      'too:many:colons',
      'user with spaces:1234567890abcdef',
      'user:token with spaces',
    ];
  }

  /// Create test data for username extraction
  static Map<String, String?> createUsernameTestData() {
    return {
      'testuser:1234567890abcdef': 'testuser',
      'user123:abcdef1234567890': 'user123',
      'long_username:fedcba0987654321': 'long_username',
      'u:a': 'u',
      // Invalid cases should return null
      'nocolon': null,
      ':missingusername': null,
      'missingtoken:': null,
      '': null,
    };
  }

  /// Async delay for testing timing-related functionality
  static Future<void> delay({int milliseconds = 10}) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Clean up storage after test
  static void cleanupStorage(InMemorySecretsStorage storage) {
    storage.clearSync();
  }

  /// Create multiple credentials services for concurrent testing
  static List<CredentialsService> createMultipleCredentialsServices(int count) {
    return List.generate(count, (_) => createCredentialsService());
  }

  /// Verify API key format validation
  static void expectValidApiKey(CredentialsService service, String apiKey) {
    expect(
      service.isValidApiKey(apiKey),
      isTrue,
      reason: 'Should be valid: $apiKey',
    );
  }

  /// Verify API key format rejection
  static void expectInvalidApiKey(CredentialsService service, String apiKey) {
    expect(
      service.isValidApiKey(apiKey),
      isFalse,
      reason: 'Should be invalid: $apiKey',
    );
  }
}

/// Extension methods for easier testing
extension InMemorySecretsStorageTestExt on InMemorySecretsStorage {
  /// Save credentials synchronously for testing
  void saveSync(Credentials credentials) {
    save(credentials);
  }

  /// Read credentials synchronously for testing
  Credentials? readSync() {
    return credentials;
  }
}

extension CredentialsServiceTestExt on CredentialsService {
  /// Quick setup for testing - saves credentials and returns service
  Future<CredentialsService> withCredentials(String apiKey) async {
    await saveCredentials(apiKey);
    return this;
  }
}
