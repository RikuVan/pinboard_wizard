import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/notes/models/sync_result.dart';

void main() {
  group('SyncResult', () {
    late Note testNote1;
    late Note testNote2;
    late Note testNote3;

    setUp(() {
      final now = DateTime.now();
      testNote1 = Note(
        id: 'note-1',
        path: 'notes/test-1.md',
        title: 'Test Note 1',
        lastKnownSha: 'sha1',
        isDirty: false,
        updatedAt: now,
        createdAt: now,
        contentPreview: 'Preview 1',
        contentLength: 100,
        isConflict: false,
        markedForDeletion: false,
      );

      testNote2 = Note(
        id: 'note-2',
        path: 'notes/test-2.md',
        title: 'Test Note 2',
        lastKnownSha: 'sha2',
        isDirty: true,
        updatedAt: now,
        createdAt: now,
        contentPreview: 'Preview 2',
        contentLength: 200,
        isConflict: false,
        markedForDeletion: false,
      );

      testNote3 = Note(
        id: 'note-3',
        path: 'notes/test-3.md',
        title: 'Test Note 3',
        lastKnownSha: 'sha3',
        isDirty: false,
        updatedAt: now,
        createdAt: now,
        contentPreview: 'Preview 3',
        contentLength: 300,
        isConflict: true,
        markedForDeletion: false,
      );
    });

    group('Status Flags', () {
      test('isFullSuccess returns true when no failures or conflicts', () {
        final result = SyncResult(
          succeeded: [testNote1, testNote2],
          failed: [],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.isFullSuccess, isTrue);
        expect(result.isPartialSuccess, isFalse);
        expect(result.isFullFailure, isFalse);
      });

      test('isPartialSuccess returns true when some succeed and some fail', () {
        final failure = SyncFailure(
          note: testNote2,
          error: 'Network error',
          type: SyncFailureType.network,
          timestamp: DateTime.now(),
        );

        final result = SyncResult(
          succeeded: [testNote1],
          failed: [failure],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.isFullSuccess, isFalse);
        expect(result.isPartialSuccess, isTrue);
        expect(result.isFullFailure, isFalse);
      });

      test(
        'isPartialSuccess returns true when some succeed and some conflict',
        () {
          final result = SyncResult(
            succeeded: [testNote1],
            failed: [],
            conflicts: [testNote3],
            isOnline: true,
            timestamp: DateTime.now(),
          );

          expect(result.isFullSuccess, isFalse);
          expect(result.isPartialSuccess, isTrue);
          expect(result.isFullFailure, isFalse);
        },
      );

      test('isFullFailure returns true when all operations fail', () {
        final failure = SyncFailure(
          note: testNote1,
          error: 'Auth error',
          type: SyncFailureType.auth,
          timestamp: DateTime.now(),
        );

        final result = SyncResult(
          succeeded: [],
          failed: [failure],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.isFullSuccess, isFalse);
        expect(result.isPartialSuccess, isFalse);
        expect(result.isFullFailure, isTrue);
      });

      test('isFullFailure returns true when all operations conflict', () {
        final result = SyncResult(
          succeeded: [],
          failed: [],
          conflicts: [testNote3],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.isFullSuccess, isFalse);
        expect(result.isPartialSuccess, isFalse);
        expect(result.isFullFailure, isTrue);
      });
    });

    group('User Messages', () {
      test('userMessage shows offline status', () {
        final result = SyncResult.offline();

        expect(result.userMessage, equals('Offline - sync pending'));
      });

      test('userMessage shows success for single note', () {
        final result = SyncResult(
          succeeded: [testNote1],
          failed: [],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.userMessage, equals('Synced 1 note'));
      });

      test('userMessage shows success for multiple notes', () {
        final result = SyncResult(
          succeeded: [testNote1, testNote2],
          failed: [],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.userMessage, equals('Synced 2 notes'));
      });

      test('userMessage shows partial success with failures', () {
        final failure = SyncFailure(
          note: testNote2,
          error: 'Network error',
          type: SyncFailureType.network,
          timestamp: DateTime.now(),
        );

        final result = SyncResult(
          succeeded: [testNote1],
          failed: [failure],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.userMessage, equals('1 synced, 1 pending'));
      });

      test('userMessage shows partial success with conflicts', () {
        final result = SyncResult(
          succeeded: [testNote1],
          failed: [],
          conflicts: [testNote3],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.userMessage, equals('1 synced, 1 conflict'));
      });

      test('userMessage shows partial success with multiple conflicts', () {
        final result = SyncResult(
          succeeded: [testNote1],
          failed: [],
          conflicts: [testNote2, testNote3],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.userMessage, equals('1 synced, 2 conflicts'));
      });

      test('userMessage shows all three categories', () {
        final failure = SyncFailure(
          note: testNote2,
          error: 'Network error',
          type: SyncFailureType.network,
          timestamp: DateTime.now(),
        );

        final result = SyncResult(
          succeeded: [testNote1],
          failed: [failure],
          conflicts: [testNote3],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.userMessage, equals('1 synced, 1 pending, 1 conflict'));
      });

      test('userMessage shows sync failed for full failure', () {
        final failure = SyncFailure(
          note: testNote1,
          error: 'Authentication failed',
          type: SyncFailureType.auth,
          timestamp: DateTime.now(),
        );

        final result = SyncResult(
          succeeded: [],
          failed: [failure],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(
          result.userMessage,
          equals('Sync failed: Authentication failed'),
        );
      });
    });

    group('Severity', () {
      test('severity is success for full success', () {
        final result = SyncResult(
          succeeded: [testNote1],
          failed: [],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.severity, equals(ToastSeverity.success));
      });

      test('severity is warning for partial success', () {
        final failure = SyncFailure(
          note: testNote2,
          error: 'Network error',
          type: SyncFailureType.network,
          timestamp: DateTime.now(),
        );

        final result = SyncResult(
          succeeded: [testNote1],
          failed: [failure],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.severity, equals(ToastSeverity.warning));
      });

      test('severity is error for full failure', () {
        final failure = SyncFailure(
          note: testNote1,
          error: 'Auth error',
          type: SyncFailureType.auth,
          timestamp: DateTime.now(),
        );

        final result = SyncResult(
          succeeded: [],
          failed: [failure],
          conflicts: [],
          isOnline: true,
          timestamp: DateTime.now(),
        );

        expect(result.severity, equals(ToastSeverity.error));
      });
    });

    group('Factory Constructors', () {
      test('offline factory creates offline result', () {
        final result = SyncResult.offline();

        expect(result.succeeded, isEmpty);
        expect(result.failed, isEmpty);
        expect(result.conflicts, isEmpty);
        expect(result.isOnline, isFalse);
        expect(result.timestamp, isNotNull);
      });

      test('offline factory accepts custom timestamp', () {
        final customTime = DateTime(2024, 1, 1);
        final result = SyncResult.offline(timestamp: customTime);

        expect(result.timestamp, equals(customTime));
      });

      test('success factory creates success result', () {
        final result = SyncResult.success(notes: [testNote1, testNote2]);

        expect(result.succeeded, equals([testNote1, testNote2]));
        expect(result.failed, isEmpty);
        expect(result.conflicts, isEmpty);
        expect(result.isOnline, isTrue);
        expect(result.timestamp, isNotNull);
      });

      test('success factory accepts custom timestamp', () {
        final customTime = DateTime(2024, 1, 1);
        final result = SyncResult.success(
          notes: [testNote1],
          timestamp: customTime,
        );

        expect(result.timestamp, equals(customTime));
      });
    });
  });

  group('SyncFailure', () {
    late Note testNote;

    setUp(() {
      testNote = Note(
        id: 'note-1',
        path: 'notes/test.md',
        title: 'Test Note',
        lastKnownSha: 'sha1',
        isDirty: false,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        contentPreview: 'Preview',
        contentLength: 100,
        isConflict: false,
        markedForDeletion: false,
      );
    });

    group('User Messages', () {
      test('network failure shows retry message', () {
        final failure = SyncFailure(
          note: testNote,
          error: 'Connection timeout',
          type: SyncFailureType.network,
          timestamp: DateTime.now(),
        );

        expect(failure.userMessage, equals('Network error - will retry'));
      });

      test('conflict failure shows conflict message', () {
        final failure = SyncFailure(
          note: testNote,
          error: 'SHA mismatch',
          type: SyncFailureType.conflict,
          timestamp: DateTime.now(),
        );

        expect(failure.userMessage, equals('Conflict detected'));
      });

      test('auth failure shows auth message', () {
        final failure = SyncFailure(
          note: testNote,
          error: '401 Unauthorized',
          type: SyncFailureType.auth,
          timestamp: DateTime.now(),
        );

        expect(failure.userMessage, equals('Authentication failed'));
      });

      test('rateLimit failure shows rate limit message', () {
        final failure = SyncFailure(
          note: testNote,
          error: '429 Too Many Requests',
          type: SyncFailureType.rateLimit,
          timestamp: DateTime.now(),
        );

        expect(failure.userMessage, equals('Rate limited - retry later'));
      });

      test('validation failure shows validation message', () {
        final failure = SyncFailure(
          note: testNote,
          error: '422 Unprocessable Entity',
          type: SyncFailureType.validation,
          timestamp: DateTime.now(),
        );

        expect(failure.userMessage, equals('Invalid content'));
      });

      test('unknown failure shows raw error message', () {
        final failure = SyncFailure(
          note: testNote,
          error: 'Something unexpected happened',
          type: SyncFailureType.unknown,
          timestamp: DateTime.now(),
        );

        expect(failure.userMessage, equals('Something unexpected happened'));
      });
    });

    group('Retryable', () {
      test('network failures are retryable', () {
        final failure = SyncFailure(
          note: testNote,
          error: 'Connection timeout',
          type: SyncFailureType.network,
          timestamp: DateTime.now(),
        );

        expect(failure.isRetryable, isTrue);
      });

      test('rate limit failures are retryable', () {
        final failure = SyncFailure(
          note: testNote,
          error: '429 Too Many Requests',
          type: SyncFailureType.rateLimit,
          timestamp: DateTime.now(),
        );

        expect(failure.isRetryable, isTrue);
      });

      test('conflict failures are not retryable', () {
        final failure = SyncFailure(
          note: testNote,
          error: 'SHA mismatch',
          type: SyncFailureType.conflict,
          timestamp: DateTime.now(),
        );

        expect(failure.isRetryable, isFalse);
      });

      test('auth failures are not retryable', () {
        final failure = SyncFailure(
          note: testNote,
          error: '401 Unauthorized',
          type: SyncFailureType.auth,
          timestamp: DateTime.now(),
        );

        expect(failure.isRetryable, isFalse);
      });

      test('validation failures are not retryable', () {
        final failure = SyncFailure(
          note: testNote,
          error: '422 Unprocessable Entity',
          type: SyncFailureType.validation,
          timestamp: DateTime.now(),
        );

        expect(failure.isRetryable, isFalse);
      });

      test('unknown failures are not retryable', () {
        final failure = SyncFailure(
          note: testNote,
          error: 'Something unexpected happened',
          type: SyncFailureType.unknown,
          timestamp: DateTime.now(),
        );

        expect(failure.isRetryable, isFalse);
      });
    });
  });

  group('SyncFailureType', () {
    test('enum has all expected values', () {
      expect(SyncFailureType.values, hasLength(6));
      expect(SyncFailureType.values, contains(SyncFailureType.network));
      expect(SyncFailureType.values, contains(SyncFailureType.conflict));
      expect(SyncFailureType.values, contains(SyncFailureType.auth));
      expect(SyncFailureType.values, contains(SyncFailureType.rateLimit));
      expect(SyncFailureType.values, contains(SyncFailureType.validation));
      expect(SyncFailureType.values, contains(SyncFailureType.unknown));
    });
  });

  group('ToastSeverity', () {
    test('enum has all expected values', () {
      expect(ToastSeverity.values, hasLength(4));
      expect(ToastSeverity.values, contains(ToastSeverity.success));
      expect(ToastSeverity.values, contains(ToastSeverity.warning));
      expect(ToastSeverity.values, contains(ToastSeverity.error));
      expect(ToastSeverity.values, contains(ToastSeverity.info));
    });
  });
}
