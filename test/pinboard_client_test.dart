import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_client.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/models/posts_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/api_token_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/tags_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/add_post_response.dart';

import 'pinboard_client_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('PinboardClient', () {
    late MockClient mockHttpClient;
    late InMemorySecretsStorage storage;
    late PinboardClient client;

    const testApiKey = 'testuser:1234567890abcdef';
    const testCredentials = Credentials(apiKey: testApiKey);

    setUp(() {
      mockHttpClient = MockClient();
      storage = InMemorySecretsStorage();
      client = PinboardClient(secretStorage: storage, httpClient: mockHttpClient);
    });

    tearDown(() {
      storage.clearSync();
    });

    group('Authentication', () {
      test('throws PinboardAuthException when no credentials stored', () async {
        expect(() => client.getUserApiToken(), throwsA(isA<PinboardAuthException>()));
      });

      test('testAuthentication returns true when API call succeeds', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result': testApiKey}), 200));

        final result = await client.testAuthentication();
        expect(result, isTrue);
      });

      test('testAuthentication returns false on auth error', () async {
        await storage.save(testCredentials);

        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('Unauthorized', 401));

        final result = await client.testAuthentication();
        expect(result, isFalse);
      });

      test('testAuthentication rethrows other errors', () async {
        await storage.save(testCredentials);

        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('Server Error', 500));

        expect(() => client.testAuthentication(), throwsA(isA<PinboardException>()));
      });
    });

    group('URL Building and Parameters', () {
      test('adds required auth_token and format parameters', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result': testApiKey}), 200));

        await client.getUserApiToken();

        final capturedRequest = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedRequest.queryParameters['auth_token'], equals(testApiKey));
        expect(capturedRequest.queryParameters['format'], equals('json'));
      });

      test('builds correct URL for endpoints', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result': testApiKey}), 200));

        await client.getUserApiToken();

        final capturedRequest = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedRequest.scheme, equals('https'));
        expect(capturedRequest.host, equals('api.pinboard.in'));
        expect(capturedRequest.path, equals('/v1/user/api_token'));
      });
    });

    group('Error Handling', () {
      test('handles 401 unauthorized responses', () async {
        await storage.save(testCredentials);

        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('Unauthorized', 401));

        expect(() => client.getUserApiToken(), throwsA(isA<PinboardAuthException>()));
      });

      test('handles 429 rate limit responses', () async {
        await storage.save(testCredentials);

        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('Rate limited', 429));

        expect(
          () => client.getUserApiToken(),
          throwsA(predicate((e) => e is PinboardException && e.message.contains('Rate limit'))),
        );
      });

      test('handles other HTTP errors', () async {
        await storage.save(testCredentials);

        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('Server Error', 500));

        expect(() => client.getUserApiToken(), throwsA(isA<PinboardException>()));
      });

      test('handles invalid JSON responses', () async {
        await storage.save(testCredentials);

        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('Invalid JSON{', 200));

        expect(() => client.getUserApiToken(), throwsA(isA<PinboardException>()));
      });
    });

    group('Posts API', () {
      test('getPosts with all parameters', () async {
        await storage.save(testCredentials);

        final mockResponse = {
          'date': '2024-01-01T12:00:00Z',
          'user': 'testuser',
          'posts': [
            {
              'href': 'https://example.com',
              'description': 'Test Post',
              'extended': 'Test description',
              'meta': 'abc123',
              'hash': 'def456',
              'time': '2024-01-01T12:00:00Z',
              'shared': 'yes',
              'toread': 'no',
              'tags': 'test example',
            },
          ],
        };

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        final result = await client.getPosts(
          tag: 'test',
          start: 0,
          results: 10,
          fromdt: DateTime.parse('2024-01-01T00:00:00Z'),
          todt: DateTime.parse('2024-01-01T23:59:59Z'),
          meta: 1,
        );

        expect(result, isA<PostsResponse>());
        expect(result.posts.length, equals(1));
        expect(result.posts.first.href, equals('https://example.com'));
        expect(result.posts.first.shared, isTrue);
        expect(result.posts.first.toread, isFalse);

        final capturedRequest = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedRequest.queryParameters['tag'], equals('test'));
        expect(capturedRequest.queryParameters['start'], equals('0'));
        expect(capturedRequest.queryParameters['results'], equals('10'));
        expect(capturedRequest.queryParameters['meta'], equals('1'));
        expect(capturedRequest.queryParameters['fromdt'], isNotNull);
        expect(capturedRequest.queryParameters['todt'], isNotNull);
      });

      test('getRecentPosts with parameters', () async {
        await storage.save(testCredentials);

        final mockResponse = {'date': '2024-01-01T12:00:00Z', 'user': 'testuser', 'posts': []};

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        await client.getRecentPosts(tag: 'recent', count: 5);

        final capturedRequest = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedRequest.path, equals('/v1/posts/recent'));
        expect(capturedRequest.queryParameters['tag'], equals('recent'));
        expect(capturedRequest.queryParameters['count'], equals('5'));
      });

      test('getPost with all parameters', () async {
        await storage.save(testCredentials);

        final mockResponse = {'date': '2024-01-01T12:00:00Z', 'user': 'testuser', 'posts': []};

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        await client.getPost(
          tag: 'test',
          dt: DateTime.parse('2024-01-01T12:00:00Z'),
          url: 'https://example.com',
          meta: 'yes',
        );

        final capturedRequest = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedRequest.path, equals('/v1/posts/get'));
        expect(capturedRequest.queryParameters['tag'], equals('test'));
        expect(capturedRequest.queryParameters['dt'], equals('2024-01-01'));
        expect(capturedRequest.queryParameters['url'], equals('https://example.com'));
        expect(capturedRequest.queryParameters['meta'], equals('yes'));
      });

      test('addPost creates GET request with correct parameters', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result_code': 'done'}), 200));

        final result = await client.addPost(
          url: 'https://example.com',
          description: 'Test Post',
          extended: 'Test description',
          tags: 'test example',
          dt: DateTime.parse('2024-01-01T12:00:00Z'),
          replace: true,
          shared: false,
          toread: true,
        );

        expect(result, isA<AddPostResponse>());
        expect(result.wasSuccessful, isTrue);

        final capturedUri = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedUri.queryParameters['url'], equals('https://example.com'));
        expect(capturedUri.queryParameters['description'], equals('Test Post'));
        expect(capturedUri.queryParameters['extended'], equals('Test description'));
        expect(capturedUri.queryParameters['tags'], equals('test example'));
        expect(capturedUri.queryParameters['replace'], equals('yes'));
        expect(capturedUri.queryParameters['shared'], equals('no'));
        expect(capturedUri.queryParameters['toread'], equals('yes'));
      });

      test('deletePost creates GET request', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result_code': 'done'}), 200));

        await client.deletePost('https://example.com');

        final capturedUri = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedUri.queryParameters['url'], equals('https://example.com'));
      });
    });

    group('Tags API', () {
      test('getTags returns TagsResponse', () async {
        await storage.save(testCredentials);

        final mockResponse = {
          'tags': {'flutter': 5, 'dart': 3, 'programming': 10},
        };

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        final result = await client.getTags();

        expect(result, isA<TagsResponse>());
        expect(result.tags['flutter'], equals(5));
        expect(result.tags['dart'], equals(3));
        expect(result.tags['programming'], equals(10));
        expect(result.totalTags, equals(3));
        expect(result.totalBookmarks, equals(18));
      });

      test('deleteTag creates GET request', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result_code': 'done'}), 200));

        await client.deleteTag('oldtag');

        final capturedUri = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedUri.queryParameters['tag'], equals('oldtag'));
      });

      test('renameTag creates GET request with correct parameters', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result_code': 'done'}), 200));

        await client.renameTag(oldTag: 'oldtag', newTag: 'newtag');

        final capturedUri = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedUri.queryParameters['old'], equals('oldtag'));
        expect(capturedUri.queryParameters['new'], equals('newtag'));
      });
    });

    group('User API', () {
      test('getUserApiToken returns ApiTokenResponse', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result': testApiKey}), 200));

        final result = await client.getUserApiToken();

        expect(result, isA<ApiTokenResponse>());
        expect(result.apiToken, equals(testApiKey));
      });

      test('getUserSecret returns UserSecretResponse', () async {
        await storage.save(testCredentials);

        const secretKey = 'secret123';
        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result': secretKey}), 200));

        final result = await client.getUserSecret();
        expect(result.secret, equals(secretKey));
      });
    });

    group('Other APIs', () {
      test('getSuggestedTags returns SuggestResponse', () async {
        await storage.save(testCredentials);

        final mockResponse = {
          'popular': ['tag1', 'tag2'],
          'recommended': ['tag3', 'tag4'],
        };

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        final result = await client.getSuggestedTags('https://example.com');
        expect(result.popular, equals(['tag1', 'tag2']));
        expect(result.recommended, equals(['tag3', 'tag4']));
        expect(result.allSuggestions, containsAll(['tag1', 'tag2', 'tag3', 'tag4']));
      });

      test('getLastUpdate returns UpdateResponse', () async {
        await storage.save(testCredentials);

        final updateTime = '2024-01-01T12:00:00Z';
        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'update_time': updateTime}), 200));

        final result = await client.getLastUpdate();
        expect(result.updateTime, equals(DateTime.parse(updateTime)));
      });

      test('getPostDates with tag parameter', () async {
        await storage.save(testCredentials);

        final mockResponse = {
          'dates': {'2024-01-01': 5, '2024-01-02': 3},
        };

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        await client.getPostDates(tag: 'test');

        final capturedRequest = verify(mockHttpClient.get(captureAny)).captured.single as Uri;
        expect(capturedRequest.path, equals('/v1/posts/dates'));
        expect(capturedRequest.queryParameters['tag'], equals('test'));
      });
    });

    group('Integration', () {
      test('isAuthenticated returns true when credentials exist and auth succeeds', () async {
        await storage.save(testCredentials);

        when(
          mockHttpClient.get(any),
        ).thenAnswer((_) async => http.Response(json.encode({'result': testApiKey}), 200));

        final result = await client.isAuthenticated();
        expect(result, isTrue);
      });

      test('isAuthenticated returns false when no credentials', () async {
        final result = await client.isAuthenticated();
        expect(result, isFalse);
      });

      test('isAuthenticated returns false when auth fails', () async {
        await storage.save(testCredentials);

        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('Unauthorized', 401));

        final result = await client.isAuthenticated();
        expect(result, isFalse);
      });
    });

    group('Dispose', () {
      test('dispose closes http client', () {
        client.dispose();
        verify(mockHttpClient.close()).called(1);
      });
    });
  });

  group('PinboardException', () {
    test('creates exception with message', () {
      const exception = PinboardException('Test error');
      expect(exception.message, equals('Test error'));
      expect(exception.toString(), equals('PinboardException: Test error'));
    });

    test('creates exception with status code and response', () {
      const exception = PinboardException('Test error', statusCode: 404, response: 'Not found');
      expect(exception.statusCode, equals(404));
      expect(exception.response, equals('Not found'));
    });
  });

  group('PinboardAuthException', () {
    test('is a subclass of PinboardException', () {
      const exception = PinboardAuthException('Auth failed');
      expect(exception, isA<PinboardException>());
      expect(exception.message, equals('Auth failed'));
    });
  });
}
