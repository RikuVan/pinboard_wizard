import 'package:flutter/material.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_client.dart';
import 'package:pinboard_wizard/src/pinboard/flutter_secure_secrets_storage.dart';
import 'package:pinboard_wizard/src/services/pinboard_service.dart';
import 'package:pinboard_wizard/src/services/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

/// Example showing how to use the Pinboard client and service
class PinboardExample {
  late final PinboardService _pinboardService;
  late final CredentialsService _credentialsService;

  PinboardExample() {
    final storage = FlutterSecureSecretsStorage();
    _credentialsService = CredentialsService(storage: storage);
    _pinboardService = PinboardService(
      secretStorage: storage,
      credentialsService: _credentialsService,
    );
  }

  /// Example: Setup and authentication flow
  Future<void> setupAndAuthenticate(String apiKey) async {
    try {
      // Save credentials to keychain
      await _credentialsService.saveCredentials(apiKey);

      // Test the connection
      final isConnected = await _pinboardService.testConnection();
      if (isConnected) {
        final username = await _pinboardService.getUsername();
        debugPrint('Successfully authenticated as: $username');
      } else {
        debugPrint('Authentication failed');
      }
    } catch (e) {
      debugPrint('Setup failed: $e');
    }
  }

  /// Example: Get all bookmarks
  Future<void> fetchAllBookmarks() async {
    try {
      final bookmarks = await _pinboardService.getAllBookmarks();
      debugPrint('Found ${bookmarks.length} bookmarks');

      for (final bookmark in bookmarks.take(5)) {
        debugPrint('- ${bookmark.description}: ${bookmark.href}');
      }
    } catch (e) {
      debugPrint('Failed to fetch bookmarks: $e');
    }
  }

  /// Example: Get recent bookmarks
  Future<void> fetchRecentBookmarks() async {
    try {
      final recent = await _pinboardService.getRecentBookmarks(count: 10);
      debugPrint('Recent bookmarks:');

      for (final bookmark in recent) {
        debugPrint(
          '- ${bookmark.description} [${bookmark.tagList.join(', ')}]',
        );
      }
    } catch (e) {
      debugPrint('Failed to fetch recent bookmarks: $e');
    }
  }

  /// Example: Search bookmarks
  Future<void> searchBookmarks(String query) async {
    try {
      final results = await _pinboardService.searchBookmarks(query);
      debugPrint('Found ${results.length} bookmarks matching "$query"');

      for (final bookmark in results) {
        debugPrint('- ${bookmark.description}: ${bookmark.href}');
      }
    } catch (e) {
      debugPrint('Search failed: $e');
    }
  }

  /// Example: Add a new bookmark
  Future<void> addNewBookmark() async {
    try {
      await _pinboardService.addBookmark(
        url: 'https://example.com',
        title: 'Example Website',
        description: 'This is an example bookmark for testing',
        tags: ['example', 'test', 'demo'],
        shared: true,
        toRead: false,
        replace: false,
      );
      debugPrint('Bookmark added successfully');
    } catch (e) {
      debugPrint('Failed to add bookmark: $e');
    }
  }

  /// Example: Get bookmarks by tag
  Future<void> getBookmarksByTag(String tag) async {
    try {
      final bookmarks = await _pinboardService.getBookmarksByTag(tag);
      debugPrint('Found ${bookmarks.length} bookmarks with tag "$tag"');

      for (final bookmark in bookmarks) {
        debugPrint('- ${bookmark.description}');
      }
    } catch (e) {
      debugPrint('Failed to get bookmarks by tag: $e');
    }
  }

  /// Example: Get "to read" bookmarks
  Future<void> getToReadBookmarks() async {
    try {
      final toRead = await _pinboardService.getToReadBookmarks();
      debugPrint('You have ${toRead.length} bookmarks to read:');

      for (final bookmark in toRead) {
        debugPrint('- ${bookmark.description}: ${bookmark.href}');
      }
    } catch (e) {
      debugPrint('Failed to get to-read bookmarks: $e');
    }
  }

  /// Example: Get all tags with counts
  Future<void> getAllTags() async {
    try {
      final tags = await _pinboardService.getAllTags();
      debugPrint('You have ${tags.length} tags:');

      // Sort by count and show top 10
      final sortedTags = tags.entries.toList();
      sortedTags.sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedTags.take(10)) {
        debugPrint('- ${entry.key} (${entry.value} bookmarks)');
      }
    } catch (e) {
      debugPrint('Failed to get tags: $e');
    }
  }

  /// Example: Get popular tags
  Future<void> getPopularTags() async {
    try {
      final popularTags = await _pinboardService.getPopularTags(10);
      debugPrint('Top 10 most used tags:');

      for (int i = 0; i < popularTags.length; i++) {
        final tag = popularTags[i];
        debugPrint('${i + 1}. ${tag.key} (${tag.value} uses)');
      }
    } catch (e) {
      debugPrint('Failed to get popular tags: $e');
    }
  }

  /// Example: Get suggested tags for a URL
  Future<void> getSuggestedTags(String url) async {
    try {
      final suggestions = await _pinboardService.getSuggestedTags(url);
      debugPrint('Suggested tags for $url:');
      debugPrint(suggestions.join(', '));
    } catch (e) {
      debugPrint('Failed to get suggested tags: $e');
    }
  }

  /// Example: Update a bookmark
  Future<void> updateBookmark(String url) async {
    try {
      final bookmark = await _pinboardService.getBookmark(url);
      if (bookmark != null) {
        final updated = bookmark.copyWith(
          description: '${bookmark.description} (Updated)',
          tags: '${bookmark.tags} updated',
        );

        await _pinboardService.updateBookmark(updated);
        debugPrint('Bookmark updated successfully');
      } else {
        debugPrint('Bookmark not found');
      }
    } catch (e) {
      debugPrint('Failed to update bookmark: $e');
    }
  }

  /// Example: Delete a bookmark
  Future<void> deleteBookmark(String url) async {
    try {
      await _pinboardService.deleteBookmark(url);
      debugPrint('Bookmark deleted successfully');
    } catch (e) {
      debugPrint('Failed to delete bookmark: $e');
    }
  }

  /// Example: Check if URL is bookmarked
  Future<void> checkIfBookmarked(String url) async {
    try {
      final isBookmarked = await _pinboardService.isBookmarked(url);
      debugPrint('URL $url is ${isBookmarked ? 'already' : 'not'} bookmarked');
    } catch (e) {
      debugPrint('Failed to check bookmark status: $e');
    }
  }

  /// Example: Get bookmark statistics
  Future<void> getBookmarkStatistics() async {
    try {
      final stats = await _pinboardService.getBookmarkStats();
      debugPrint('Bookmark Statistics:');
      debugPrint('- Total bookmarks: ${stats.totalBookmarks}');
      debugPrint('- Total tags: ${stats.totalTags}');
      debugPrint('- To read: ${stats.toReadCount}');
      debugPrint('- Private: ${stats.privateCount}');
      debugPrint('- Public: ${stats.publicCount}');
    } catch (e) {
      debugPrint('Failed to get statistics: $e');
    }
  }

  /// Example: Get last update time
  Future<void> getLastUpdateTime() async {
    try {
      final lastUpdate = await _pinboardService.getLastUpdateTime();
      if (lastUpdate != null) {
        debugPrint('Last update: $lastUpdate');
      } else {
        debugPrint('No update time available');
      }
    } catch (e) {
      debugPrint('Failed to get last update time: $e');
    }
  }

  /// Example: Complete workflow
  Future<void> completeWorkflow() async {
    try {
      debugPrint('=== Pinboard Workflow Example ===');

      // Check authentication
      final isAuth = await _pinboardService.isAuthenticated();
      if (!isAuth) {
        debugPrint('Not authenticated. Please set up credentials first.');
        return;
      }

      final username = await _pinboardService.getUsername();
      debugPrint('Logged in as: $username');

      // Get statistics
      await getBookmarkStatistics();

      // Get recent bookmarks
      debugPrint('\n--- Recent Bookmarks ---');
      await fetchRecentBookmarks();

      // Get popular tags
      debugPrint('\n--- Popular Tags ---');
      await getPopularTags();

      // Get to-read bookmarks
      debugPrint('\n--- To Read Bookmarks ---');
      await getToReadBookmarks();

      debugPrint('\n=== Workflow Complete ===');
    } catch (e) {
      debugPrint('Workflow failed: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _pinboardService.dispose();
  }
}

/// Example Widget showing Pinboard integration
class PinboardWidget extends StatefulWidget {
  const PinboardWidget({super.key});

  @override
  State<PinboardWidget> createState() => _PinboardWidgetState();
}

class _PinboardWidgetState extends State<PinboardWidget> {
  final PinboardExample _example = PinboardExample();
  List<Post> _bookmarks = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _example.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = FlutterSecureSecretsStorage();
      final service = PinboardService(secretStorage: storage);

      final bookmarks = await service.getRecentBookmarks(count: 20);

      setState(() {
        _bookmarks = bookmarks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinboard Bookmarks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookmarks,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookmarks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, size: 64),
            const SizedBox(height: 16),
            const Text('No bookmarks found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookmarks,
              child: const Text('Load Bookmarks'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        return PostTile(post: bookmark);
      },
    );
  }
}

/// Widget for displaying a single bookmark
class PostTile extends StatelessWidget {
  final Post post;

  const PostTile({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          post.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.href,
              style: TextStyle(color: Colors.blue[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.extended.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                post.extended,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (post.tagList.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: post.tagList.map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 10)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (post.toread) const Icon(Icons.schedule, size: 16),
            if (!post.shared) const Icon(Icons.lock, size: 16),
          ],
        ),
        onTap: () {
          // Handle bookmark tap (e.g., open URL)
        },
      ),
    );
  }
}
