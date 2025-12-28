import 'package:pinboard_wizard/src/database/notes_database.dart';

/// Represents the result of a sync operation with multiple notes.
///
/// Tracks which notes succeeded, failed, or have conflicts, along with
/// metadata about the sync operation (online status, timestamp).
class SyncResult {
  /// Notes that were successfully synced to GitHub
  final List<Note> succeeded;

  /// Notes that failed to sync with error details
  final List<SyncFailure> failed;

  /// Notes that have conflicts requiring user resolution
  final List<Note> conflicts;

  /// Whether the device was online during sync
  final bool isOnline;

  /// When the sync operation completed
  final DateTime timestamp;

  SyncResult({
    required this.succeeded,
    required this.failed,
    required this.conflicts,
    required this.isOnline,
    required this.timestamp,
  });

  /// All operations succeeded without conflicts
  bool get isFullSuccess => failed.isEmpty && conflicts.isEmpty;

  /// Some operations succeeded, but some failed or have conflicts
  bool get isPartialSuccess =>
      succeeded.isNotEmpty && (failed.isNotEmpty || conflicts.isNotEmpty);

  /// All operations failed or resulted in conflicts
  bool get isFullFailure =>
      succeeded.isEmpty && (failed.isNotEmpty || conflicts.isNotEmpty);

  /// User-friendly message summarizing the sync result
  String get userMessage {
    if (!isOnline) {
      return 'Offline - sync pending';
    }
    if (isFullSuccess) {
      return 'Synced ${succeeded.length} note${succeeded.length == 1 ? '' : 's'}';
    }
    if (isPartialSuccess) {
      final parts = <String>[];
      if (succeeded.isNotEmpty) parts.add('${succeeded.length} synced');
      if (failed.isNotEmpty) parts.add('${failed.length} pending');
      if (conflicts.isNotEmpty) {
        parts.add(
          '${conflicts.length} conflict${conflicts.length == 1 ? '' : 's'}',
        );
      }
      return parts.join(', ');
    }
    if (isFullFailure) {
      return 'Sync failed: ${failed.first.error}';
    }
    return 'Unknown sync status';
  }

  /// Toast severity level based on sync outcome
  ToastSeverity get severity {
    if (isFullSuccess) return ToastSeverity.success;
    if (isPartialSuccess) return ToastSeverity.warning;
    return ToastSeverity.error;
  }

  /// Create a sync result for offline state
  factory SyncResult.offline({DateTime? timestamp}) {
    return SyncResult(
      succeeded: [],
      failed: [],
      conflicts: [],
      isOnline: false,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Create a sync result for full success
  factory SyncResult.success({required List<Note> notes, DateTime? timestamp}) {
    return SyncResult(
      succeeded: notes,
      failed: [],
      conflicts: [],
      isOnline: true,
      timestamp: timestamp ?? DateTime.now(),
    );
  }
}

/// Represents a single note that failed to sync
class SyncFailure {
  /// The note that failed to sync
  final Note note;

  /// Error message describing what went wrong
  final String error;

  /// Category of failure for appropriate handling
  final SyncFailureType type;

  /// When the failure occurred
  final DateTime timestamp;

  SyncFailure({
    required this.note,
    required this.error,
    required this.type,
    required this.timestamp,
  });

  /// User-friendly message based on failure type
  String get userMessage {
    switch (type) {
      case SyncFailureType.network:
        return 'Network error - will retry';
      case SyncFailureType.conflict:
        return 'Conflict detected';
      case SyncFailureType.auth:
        return 'Authentication failed';
      case SyncFailureType.rateLimit:
        return 'Rate limited - retry later';
      case SyncFailureType.validation:
        return 'Invalid content';
      case SyncFailureType.unknown:
        return error;
    }
  }

  /// Whether this is a transient failure that can be retried
  bool get isRetryable {
    switch (type) {
      case SyncFailureType.network:
      case SyncFailureType.rateLimit:
        return true;
      case SyncFailureType.conflict:
      case SyncFailureType.auth:
      case SyncFailureType.validation:
      case SyncFailureType.unknown:
        return false;
    }
  }
}

/// Categories of sync failures for appropriate handling
enum SyncFailureType {
  /// Timeout, connection lost, DNS failure
  network,

  /// SHA mismatch, concurrent edit
  conflict,

  /// 401/403, token expired
  auth,

  /// 429, exceeded API quota
  rateLimit,

  /// 422, invalid data
  validation,

  /// Unexpected error
  unknown,
}

/// Severity levels for toast notifications
enum ToastSeverity {
  /// Green - operation completed successfully
  success,

  /// Yellow/Orange - partial success or non-critical issue
  warning,

  /// Red - operation failed
  error,

  /// Blue - informational message
  info,
}
