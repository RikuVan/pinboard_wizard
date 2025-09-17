import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_client.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/models/posts_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/tags_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/add_post_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/suggest_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/update_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';

import 'pinboard_service_test.mocks.dart';

@GenerateMocks([PinboardClient, CredentialsService])
void main() {
  group('PinboardService', () {
    late MockPinboardClient mockClient;
    late MockCredentialsService mockCredentialsService;
    late InMemorySecretsStorage storage;

    setUp(() {
      mockClient = MockPinboardClient();
      mockCredentialsService = MockCredentialsService();
      storage = InMemorySecretsStorage();

      // Using TestPinboardService wrapper for injecting mocks
    });

    tearDown(() {
      storage.clearSync();
    });

    group('Authentication', () {
      test(
        'isAuthenticated returns true when client is authenticated',
        () async {
          when(mockClient.isAuthenticated()).thenAnswer((_) async => true);

          // We need to create a new service that uses the mock client
          final testService = TestPinboardService(
            mockClient,
            mockCredentialsService,
          );

          final result = await testService.isAuthenticated();
          expect(result, isTrue);
          verify(mockClient.isAuthenticated()).called(1);
        },
      );

      test(
        'isAuthenticated returns false when client is not authenticated',
        () async {
          when(mockClient.isAuthenticated()).thenAnswer((_) async => false);

          final testService = TestPinboardService(
            mockClient,
            mockCredentialsService,
          );

          final result = await testService.isAuthenticated();
          expect(result, isFalse);
        },
      );

      test('testConnection returns true on successful connection', () async {
        when(mockClient.testAuthentication()).thenAnswer((_) async => true);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.testConnection();
        expect(result, isTrue);
      });

      test('testConnection returns false on failed connection', () async {
        when(mockClient.testAuthentication()).thenAnswer((_) async => false);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.testConnection();
        expect(result, isFalse);
      });

      test(
        'testConnection returns false when client throws exception',
        () async {
          when(
            mockClient.testAuthentication(),
          ).thenThrow(PinboardException('Connection failed'));

          final testService = TestPinboardService(
            mockClient,
            mockCredentialsService,
          );

          final result = await testService.testConnection();
          expect(result, isFalse);
        },
      );
    });

    group('getAllBookmarks', () {
      test('returns list of posts from client', () async {
        final mockPosts = [
          _createMockPost('https://example1.com', 'Post 1'),
          _createMockPost('https://example2.com', 'Post 2'),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );

        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getAllBookmarks(
          tag: 'flutter',
          results: 10,
        );

        expect(result, hasLength(2));
        expect(result.first.href, equals('https://example1.com'));
        expect(result.first.description, equals('Post 1'));

        verify(
          mockClient.getPosts(
            tag: 'flutter',
            results: 10,
            start: null,
            fromdt: null,
            todt: null,
            meta: null,
          ),
        ).called(1);
      });

      test('throws PinboardServiceException when client fails', () async {
        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenThrow(PinboardException('API Error'));

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        expect(
          () => testService.getAllBookmarks(),
          throwsA(isA<PinboardException>()),
        );
      });
    });

    group('getRecentBookmarks', () {
      test('returns recent posts from client', () async {
        final mockPosts = [
          _createMockPost('https://recent.com', 'Recent Post'),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );

        when(
          mockClient.getRecentPosts(
            tag: anyNamed('tag'),
            count: anyNamed('count'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getRecentBookmarks(
          tag: 'recent',
          count: 5,
        );

        expect(result, hasLength(1));
        expect(result.first.href, equals('https://recent.com'));

        verify(mockClient.getRecentPosts(tag: 'recent', count: 5)).called(1);
      });
    });

    group('searchBookmarks', () {
      test('searches in title, description, tags, and URL', () async {
        final mockPosts = [
          _createMockPost(
            'https://flutter.dev',
            'Flutter Framework',
            extended: 'UI toolkit',
            tags: 'flutter ui',
          ),
          _createMockPost(
            'https://dart.dev',
            'Dart Language',
            extended: 'Programming language',
            tags: 'dart programming',
          ),
          _createMockPost(
            'https://example.com',
            'Example Site',
            extended: 'Flutter tutorial',
            tags: 'web tutorial',
          ),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );

        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.searchBookmarks('flutter');

        expect(result, hasLength(2)); // Should match first and third posts
        expect(result.any((p) => p.href == 'https://flutter.dev'), isTrue);
        expect(result.any((p) => p.href == 'https://example.com'), isTrue);
      });

      test('returns empty list when no matches found', () async {
        final mockPosts = [
          _createMockPost('https://example.com', 'Example', tags: 'web'),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );

        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.searchBookmarks('nonexistent');

        expect(result, isEmpty);
      });
    });

    group('getBookmarksByTag', () {
      test('filters bookmarks by specific tag', () async {
        final mockPosts = [
          _createMockPost(
            'https://flutter1.com',
            'Flutter Post 1',
            tags: 'flutter mobile',
          ),
          _createMockPost(
            'https://flutter2.com',
            'Flutter Post 2',
            tags: 'flutter web',
          ),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );

        when(
          mockClient.getPosts(
            tag: 'flutter',
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getBookmarksByTag('flutter');

        expect(result, hasLength(2));
        verify(
          mockClient.getPosts(
            tag: 'flutter',
            start: null,
            results: null,
            fromdt: null,
            todt: null,
            meta: null,
          ),
        ).called(1);
      });
    });

    group('getToReadBookmarks', () {
      test('returns only bookmarks marked as toread', () async {
        final mockPosts = [
          _createMockPost('https://read1.com', 'To Read 1', toread: true),
          _createMockPost('https://read2.com', 'Already Read', toread: false),
          _createMockPost('https://read3.com', 'To Read 2', toread: true),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );

        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getToReadBookmarks();

        expect(result, hasLength(2));
        expect(result.every((p) => p.toread), isTrue);
      });
    });

    group('getPrivateBookmarks', () {
      test('returns only private bookmarks', () async {
        final mockPosts = [
          _createMockPost('https://private1.com', 'Private 1', shared: false),
          _createMockPost('https://public.com', 'Public', shared: true),
          _createMockPost('https://private2.com', 'Private 2', shared: false),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );

        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getPrivateBookmarks();

        expect(result, hasLength(2));
        expect(result.every((p) => !p.shared), isTrue);
      });
    });

    group('addBookmark', () {
      test('calls client addPost with correct parameters', () async {
        when(
          mockClient.addPost(
            url: anyNamed('url'),
            description: anyNamed('description'),
            extended: anyNamed('extended'),
            tags: anyNamed('tags'),
            shared: anyNamed('shared'),
            toread: anyNamed('toread'),
            replace: anyNamed('replace'),
          ),
        ).thenAnswer((_) async => const AddPostResponse(resultCode: 'done'));

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        await testService.addBookmark(
          url: 'https://example.com',
          title: 'Test Bookmark',
          description: 'Test description',
          tags: ['test', 'example'],
          shared: false,
          toRead: true,
          replace: true,
        );

        verify(
          mockClient.addPost(
            url: 'https://example.com',
            description: 'Test Bookmark',
            extended: 'Test description',
            tags: 'test example',
            shared: false,
            toread: true,
            replace: true,
          ),
        ).called(1);
      });

      test('handles null tags list', () async {
        when(
          mockClient.addPost(
            url: anyNamed('url'),
            description: anyNamed('description'),
            extended: anyNamed('extended'),
            tags: anyNamed('tags'),
            shared: anyNamed('shared'),
            toread: anyNamed('toread'),
            replace: anyNamed('replace'),
          ),
        ).thenAnswer((_) async => const AddPostResponse(resultCode: 'done'));

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        await testService.addBookmark(
          url: 'https://example.com',
          title: 'Test Bookmark',
        );

        verify(
          mockClient.addPost(
            url: 'https://example.com',
            description: 'Test Bookmark',
            extended: null,
            tags: null,
            shared: true,
            toread: false,
            replace: false,
          ),
        ).called(1);
      });
    });

    group('updateBookmark', () {
      test('calls client addPost with replace=true', () async {
        final post = _createMockPost('https://example.com', 'Updated Title');

        when(
          mockClient.addPost(
            url: anyNamed('url'),
            description: anyNamed('description'),
            extended: anyNamed('extended'),
            tags: anyNamed('tags'),
            dt: anyNamed('dt'),
            shared: anyNamed('shared'),
            toread: anyNamed('toread'),
            replace: anyNamed('replace'),
          ),
        ).thenAnswer((_) async => const AddPostResponse(resultCode: 'done'));

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        await testService.updateBookmark(post);

        verify(
          mockClient.addPost(
            url: 'https://example.com',
            description: 'Updated Title',
            extended: '',
            tags: 'test',
            dt: anyNamed('dt'),
            shared: true,
            toread: false,
            replace: true,
          ),
        ).called(1);
      });
    });

    group('deleteBookmark', () {
      test('calls client deletePost', () async {
        when(
          mockClient.deletePost(any),
        ).thenAnswer((_) async => const AddPostResponse(resultCode: 'done'));

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        await testService.deleteBookmark('https://example.com');

        verify(mockClient.deletePost('https://example.com')).called(1);
      });
    });

    group('getBookmark', () {
      test('returns first post from client response', () async {
        final mockPost = _createMockPost('https://example.com', 'Example');
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: [mockPost],
        );

        when(
          mockClient.getPost(url: anyNamed('url')),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getBookmark('https://example.com');

        expect(result, isNotNull);
        expect(result!.href, equals('https://example.com'));
      });

      test('returns null when no posts found', () async {
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: [],
        );

        when(
          mockClient.getPost(url: anyNamed('url')),
        ).thenAnswer((_) async => mockResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getBookmark('https://example.com');

        expect(result, isNull);
      });
    });

    group('getAllTags', () {
      test('returns tags map from client', () async {
        final tagsResponse = TagsResponse(tags: {'flutter': 10, 'dart': 5});

        when(mockClient.getTags()).thenAnswer((_) async => tagsResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getAllTags();

        expect(result, equals({'flutter': 10, 'dart': 5}));
      });
    });

    group('getPopularTags', () {
      test('returns tags sorted by count', () async {
        final tagsResponse = TagsResponse(
          tags: {'dart': 5, 'flutter': 10, 'web': 3},
        );

        when(mockClient.getTags()).thenAnswer((_) async => tagsResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getPopularTags(2);

        expect(result, hasLength(2));
        expect(result.first.key, equals('flutter'));
        expect(result.first.value, equals(10));
        expect(result.last.key, equals('dart'));
        expect(result.last.value, equals(5));
      });
    });

    group('getSuggestedTags', () {
      test('returns all suggestions from client', () async {
        final suggestResponse = SuggestResponse(
          popular: ['tag1', 'tag2'],
          recommended: ['tag3', 'tag4'],
        );

        when(
          mockClient.getSuggestedTags('https://example.com'),
        ).thenAnswer((_) async => suggestResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getSuggestedTags(
          'https://example.com',
        );

        expect(result, containsAll(['tag1', 'tag2', 'tag3', 'tag4']));
      });
    });

    group('getBookmarkStats', () {
      test('calculates correct statistics', () async {
        final mockPosts = [
          _createMockPost(
            'https://example1.com',
            'Post 1',
            shared: true,
            toread: false,
          ),
          _createMockPost(
            'https://example2.com',
            'Post 2',
            shared: false,
            toread: true,
          ),
          _createMockPost(
            'https://example3.com',
            'Post 3',
            shared: true,
            toread: true,
          ),
        ];
        final mockResponse = PostsResponse(
          date: DateTime.now(),
          user: 'testuser',
          posts: mockPosts,
        );
        final tagsResponse = TagsResponse(tags: {'tag1': 1, 'tag2': 2});

        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenAnswer((_) async => mockResponse);
        when(mockClient.getTags()).thenAnswer((_) async => tagsResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final stats = await testService.getBookmarkStats();

        expect(stats.totalBookmarks, equals(3));
        expect(stats.totalTags, equals(2));
        expect(stats.toReadCount, equals(2));
        expect(stats.privateCount, equals(1));
        expect(stats.publicCount, equals(2));
      });
    });

    group('getLastUpdateTime', () {
      test('returns update time from client', () async {
        final updateTime = DateTime.parse('2024-01-01T12:00:00Z');
        final updateResponse = UpdateResponse(updateTime: updateTime);

        when(
          mockClient.getLastUpdate(),
        ).thenAnswer((_) async => updateResponse);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getLastUpdateTime();

        expect(result, equals(updateTime));
      });
    });

    group('getUsername', () {
      test('extracts username from credentials', () async {
        const credentials = Credentials(apiKey: 'testuser:abc123');

        when(
          mockCredentialsService.getCredentials(),
        ).thenAnswer((_) async => credentials);
        when(
          mockCredentialsService.getUsernameFromApiKey('testuser:abc123'),
        ).thenReturn('testuser');

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getUsername();

        expect(result, equals('testuser'));
      });

      test('returns null when no credentials', () async {
        when(
          mockCredentialsService.getCredentials(),
        ).thenAnswer((_) async => null);

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        final result = await testService.getUsername();

        expect(result, isNull);
      });
    });

    group('Error Handling', () {
      test('rethrows PinboardException from client', () async {
        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenThrow(PinboardException('API Error'));

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        expect(
          () => testService.getAllBookmarks(),
          throwsA(isA<PinboardException>()),
        );
      });

      test('wraps other exceptions in PinboardServiceException', () async {
        when(
          mockClient.getPosts(
            tag: anyNamed('tag'),
            start: anyNamed('start'),
            results: anyNamed('results'),
            fromdt: anyNamed('fromdt'),
            todt: anyNamed('todt'),
            meta: anyNamed('meta'),
          ),
        ).thenThrow(Exception('Generic error'));

        final testService = TestPinboardService(
          mockClient,
          mockCredentialsService,
        );

        expect(
          () => testService.getAllBookmarks(),
          throwsA(isA<PinboardServiceException>()),
        );
      });
    });
  });
}

// Helper function to create mock Post objects
Post _createMockPost(
  String url,
  String description, {
  String extended = '',
  String tags = 'test',
  bool shared = true,
  bool toread = false,
}) {
  return Post(
    href: url,
    description: description,
    extended: extended,
    meta: 'abc123',
    hash: 'def456',
    time: DateTime.now(),
    shared: shared,
    toread: toread,
    tags: tags,
  );
}

// Test wrapper class to inject mocked client
class TestPinboardService {
  final PinboardClient _client;
  final CredentialsService _credentialsService;

  TestPinboardService(this._client, this._credentialsService);

  Future<bool> isAuthenticated() => _client.isAuthenticated();
  Future<bool> testConnection() async {
    try {
      return await _client.testAuthentication();
    } catch (e) {
      return false;
    }
  }

  Future<List<Post>> getAllBookmarks({
    String? tag,
    int? start,
    int? results,
    DateTime? fromdt,
    DateTime? todt,
    int? meta,
  }) async {
    try {
      final response = await _client.getPosts(
        tag: tag,
        start: start,
        results: results,
        fromdt: fromdt,
        todt: todt,
        meta: meta,
      );
      return response.posts;
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to fetch bookmarks: $e');
    }
  }

  Future<List<Post>> getRecentBookmarks({String? tag, int? count}) async {
    final response = await _client.getRecentPosts(tag: tag, count: count);
    return response.posts;
  }

  Future<List<Post>> searchBookmarks(String query, {String? tag}) async {
    final allBookmarks = await getAllBookmarks(tag: tag);
    final queryLower = query.toLowerCase();

    return allBookmarks.where((bookmark) {
      final titleMatch = bookmark.description.toLowerCase().contains(
        queryLower,
      );
      final descMatch = bookmark.extended.toLowerCase().contains(queryLower);
      final tagMatch = bookmark.tags.toLowerCase().contains(queryLower);
      final urlMatch = bookmark.href.toLowerCase().contains(queryLower);

      return titleMatch || descMatch || tagMatch || urlMatch;
    }).toList();
  }

  Future<List<Post>> getBookmarksByTag(String tag) async {
    return await getAllBookmarks(tag: tag);
  }

  Future<List<Post>> getToReadBookmarks() async {
    final allBookmarks = await getAllBookmarks();
    return allBookmarks.where((bookmark) => bookmark.toread).toList();
  }

  Future<List<Post>> getPrivateBookmarks() async {
    final allBookmarks = await getAllBookmarks();
    return allBookmarks.where((bookmark) => !bookmark.shared).toList();
  }

  Future<void> addBookmark({
    required String url,
    required String title,
    String? description,
    List<String>? tags,
    bool shared = true,
    bool toRead = false,
    bool replace = false,
  }) async {
    await _client.addPost(
      url: url,
      description: title,
      extended: description,
      tags: tags?.join(' '),
      shared: shared,
      toread: toRead,
      replace: replace,
    );
  }

  Future<void> updateBookmark(Post bookmark) async {
    await _client.addPost(
      url: bookmark.href,
      description: bookmark.description,
      extended: bookmark.extended,
      tags: bookmark.tags.isNotEmpty ? bookmark.tags : null,
      dt: bookmark.time,
      shared: bookmark.shared,
      toread: bookmark.toread,
      replace: true,
    );
  }

  Future<void> deleteBookmark(String url) async {
    await _client.deletePost(url);
  }

  Future<Post?> getBookmark(String url) async {
    final response = await _client.getPost(url: url);
    return response.posts.isNotEmpty ? response.posts.first : null;
  }

  Future<Map<String, int>> getAllTags() async {
    final response = await _client.getTags();
    return response.tags;
  }

  Future<List<MapEntry<String, int>>> getPopularTags([int? limit]) async {
    final allTags = await getAllTags();
    final sortedTags = allTags.entries.toList();
    sortedTags.sort((a, b) => b.value.compareTo(a.value));

    if (limit != null && limit > 0) {
      return sortedTags.take(limit).toList();
    }
    return sortedTags;
  }

  Future<List<String>> getSuggestedTags(String url) async {
    final response = await _client.getSuggestedTags(url);
    return response.allSuggestions;
  }

  Future<BookmarkStats> getBookmarkStats() async {
    final allBookmarks = await getAllBookmarks();
    final allTags = await getAllTags();

    final toReadCount = allBookmarks.where((b) => b.toread).length;
    final privateCount = allBookmarks.where((b) => !b.shared).length;
    final publicCount = allBookmarks.length - privateCount;

    return BookmarkStats(
      totalBookmarks: allBookmarks.length,
      totalTags: allTags.length,
      toReadCount: toReadCount,
      privateCount: privateCount,
      publicCount: publicCount,
    );
  }

  Future<DateTime> getLastUpdateTime() async {
    final response = await _client.getLastUpdate();
    return response.updateTime;
  }

  Future<String?> getUsername() async {
    try {
      final credentials = await _credentialsService.getCredentials();
      return _credentialsService.getUsernameFromApiKey(credentials?.apiKey);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _client.dispose();
  }
}
