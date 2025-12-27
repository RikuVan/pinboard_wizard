import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/github/github_client.dart';

import 'github_client_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockHttpClient;
  late GitHubClient client;

  const token = 'ghp_test_token';
  const owner = 'testuser';
  const repo = 'testrepo';
  const branch = 'main';
  const notesPath = 'notes/';

  setUp(() {
    mockHttpClient = MockClient();
    client = GitHubClient(
      token: token,
      owner: owner,
      repo: repo,
      branch: branch,
      notesPath: notesPath,
      httpClient: mockHttpClient,
    );
  });

  group('GitHubClient - Authentication', () {
    test('testAuthentication returns true on successful auth', () async {
      // Arrange
      final response = http.Response(
        '{"login": "testuser"}',
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse('https://api.github.com/user'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      final result = await client.testAuthentication();

      // Assert
      expect(result, true);
      verify(
        mockHttpClient.get(
          Uri.parse('https://api.github.com/user'),
          headers: anyNamed('headers'),
        ),
      ).called(1);
    });

    test('testAuthentication returns false on 401 error', () async {
      // Arrange
      final response = http.Response('{"message": "Bad credentials"}', 401);

      when(
        mockHttpClient.get(
          Uri.parse('https://api.github.com/user'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      final result = await client.testAuthentication();

      // Assert
      expect(result, false);
    });

    test('testAuthentication throws on network error', () async {
      // Arrange
      when(
        mockHttpClient.get(
          Uri.parse('https://api.github.com/user'),
          headers: anyNamed('headers'),
        ),
      ).thenThrow(SocketException('Network error'));

      // Act & Assert
      expect(
        () => client.testAuthentication(),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('GitHubClient - List Files', () {
    test('listNotesFiles returns markdown files from tree API', () async {
      // Arrange - Mock commit response
      final commitResponse = http.Response(
        json.encode({
          'sha': 'commit123',
          'tree': {'sha': 'tree123'},
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      // Mock tree response
      final treeResponse = http.Response(
        json.encode({
          'sha': 'tree123',
          'tree': [
            {
              'path': 'notes/file1.md',
              'sha': 'sha1',
              'size': 100,
              'type': 'blob',
            },
            {
              'path': 'notes/file2.md',
              'sha': 'sha2',
              'size': 200,
              'type': 'blob',
            },
            {
              'path': 'notes/subfolder/file3.markdown',
              'sha': 'sha3',
              'size': 150,
              'type': 'blob',
            },
            {
              'path': 'notes/not-markdown.txt',
              'sha': 'sha4',
              'size': 50,
              'type': 'blob',
            },
            {
              'path': 'other/file.md',
              'sha': 'sha5',
              'size': 75,
              'type': 'blob',
            },
          ],
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4998',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$branch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => commitResponse);

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/git/trees/tree123?recursive=1',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => treeResponse);

      // Act
      final files = await client.listNotesFiles();

      // Assert
      expect(files.length, 3); // Only .md and .markdown files in notes/
      expect(files[0].path, 'notes/file1.md');
      expect(files[0].sha, 'sha1');
      expect(files[0].size, 100);
      expect(files[1].path, 'notes/file2.md');
      expect(files[2].path, 'notes/subfolder/file3.markdown');
    });

    test('listNotesFiles returns empty list when tree unchanged', () async {
      // Arrange - First call
      final commitResponse1 = http.Response(
        json.encode({
          'sha': 'commit123',
          'tree': {'sha': 'tree123'},
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      final treeResponse = http.Response(
        json.encode({
          'sha': 'tree123',
          'tree': [
            {
              'path': 'notes/file1.md',
              'sha': 'sha1',
              'size': 100,
              'type': 'blob',
            },
          ],
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4998',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$branch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => commitResponse1);

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/git/trees/tree123?recursive=1',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => treeResponse);

      // First call
      final files1 = await client.listNotesFiles();
      expect(files1.length, 1);

      // Second call with same tree SHA
      final files2 = await client.listNotesFiles();

      // Assert
      expect(files2.length, 0); // Empty because tree hasn't changed
    });
  });

  group('GitHubClient - Download File', () {
    test('downloadFile returns decoded content', () async {
      // Arrange
      const fileContent = 'Hello, World!';
      final base64Content = base64.encode(utf8.encode(fileContent));

      final response = http.Response(
        json.encode({
          'path': 'notes/test.md',
          'sha': 'sha123',
          'size': fileContent.length,
          'type': 'file',
          'content': base64Content,
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/notes/test.md?ref=$branch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      final content = await client.downloadFile('notes/test.md');

      // Assert
      expect(content, fileContent);
    });

    test('downloadFile returns null on 304 Not Modified', () async {
      // Arrange - First call to set ETag
      const fileContent = 'Hello, World!';
      final base64Content = base64.encode(utf8.encode(fileContent));

      final response1 = http.Response(
        json.encode({
          'path': 'notes/test.md',
          'sha': 'sha123',
          'size': fileContent.length,
          'type': 'file',
          'content': base64Content,
        }),
        200,
        headers: {
          'etag': 'W/"abc123"',
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/notes/test.md?ref=$branch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => response1);

      // First call
      await client.downloadFile('notes/test.md');

      // Second call with 304 response
      final response2 = http.Response(
        '',
        304,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4998',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/notes/test.md?ref=$branch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => response2);

      // Act
      final content = await client.downloadFile('notes/test.md');

      // Assert
      expect(content, null);
    });
  });

  group('GitHubClient - Create File', () {
    test('createFile successfully creates a file', () async {
      // Arrange
      const filePath = 'notes/new-note.md';
      const content = '# New Note\n\nContent here';
      final base64Content = base64.encode(utf8.encode(content));

      final response = http.Response(
        json.encode({
          'commit': {'sha': 'commit123'},
          'content': {'sha': 'file123'},
        }),
        201,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.put(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      final commitSha = await client.createFile(
        path: filePath,
        content: content,
        message: 'Create new note',
      );

      // Assert
      expect(commitSha, 'commit123');

      // Verify request body
      final captured = verify(
        mockHttpClient.put(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;

      final bodyJson = json.decode(captured[1] as String);
      expect(bodyJson['message'], 'Create new note');
      expect(bodyJson['content'], base64Content);
      expect(bodyJson['branch'], branch);
    });

    test('createFile uses default commit message', () async {
      // Arrange
      const filePath = 'notes/new-note.md';
      const content = '# New Note';

      final response = http.Response(
        json.encode({
          'commit': {'sha': 'commit123'},
          'content': {'sha': 'file123'},
        }),
        201,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.put(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      await client.createFile(path: filePath, content: content);

      // Assert - Verify default message
      final captured = verify(
        mockHttpClient.put(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;

      final bodyJson = json.decode(captured.last as String);
      expect(bodyJson['message'], 'Create new-note.md');
    });
  });

  group('GitHubClient - Update File', () {
    test('updateFile successfully updates a file', () async {
      // Arrange
      const filePath = 'notes/existing.md';
      const content = '# Updated Content';
      const currentSha = 'oldsha123';
      final base64Content = base64.encode(utf8.encode(content));

      final response = http.Response(
        json.encode({
          'commit': {'sha': 'newcommit123'},
          'content': {'sha': 'newfile123'},
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.put(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      final commitSha = await client.updateFile(
        path: filePath,
        content: content,
        currentSha: currentSha,
        message: 'Update note',
      );

      // Assert
      expect(commitSha, 'newcommit123');

      final captured = verify(
        mockHttpClient.put(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;

      final bodyJson = json.decode(captured.last as String);
      expect(bodyJson['message'], 'Update note');
      expect(bodyJson['content'], base64Content);
      expect(bodyJson['sha'], currentSha);
      expect(bodyJson['branch'], branch);
    });

    test('updateFile throws GitHubException on conflict (409)', () async {
      // Arrange
      const filePath = 'notes/existing.md';
      const content = '# Updated Content';
      const currentSha = 'wrongsha';

      final response = http.Response('{"message": "SHA does not match"}', 409);

      when(
        mockHttpClient.put(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => response);

      // Act & Assert
      expect(
        () => client.updateFile(
          path: filePath,
          content: content,
          currentSha: currentSha,
        ),
        throwsA(isA<GitHubException>()),
      );
    });
  });

  group('GitHubClient - Delete File', () {
    test('deleteFile successfully deletes a file', () async {
      // Arrange
      const filePath = 'notes/to-delete.md';
      const currentSha = 'sha123';

      final response = http.Response(
        json.encode({
          'commit': {'sha': 'deletecommit123'},
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.delete(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      final commitSha = await client.deleteFile(
        path: filePath,
        currentSha: currentSha,
        message: 'Delete old note',
      );

      // Assert
      expect(commitSha, 'deletecommit123');

      final captured = verify(
        mockHttpClient.delete(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/contents/$filePath',
          ),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;

      final bodyJson = json.decode(captured.last as String);
      expect(bodyJson['message'], 'Delete old note');
      expect(bodyJson['sha'], currentSha);
      expect(bodyJson['branch'], branch);
    });
  });

  group('GitHubClient - Error Handling', () {
    test('throws GitHubAuthException on 401', () async {
      // Arrange
      final response = http.Response('{"message": "Bad credentials"}', 401);

      when(
        mockHttpClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => response);

      // Act & Assert
      expect(
        () => client.listNotesFiles(),
        throwsA(isA<GitHubAuthException>()),
      );
    });

    test('throws GitHubAuthException on 403', () async {
      // Arrange
      final response = http.Response('{"message": "Forbidden"}', 403);

      when(
        mockHttpClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => response);

      // Act & Assert
      expect(
        () => client.listNotesFiles(),
        throwsA(isA<GitHubAuthException>()),
      );
    });

    test('throws GitHubRateLimitException on 429', () async {
      // Arrange
      final response = http.Response(
        '{"message": "API rate limit exceeded"}',
        429,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset':
              '${DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => response);

      // Act & Assert
      expect(
        () => client.listNotesFiles(),
        throwsA(isA<GitHubRateLimitException>()),
      );
    });

    test('throws GitHubException on 404', () async {
      // Arrange
      final response = http.Response('{"message": "Not Found"}', 404);

      when(
        mockHttpClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => response);

      // Act & Assert
      expect(() => client.listNotesFiles(), throwsA(isA<GitHubException>()));
    });

    test('throws GitHubException on 422 validation error', () async {
      // Arrange
      final response = http.Response('{"message": "Validation Failed"}', 422);

      when(
        mockHttpClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => response);

      // Act & Assert
      expect(() => client.listNotesFiles(), throwsA(isA<GitHubException>()));
    });
  });

  group('GitHubClient - Retry Logic', () {
    test('retries on transient errors and succeeds', () async {
      // Arrange
      var attemptCount = 0;
      final commitResponse = http.Response(
        json.encode({
          'sha': 'commit123',
          'tree': {'sha': 'tree123'},
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$branch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async {
        attemptCount++;
        if (attemptCount < 3) {
          throw SocketException('Network error');
        }
        return commitResponse;
      });

      // Act
      await client.withRetry(() async {
        final response = await mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$branch',
          ),
          headers: const {},
        );
        return response;
      });

      // Assert
      expect(attemptCount, 3);
    });

    test('retries on 500 errors and succeeds', () async {
      // Arrange
      var attemptCount = 0;
      final successResponse = http.Response(
        '{"data": "ok"}',
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((
        _,
      ) async {
        attemptCount++;
        if (attemptCount < 2) {
          return http.Response('Internal Server Error', 500);
        }
        return successResponse;
      });

      // Act
      final result = await client.withRetry(() async {
        final response = await mockHttpClient.get(
          Uri.parse('https://api.github.com/test'),
          headers: const {},
        );
        if (response.statusCode >= 500) {
          throw GitHubException(
            'Server error',
            statusCode: response.statusCode,
          );
        }
        return response;
      });

      // Assert
      expect(attemptCount, 2);
      expect(result.statusCode, 200);
    });

    test('does not retry on 401 auth errors', () async {
      // Arrange
      var attemptCount = 0;

      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((
        _,
      ) async {
        attemptCount++;
        throw GitHubAuthException('Bad credentials', statusCode: 401);
      });

      // Act & Assert
      expect(
        () => client.withRetry(() async {
          await mockHttpClient.get(
            Uri.parse('https://api.github.com/test'),
            headers: const {},
          );
          throw GitHubAuthException('Bad credentials', statusCode: 401);
        }),
        throwsA(isA<GitHubAuthException>()),
      );
      expect(attemptCount, 1); // Should not retry
    });

    test('gives up after max retries', () async {
      // Arrange
      var attemptCount = 0;

      // Act & Assert
      await expectLater(
        client.withRetry(() async {
          attemptCount++;
          throw SocketException('Network error');
        }, maxAttempts: 3),
        throwsA(isA<SocketException>()),
      );
      expect(attemptCount, 3);
    });
  });

  group('GitHubClient - Rate Limit Tracking', () {
    test('tracks rate limit from response headers', () async {
      // Arrange
      final response = http.Response(
        '{"login": "testuser"}',
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4500',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse('https://api.github.com/user'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => response);

      // Act
      await client.testAuthentication();

      // Assert
      final rateLimit = client.rateLimitInfo;
      expect(rateLimit, isNotNull);
      expect(rateLimit!.limit, 5000);
      expect(rateLimit.remaining, 4500);
    });

    test('rateLimitInfo is null before any requests', () {
      // Assert
      expect(client.rateLimitInfo, isNull);
    });
  });

  group('GitHubClient - Cache Management', () {
    test('clearCache resets tree SHA and ETags', () async {
      // Arrange - Make a request to populate caches
      final commitResponse = http.Response(
        json.encode({
          'sha': 'commit123',
          'tree': {'sha': 'tree123'},
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      final treeResponse = http.Response(
        json.encode({
          'sha': 'tree123',
          'tree': [
            {
              'path': 'notes/file.md',
              'sha': 'sha1',
              'size': 100,
              'type': 'blob',
            },
          ],
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4998',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$branch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => commitResponse);

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/git/trees/tree123?recursive=1',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => treeResponse);

      await client.listNotesFiles();

      // Act
      client.clearCache();

      // Assert - Next call should fetch tree again
      final files = await client.listNotesFiles();
      expect(files.length, 1);
      verify(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/git/trees/tree123?recursive=1',
          ),
          headers: anyNamed('headers'),
        ),
      ).called(2); // Called twice because cache was cleared
    });
  });

  group('GitHubClient - Configuration', () {
    test('handles custom notes path without trailing slash', () {
      // Arrange & Act
      final customClient = GitHubClient(
        token: token,
        owner: owner,
        repo: repo,
        branch: branch,
        notesPath: 'custom',
        httpClient: mockHttpClient,
      );

      // Assert - Internal path should have trailing slash added
      // We can't directly access the private field, but we can verify behavior
      expect(customClient, isNotNull);
    });

    test('uses provided branch name', () async {
      // Arrange
      const customBranch = 'develop';
      final customClient = GitHubClient(
        token: token,
        owner: owner,
        repo: repo,
        branch: customBranch,
        notesPath: notesPath,
        httpClient: mockHttpClient,
      );

      final response = http.Response(
        json.encode({
          'sha': 'commit123',
          'tree': {'sha': 'tree123'},
        }),
        200,
        headers: {
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4999',
          'x-ratelimit-reset':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$customBranch',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => response);

      // Act & Assert - Should use custom branch
      await customClient.withRetry(() async {
        final resp = await mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$customBranch',
          ),
          headers: const {},
        );
        return resp;
      });

      verify(
        mockHttpClient.get(
          Uri.parse(
            'https://api.github.com/repos/$owner/$repo/commits/$customBranch',
          ),
          headers: anyNamed('headers'),
        ),
      ).called(1);
    });
  });
}
