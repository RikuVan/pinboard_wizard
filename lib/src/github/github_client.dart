import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pinboard_wizard/src/github/models/github_file.dart';
import 'package:pinboard_wizard/src/github/models/rate_limit_info.dart';

/// Exception thrown when GitHub API operations fail
class GitHubException implements Exception {
  final String message;
  final int? statusCode;
  final String? response;

  const GitHubException(this.message, {this.statusCode, this.response});

  @override
  String toString() => 'GitHubException: $message';
}

/// Exception thrown when GitHub authentication fails
class GitHubAuthException extends GitHubException {
  const GitHubAuthException(super.message, {super.statusCode, super.response});
}

/// Exception thrown when a GitHub API rate limit is exceeded
class GitHubRateLimitException extends GitHubException {
  final RateLimitInfo? rateLimitInfo;

  const GitHubRateLimitException(
    super.message, {
    super.statusCode,
    super.response,
    this.rateLimitInfo,
  });
}

/// Client for interacting with the GitHub REST API.
///
/// Provides methods for managing files in a GitHub repository with:
/// - Efficient batch operations using the Git Trees API
/// - Retry logic with exponential backoff for transient errors
/// - Rate limit tracking and handling
/// - ETag support for conditional requests
///
/// Example:
/// ```dart
/// final client = GitHubClient(
///   token: 'ghp_xxxx',
///   owner: 'username',
///   repo: 'my-notes',
///   branch: 'main',
///   notesPath: 'notes/',
/// );
///
/// // List all markdown files in the notes path
/// final files = await client.listNotesFiles();
///
/// // Download a file
/// final content = await client.downloadFile('notes/example.md');
///
/// // Create a new file
/// await client.createFile(
///   path: 'notes/new-note.md',
///   content: '# My Note\n\nContent here',
///   message: 'Create new note',
/// );
/// ```
class GitHubClient {
  static const String _baseUrl = 'https://api.github.com';
  static const int _defaultMaxRetries = 5;
  static const Duration _defaultInitialDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);

  final String _token;
  final String _owner;
  final String _repo;
  final String _branch;
  final String _notesPath;
  final http.Client _httpClient;

  /// Cache of the last known tree SHA for efficient sync detection
  String? _lastTreeSha;

  /// Cache of ETags for conditional requests
  final Map<String, String> _etagCache = {};

  /// Current rate limit information
  RateLimitInfo? _rateLimitInfo;

  /// Creates a new GitHubClient instance.
  ///
  /// [token] - GitHub Personal Access Token (PAT) with repo access
  /// [owner] - Repository owner (username or organization)
  /// [repo] - Repository name
  /// [branch] - Git branch to use (defaults to 'main')
  /// [notesPath] - Path prefix for notes files (defaults to 'notes/')
  /// [httpClient] - Optional HTTP client for testing
  GitHubClient({
    required String token,
    required String owner,
    required String repo,
    String branch = 'main',
    String notesPath = 'notes/',
    http.Client? httpClient,
  }) : _token = token,
       _owner = owner,
       _repo = repo,
       _branch = branch,
       _notesPath = notesPath.endsWith('/') ? notesPath : '$notesPath/',
       _httpClient = httpClient ?? http.Client();

  /// Gets the current rate limit information
  ///
  /// Returns null if no API calls have been made yet.
  RateLimitInfo? get rateLimitInfo => _rateLimitInfo;

  /// Efficiently lists all markdown files in the notes path using the Git Trees API.
  ///
  /// This uses a single API call to fetch the entire tree recursively,
  /// which is much more efficient than listing files individually.
  ///
  /// Returns an empty list if the tree hasn't changed since the last call
  /// (based on cached tree SHA comparison).
  ///
  /// Throws [GitHubException] if the API call fails.
  /// Throws [GitHubAuthException] if authentication fails.
  /// Throws [GitHubRateLimitException] if rate limit is exceeded.
  Future<List<GitHubFile>> listNotesFiles() async {
    // Step 1: Get latest commit SHA
    final commit = await _getLatestCommit();
    final treeSha = commit['tree']['sha'] as String;

    // Step 2: Check if tree changed (cached comparison)
    if (_lastTreeSha == treeSha) {
      // No changes since last sync, return empty
      return [];
    }

    // Step 3: Fetch entire tree recursively (one API call)
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/git/trees/$treeSha?recursive=1',
    );

    final response = await _get(url);
    final tree = json.decode(response.body) as Map<String, dynamic>;

    // Step 4: Filter for markdown files in notes path
    final files = <GitHubFile>[];
    final treeList = tree['tree'] as List<dynamic>;

    for (final entry in treeList) {
      final entryMap = entry as Map<String, dynamic>;
      final path = entryMap['path'] as String;

      if (path.startsWith(_notesPath) &&
          (path.endsWith('.md') || path.endsWith('.markdown'))) {
        files.add(
          GitHubFile(
            path: path,
            sha: entryMap['sha'] as String,
            size: entryMap['size'] as int,
            type: entryMap['type'] as String,
          ),
        );
      }
    }

    // Cache tree SHA for next sync
    _lastTreeSha = treeSha;

    return files;
  }

  /// Gets the latest commit on the configured branch.
  ///
  /// Returns a Map containing commit metadata including tree SHA.
  Future<Map<String, dynamic>> _getLatestCommit() async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/commits/$_branch');

    final response = await _get(url);
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Gets metadata for a single file.
  ///
  /// Returns a [GitHubFile] with metadata but without content.
  /// Use [downloadFile] to get the file content.
  ///
  /// Throws [GitHubException] if the file doesn't exist or API call fails.
  Future<GitHubFile> getFileMetadata(String path) async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/contents/$path?ref=$_branch',
    );

    final response = await _get(url);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return GitHubFile.fromJson(data);
  }

  /// Downloads a file's content.
  ///
  /// Returns the file content as a UTF-8 string.
  /// Returns null if the file hasn't changed (based on ETag).
  ///
  /// Throws [GitHubException] if the file doesn't exist or download fails.
  Future<String?> downloadFile(String path) async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/contents/$path?ref=$_branch',
    );

    // Add cached ETag if available
    final headers = _buildHeaders();
    if (_etagCache.containsKey(path)) {
      headers['If-None-Match'] = _etagCache[path]!;
    }

    final response = await _getWithHeaders(url, headers);

    // 304 Not Modified - content hasn't changed
    if (response.statusCode == 304) {
      return null;
    }

    // Cache new ETag
    final etag = response.headers['etag'];
    if (etag != null) {
      _etagCache[path] = etag;
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final file = GitHubFile.fromJson(data);
    return file.decodedContent;
  }

  /// Creates a new file in the repository.
  ///
  /// [path] - File path relative to repository root
  /// [content] - File content as a UTF-8 string
  /// [message] - Commit message (defaults to "Create {filename}")
  ///
  /// Returns the SHA of the new commit.
  ///
  /// Throws [GitHubException] if the file already exists or creation fails.
  Future<String> createFile({
    required String path,
    required String content,
    String? message,
  }) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');

    final filename = path.split('/').last;
    final commitMessage = message ?? 'Create $filename';

    final body = json.encode({
      'message': commitMessage,
      'content': base64.encode(utf8.encode(content)),
      'branch': _branch,
    });

    final response = await _put(url, body);
    final result = json.decode(response.body) as Map<String, dynamic>;
    final commit = result['commit'] as Map<String, dynamic>;

    // Clear tree cache since we modified the tree
    _lastTreeSha = null;

    return commit['sha'] as String;
  }

  /// Updates an existing file in the repository.
  ///
  /// [path] - File path relative to repository root
  /// [content] - New file content as a UTF-8 string
  /// [currentSha] - Current SHA of the file (for optimistic locking)
  /// [message] - Commit message (defaults to "Update {filename}")
  ///
  /// Returns the SHA of the new commit.
  ///
  /// Throws [GitHubException] if the SHA doesn't match (conflict) or update fails.
  Future<String> updateFile({
    required String path,
    required String content,
    required String currentSha,
    String? message,
  }) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');

    final filename = path.split('/').last;
    final commitMessage = message ?? 'Update $filename';

    final body = json.encode({
      'message': commitMessage,
      'content': base64.encode(utf8.encode(content)),
      'sha': currentSha,
      'branch': _branch,
    });

    final response = await _put(url, body);
    final result = json.decode(response.body) as Map<String, dynamic>;
    final commit = result['commit'] as Map<String, dynamic>;

    // Clear tree cache and ETag cache for this file
    _lastTreeSha = null;
    _etagCache.remove(path);

    return commit['sha'] as String;
  }

  /// Deletes a file from the repository.
  ///
  /// [path] - File path relative to repository root
  /// [currentSha] - Current SHA of the file (for optimistic locking)
  /// [message] - Commit message (defaults to "Delete {filename}")
  ///
  /// Returns the SHA of the delete commit.
  ///
  /// Throws [GitHubException] if the SHA doesn't match or deletion fails.
  Future<String> deleteFile({
    required String path,
    required String currentSha,
    String? message,
  }) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');

    final filename = path.split('/').last;
    final commitMessage = message ?? 'Delete $filename';

    final body = json.encode({
      'message': commitMessage,
      'sha': currentSha,
      'branch': _branch,
    });

    final response = await _delete(url, body);
    final result = json.decode(response.body) as Map<String, dynamic>;
    final commit = result['commit'] as Map<String, dynamic>;

    // Clear caches
    _lastTreeSha = null;
    _etagCache.remove(path);

    return commit['sha'] as String;
  }

  /// Performs an operation with automatic retry logic for transient errors.
  ///
  /// Retries on network errors and 5xx server errors with exponential backoff.
  /// Does not retry on authentication errors or client errors (4xx).
  Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = _defaultMaxRetries,
  }) async {
    Duration delay = _defaultInitialDelay;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        // Don't retry if this is the last attempt
        if (attempt == maxAttempts) rethrow;

        // Don't retry non-transient errors
        if (!_isTransientError(e)) rethrow;

        // Wait with exponential backoff
        await Future.delayed(delay);
        final newDelayMs = (delay.inMilliseconds * 2).toInt();
        final clampedMs = newDelayMs.clamp(
          _defaultInitialDelay.inMilliseconds,
          _maxDelay.inMilliseconds,
        );
        delay = Duration(milliseconds: clampedMs);
      }
    }

    throw GitHubException('Operation failed after $maxAttempts attempts');
  }

  /// Checks if an error is transient and should be retried.
  bool _isTransientError(dynamic error) {
    // Network errors are always transient
    if (error is SocketException || error is TimeoutException) {
      return true;
    }

    // Server errors (5xx) are transient
    if (error is GitHubException && error.statusCode != null) {
      final code = error.statusCode!;
      return code >= 500 && code < 600;
    }

    return false;
  }

  /// Builds standard headers for GitHub API requests.
  Map<String, String> _buildHeaders() {
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'PinboardWizard/1.0',
    };
  }

  /// Performs a GET request with retry logic.
  Future<http.Response> _get(Uri url) async {
    return withRetry(() async {
      final response = await _httpClient.get(url, headers: _buildHeaders());
      _updateRateLimitInfo(response);
      _handleResponse(response);
      return response;
    });
  }

  /// Performs a GET request with custom headers.
  Future<http.Response> _getWithHeaders(
    Uri url,
    Map<String, String> headers,
  ) async {
    return withRetry(() async {
      final response = await _httpClient.get(url, headers: headers);
      _updateRateLimitInfo(response);

      // Don't throw on 304 Not Modified
      if (response.statusCode == 304) {
        return response;
      }

      _handleResponse(response);
      return response;
    });
  }

  /// Performs a PUT request with retry logic.
  Future<http.Response> _put(Uri url, String body) async {
    return withRetry(() async {
      final headers = _buildHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await _httpClient.put(url, headers: headers, body: body);
      _updateRateLimitInfo(response);
      _handleResponse(response);
      return response;
    });
  }

  /// Performs a DELETE request with retry logic.
  Future<http.Response> _delete(Uri url, String body) async {
    return withRetry(() async {
      final headers = _buildHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await _httpClient.delete(
        url,
        headers: headers,
        body: body,
      );
      _updateRateLimitInfo(response);
      _handleResponse(response);
      return response;
    });
  }

  /// Updates rate limit information from response headers.
  void _updateRateLimitInfo(http.Response response) {
    if (response.headers.containsKey('x-ratelimit-limit')) {
      _rateLimitInfo = RateLimitInfo.fromHeaders(response.headers);
    }
  }

  /// Handles HTTP response and throws appropriate exceptions.
  void _handleResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GitHubAuthException(
        'Authentication failed. Please check your API token and permissions.',
        statusCode: response.statusCode,
        response: response.body,
      );
    }

    if (response.statusCode == 429) {
      throw GitHubRateLimitException(
        'GitHub API rate limit exceeded. Please try again later.',
        statusCode: response.statusCode,
        response: response.body,
        rateLimitInfo: _rateLimitInfo,
      );
    }

    if (response.statusCode == 404) {
      throw GitHubException(
        'Resource not found. Please check the repository and file path.',
        statusCode: response.statusCode,
        response: response.body,
      );
    }

    if (response.statusCode == 409) {
      throw GitHubException(
        'Conflict detected. The file may have been modified by another process.',
        statusCode: response.statusCode,
        response: response.body,
      );
    }

    if (response.statusCode == 422) {
      throw GitHubException(
        'Validation failed. Please check your request parameters.',
        statusCode: response.statusCode,
        response: response.body,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GitHubException(
        'GitHub API request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        response: response.body,
      );
    }
  }

  /// Validates that the client is properly configured and authenticated.
  ///
  /// Makes a lightweight API call to verify credentials.
  /// Returns true if authentication is valid, false otherwise.
  Future<bool> testAuthentication() async {
    try {
      final url = Uri.parse('$_baseUrl/user');
      await _get(url);
      return true;
    } on GitHubAuthException {
      return false;
    } catch (e) {
      // Other errors might indicate network issues, not auth issues
      rethrow;
    }
  }

  /// Clears all cached data (tree SHA and ETags).
  ///
  /// Useful when you want to force a full sync.
  void clearCache() {
    _lastTreeSha = null;
    _etagCache.clear();
  }

  /// Disposes of the HTTP client.
  ///
  /// Call this when you're done using the client.
  void dispose() {
    _httpClient.close();
  }
}
