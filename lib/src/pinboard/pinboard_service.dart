import 'package:pinboard_wizard/src/pinboard/pinboard_client.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';

class PinboardService {
  final PinboardClient _client;
  final CredentialsService _credentialsService;

  PinboardService({required SecretStorage secretStorage, CredentialsService? credentialsService})
    : _client = PinboardClient(secretStorage: secretStorage),
      _credentialsService = credentialsService ?? CredentialsService(storage: secretStorage);

  Future<bool> isAuthenticated() async {
    return await _client.isAuthenticated();
  }

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
    try {
      final response = await _client.getRecentPosts(tag: tag, count: count);
      return response.posts;
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to fetch recent bookmarks: $e');
    }
  }

  Future<List<Post>> searchBookmarks(String query, {String? tag}) async {
    final allBookmarks = await getAllBookmarks(tag: tag);
    final queryLower = query.toLowerCase();

    return allBookmarks.where((bookmark) {
      final titleMatch = bookmark.description.toLowerCase().contains(queryLower);
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
    try {
      await _client.addPost(
        url: url,
        description: title,
        extended: description,
        tags: tags?.join(' '),
        shared: shared,
        toread: toRead,
        replace: replace,
      );
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to add bookmark: $e');
    }
  }

  Future<void> updateBookmark(Post bookmark) async {
    try {
      await _client.addPost(
        url: bookmark.href,
        description: bookmark.description,
        extended: bookmark.extended,
        tags: bookmark.tags.isNotEmpty ? bookmark.tags : null,
        dt: bookmark.time,
        shared: bookmark.shared,
        toread: bookmark.toread,
        replace: true, // Replace existing bookmark
      );
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to update bookmark: $e');
    }
  }

  Future<void> deleteBookmark(String url) async {
    try {
      await _client.deletePost(url);
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to delete bookmark: $e');
    }
  }

  Future<Post?> getBookmark(String url) async {
    try {
      final response = await _client.getPost(url: url);
      return response.posts.isNotEmpty ? response.posts.first : null;
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to fetch bookmark: $e');
    }
  }

  Future<bool> isBookmarked(String url) async {
    final bookmark = await getBookmark(url);
    return bookmark != null;
  }

  Future<Map<String, int>> getAllTags() async {
    try {
      final response = await _client.getTags();
      return response.tags;
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to fetch tags: $e');
    }
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

  Future<void> renameTag({required String oldTag, required String newTag}) async {
    try {
      await _client.renameTag(oldTag: oldTag, newTag: newTag);
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to rename tag: $e');
    }
  }

  Future<void> deleteTag(String tag) async {
    try {
      await _client.deleteTag(tag);
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to delete tag: $e');
    }
  }

  Future<List<String>> getSuggestedTags(String url) async {
    try {
      final response = await _client.getSuggestedTags(url);
      return response.allSuggestions;
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to get suggested tags: $e');
    }
  }

  Future<BookmarkStats> getBookmarkStats() async {
    try {
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
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to calculate statistics: $e');
    }
  }

  Future<DateTime> getLastUpdateTime() async {
    try {
      final response = await _client.getLastUpdate();
      return response.updateTime;
    } on PinboardException {
      rethrow;
    } catch (e) {
      throw PinboardServiceException('Failed to get last update time: $e');
    }
  }

  Future<String?> getUsername() async {
    try {
      final credentials = await _credentialsService.getCredentials();
      return _credentialsService.getUsernameFromApiKey(credentials?.apiKey);
    } catch (e) {
      return null;
    }
  }

  /// Debug method to test authentication and diagnose issues
  Future<void> debugAuthentication() async {
    print('=== PINBOARD SERVICE DEBUG ===');

    // First check credentials
    await _credentialsService.debugCredentials();

    print('\n--- Testing API Connection ---');
    try {
      final isAuth = await isAuthenticated();
      print('isAuthenticated(): ${isAuth ? "✅ True" : "❌ False"}');

      if (isAuth) {
        print('--- Testing API Token Endpoint ---');
        final tokenResponse = await _client.getUserApiToken();
        print('✅ API Token test successful: ${tokenResponse.result}');

        print('--- Testing Simple GET Request ---');
        final updateTime = await getLastUpdateTime();
        print('✅ Last update time: $updateTime');
      } else {
        print('❌ Authentication failed - cannot proceed with API tests');
      }
    } catch (e) {
      print('❌ Authentication test failed: $e');
      if (e is PinboardAuthException) {
        print('   This is an authentication error - check your API token');
      }
    }

    print('=== END PINBOARD SERVICE DEBUG ===');
  }

  void dispose() {
    _client.dispose();
  }
}

class BookmarkStats {
  final int totalBookmarks;
  final int totalTags;
  final int toReadCount;
  final int privateCount;
  final int publicCount;

  const BookmarkStats({
    required this.totalBookmarks,
    required this.totalTags,
    required this.toReadCount,
    required this.privateCount,
    required this.publicCount,
  });

  @override
  String toString() {
    return 'BookmarkStats(total: $totalBookmarks, tags: $totalTags, toRead: $toReadCount, private: $privateCount, public: $publicCount)';
  }
}

class PinboardServiceException implements Exception {
  final String message;

  const PinboardServiceException(this.message);

  @override
  String toString() => 'PinboardServiceException: $message';
}
