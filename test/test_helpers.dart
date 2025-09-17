import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';

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

/// Test data helpers for creating Post instances and related test data
class PostTestData {
  /// Create a basic test post
  static Post createPost({
    String? href,
    String? description,
    String? extended,
    String? meta,
    String? hash,
    DateTime? time,
    bool? shared,
    bool? toread,
    String? tags,
  }) {
    return Post(
      href: href ?? 'https://example.com',
      description: description ?? 'Test Bookmark',
      extended: extended ?? 'Test description',
      meta: meta ?? 'meta',
      hash: hash ?? 'abcdef123456',
      time: time ?? DateTime(2023, 1, 1),
      shared: shared ?? true,
      toread: toread ?? false,
      tags: tags ?? 'test development',
    );
  }

  /// Create a list of test posts with varying properties
  static List<Post> createPostList({int count = 3}) {
    return List.generate(count, (index) {
      return Post(
        href: 'https://example$index.com',
        description: 'Test Bookmark $index',
        extended: 'Extended description for bookmark $index',
        meta: 'meta$index',
        hash: 'hash$index${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime(2023, 1, index + 1),
        shared: index % 2 == 0,
        toread: index % 3 == 0,
        tags: _createTagsForIndex(index),
      );
    });
  }

  /// Create posts with specific tags for testing tag functionality
  static List<Post> createPostsWithTags() {
    return [
      createPost(
        href: 'https://flutter.dev',
        description: 'Flutter Documentation',
        tags: 'flutter mobile development dart',
      ),
      createPost(
        href: 'https://dart.dev',
        description: 'Dart Language',
        tags: 'dart programming language',
      ),
      createPost(
        href: 'https://github.com',
        description: 'GitHub',
        tags: 'github git version-control',
      ),
      createPost(
        href: 'https://stackoverflow.com',
        description: 'Stack Overflow',
        tags: 'programming help community',
      ),
      createPost(
        href: 'https://docs.rs',
        description: 'Rust Documentation',
        tags: 'rust systems-programming',
      ),
    ];
  }

  /// Create posts for testing search functionality
  static List<Post> createSearchTestPosts() {
    return [
      createPost(
        href: 'https://flutter.dev',
        description: 'Flutter Framework Documentation',
        extended: 'Complete guide to Flutter mobile development',
        tags: 'flutter mobile ui',
      ),
      createPost(
        href: 'https://reactjs.org',
        description: 'React JavaScript Library',
        extended: 'A JavaScript library for building user interfaces',
        tags: 'react javascript frontend',
      ),
      createPost(
        href: 'https://vuejs.org',
        description: 'Vue.js Progressive Framework',
        extended: 'The progressive JavaScript framework',
        tags: 'vue javascript spa',
      ),
      createPost(
        href: 'https://angular.io',
        description: 'Angular Platform',
        extended: 'Platform for building mobile and desktop applications',
        tags: 'angular typescript framework',
      ),
    ];
  }

  /// Create posts with read status for testing
  static List<Post> createToReadPosts() {
    return [
      createPost(
        description: 'Article to Read 1',
        toread: true,
        tags: 'article reading',
      ),
      createPost(
        description: 'Article to Read 2',
        toread: true,
        tags: 'tutorial learning',
      ),
      createPost(description: 'Already Read', toread: false, tags: 'completed'),
    ];
  }

  /// Create posts with sharing status for testing
  static List<Post> createPrivatePosts() {
    return [
      createPost(
        description: 'Private Bookmark 1',
        shared: false,
        tags: 'private personal',
      ),
      createPost(
        description: 'Public Bookmark',
        shared: true,
        tags: 'public shared',
      ),
      createPost(
        description: 'Private Bookmark 2',
        shared: false,
        tags: 'secret internal',
      ),
    ];
  }

  /// Create a large list for pagination testing
  static List<Post> createLargePostList({int count = 100}) {
    return List.generate(count, (index) {
      return Post(
        href: 'https://example$index.com',
        description: 'Bookmark $index',
        extended: 'Description for bookmark number $index',
        meta: 'meta$index',
        hash: 'hash${index.toString().padLeft(6, '0')}',
        time: DateTime(2023, 1, 1).add(Duration(days: index)),
        shared: index % 2 == 0,
        toread: index % 5 == 0,
        tags: 'tag${index % 10} category${index % 3}',
      );
    });
  }

  /// Create posts with duplicate tags for testing tag deduplication
  static List<Post> createPostsWithDuplicateTags() {
    return [
      createPost(tags: 'flutter dart mobile'),
      createPost(tags: 'dart programming language'),
      createPost(tags: 'flutter ui development'),
      createPost(tags: 'mobile flutter ios android'),
      createPost(tags: 'programming dart algorithms'),
    ];
  }

  /// Create posts with empty or whitespace tags
  static List<Post> createPostsWithEmptyTags() {
    return [
      createPost(tags: ''),
      createPost(tags: '   '),
      createPost(tags: 'tag1  tag2   tag3'),
      createPost(tags: ' flutter  dart  '),
    ];
  }

  /// Helper method to create tags for a given index
  static String _createTagsForIndex(int index) {
    final baseTags = [
      'development programming',
      'tutorial learning',
      'documentation reference',
      'tools utilities',
      'framework library',
    ];
    return baseTags[index % baseTags.length];
  }

  /// Create posts for testing URL domain extraction
  static List<Post> createPostsWithVariousUrls() {
    return [
      createPost(
        href: 'https://github.com/user/repo',
        description: 'GitHub Repo',
      ),
      createPost(
        href: 'https://stackoverflow.com/questions/123',
        description: 'SO Question',
      ),
      createPost(
        href: 'https://medium.com/@author/article',
        description: 'Medium Article',
      ),
      createPost(href: 'https://dev.to/user/post', description: 'Dev.to Post'),
      createPost(
        href: 'https://blog.example.com/post',
        description: 'Blog Post',
      ),
      createPost(href: 'invalid-url', description: 'Invalid URL'),
    ];
  }

  /// Create posts with specific dates for date-based testing
  static List<Post> createPostsWithDates() {
    return [
      createPost(time: DateTime(2023, 1, 1), description: 'New Year Post'),
      createPost(time: DateTime(2023, 6, 15), description: 'Mid Year Post'),
      createPost(time: DateTime(2023, 12, 31), description: 'End Year Post'),
      createPost(time: DateTime(2024, 1, 1), description: 'Next Year Post'),
    ];
  }

  /// Expected results for search tests
  static const Map<String, List<String>> searchExpectedResults = {
    'flutter': ['Flutter Framework Documentation'],
    'react': ['React JavaScript Library'],
    'javascript': ['React JavaScript Library', 'Vue.js Progressive Framework'],
    'framework': ['Vue.js Progressive Framework', 'Angular Platform'],
    'mobile': ['Flutter Framework Documentation', 'Angular Platform'],
    'nonexistent': [],
  };

  /// Expected tag lists for tag testing
  static const List<String> expectedUniqueTags = [
    'flutter',
    'mobile',
    'ui',
    'react',
    'javascript',
    'frontend',
    'vue',
    'spa',
    'angular',
    'typescript',
    'framework',
  ];
}

/// Exception test data for testing error scenarios
class ExceptionTestData {
  /// Create a generic exception
  static Exception createGenericException([String message = 'Test exception']) {
    return Exception(message);
  }

  /// Create a network-related exception
  static Exception createNetworkException() {
    return Exception('Network error: Failed to connect to server');
  }

  /// Create an authentication exception
  static Exception createAuthException() {
    return Exception('Authentication failed: Invalid API token');
  }

  /// Create a timeout exception
  static Exception createTimeoutException() {
    return Exception('Request timeout: Operation took too long');
  }

  /// Create a server error exception
  static Exception createServerException() {
    return Exception('Server error: Internal server error (500)');
  }

  /// Create a not found exception
  static Exception createNotFoundException() {
    return Exception('Not found: Resource does not exist (404)');
  }
}
