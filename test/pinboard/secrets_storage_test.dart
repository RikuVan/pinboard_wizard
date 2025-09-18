import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';

void main() {
  group('InMemorySecretsStorage', () {
    late InMemorySecretsStorage storage;

    setUp(() {
      storage = InMemorySecretsStorage();
    });

    tearDown(() {
      storage.clearSync();
    });

    test('should start empty', () {
      expect(storage.isEmpty, isTrue);
      expect(storage.isNotEmpty, isFalse);
      expect(storage.credentials, isNull);
    });

    test('should read null when no credentials are stored', () async {
      final result = await storage.read();
      expect(result, isNull);
    });

    test('should save and read credentials', () async {
      final credentials = Credentials(apiKey: 'testuser:1234567890abcdef');

      await storage.save(credentials);

      expect(storage.isNotEmpty, isTrue);
      expect(storage.isEmpty, isFalse);

      final result = await storage.read();
      expect(result, equals(credentials));
      expect(result?.apiKey, equals('testuser:1234567890abcdef'));
    });

    test('should overwrite existing credentials', () async {
      final firstCredentials = Credentials(apiKey: 'user1:1111111111111111');
      final secondCredentials = Credentials(apiKey: 'user2:2222222222222222');

      await storage.save(firstCredentials);
      await storage.save(secondCredentials);

      final result = await storage.read();
      expect(result, equals(secondCredentials));
      expect(result?.apiKey, equals('user2:2222222222222222'));
    });

    test('should clear credentials', () async {
      final credentials = Credentials(apiKey: 'testuser:1234567890abcdef');

      await storage.save(credentials);
      expect(storage.isNotEmpty, isTrue);

      await storage.clear();
      expect(storage.isEmpty, isTrue);

      final result = await storage.read();
      expect(result, isNull);
    });

    test('hasCredentials should return correct status', () async {
      expect(await storage.hasCredentials(), isFalse);

      final credentials = Credentials(apiKey: 'testuser:1234567890abcdef');
      await storage.save(credentials);

      expect(await storage.hasCredentials(), isTrue);

      await storage.clear();
      expect(await storage.hasCredentials(), isFalse);
    });

    test('clearSync should clear credentials immediately', () async {
      final credentials = Credentials(apiKey: 'testuser:1234567890abcdef');
      await storage.save(credentials);

      expect(storage.isNotEmpty, isTrue);

      storage.clearSync();
      expect(storage.isEmpty, isTrue);
      expect(storage.credentials, isNull);
    });

    test('should handle multiple save/read operations', () async {
      final credentials1 = Credentials(apiKey: 'user1:1111111111111111');
      final credentials2 = Credentials(apiKey: 'user2:2222222222222222');
      final credentials3 = Credentials(apiKey: 'user3:3333333333333333');

      await storage.save(credentials1);
      expect((await storage.read())?.apiKey, equals('user1:1111111111111111'));

      await storage.save(credentials2);
      expect((await storage.read())?.apiKey, equals('user2:2222222222222222'));

      await storage.save(credentials3);
      expect((await storage.read())?.apiKey, equals('user3:3333333333333333'));

      await storage.clear();
      expect(await storage.read(), isNull);
    });

    test('should maintain state during async operations', () async {
      // Start multiple save operations
      final futures = <Future<void>>[];
      for (int i = 0; i < 10; i++) {
        final testCredentials = Credentials(apiKey: 'user$i:${i.toString().padLeft(16, '0')}');
        futures.add(storage.save(testCredentials));
      }

      await Future.wait(futures);

      // Should have the last saved credentials (not deterministic which one wins)
      final result = await storage.read();
      expect(result, isNotNull);
      expect(result!.apiKey, startsWith('user'));
    });
  });

  group('SecretStorage Interface Compliance', () {
    late SecretStorage storage;

    setUp(() {
      storage = InMemorySecretsStorage();
    });

    test('should implement SecretStorage interface', () {
      expect(storage, isA<SecretStorage>());
    });

    test('should have required methods', () async {
      // Test that all interface methods are callable
      expect(() => storage.read(), returnsNormally);
      expect(() => storage.clear(), returnsNormally);

      final credentials = Credentials(apiKey: 'test:1234567890abcdef');
      expect(() => storage.save(credentials), returnsNormally);
    });

    test('should handle credentials lifecycle', () async {
      final credentials = Credentials(apiKey: 'lifecycle:1234567890abcdef');

      // Initial state
      expect(await storage.read(), isNull);

      // Save
      await storage.save(credentials);
      final saved = await storage.read();
      expect(saved, isNotNull);
      expect(saved!.apiKey, equals('lifecycle:1234567890abcdef'));

      // Clear
      await storage.clear();
      expect(await storage.read(), isNull);
    });
  });

  group('Credentials Model Integration', () {
    late InMemorySecretsStorage storage;

    setUp(() {
      storage = InMemorySecretsStorage();
    });

    test('should work with different credential formats', () async {
      final testCases = [
        'user:1234567890abcdef',
        'longusername:fedcba0987654321',
        'user123:abcdef1234567890',
        'test_user:1111111111111111',
      ];

      for (final apiKey in testCases) {
        final credentials = Credentials(apiKey: apiKey);
        await storage.save(credentials);

        final result = await storage.read();
        expect(result?.apiKey, equals(apiKey));

        await storage.clear();
      }
    });

    test('should preserve credentials equality', () async {
      final original = Credentials(apiKey: 'testuser:1234567890abcdef');

      await storage.save(original);
      final retrieved = await storage.read();

      expect(retrieved, equals(original));
      expect(retrieved.hashCode, equals(original.hashCode));
    });
  });
}
