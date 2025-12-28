import 'dart:async';
import 'dart:io';

/// Service for checking network connectivity before sync operations.
///
/// Provides methods to verify if the device has internet access by attempting
/// to resolve GitHub's API domain.
class NetworkService {
  /// Check if device has internet connectivity
  ///
  /// Attempts to resolve GitHub's API domain to verify connectivity.
  /// Returns false if DNS lookup fails or throws a SocketException.
  Future<bool> isOnline() async {
    try {
      // Try to lookup GitHub's DNS
      final result = await InternetAddress.lookup('api.github.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Check connectivity with timeout
  ///
  /// Same as [isOnline] but with a configurable timeout to prevent
  /// hanging on slow networks.
  ///
  /// Returns false if the check times out.
  Future<bool> isOnlineWithTimeout({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      return await isOnline().timeout(timeout);
    } on TimeoutException {
      return false;
    }
  }

  /// Check if online and throw if offline
  ///
  /// Convenience method that throws a [NetworkException] if offline.
  /// Useful for operations that require connectivity.
  Future<void> requireOnline({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final online = await isOnlineWithTimeout(timeout: timeout);
    if (!online) {
      throw NetworkException('No internet connection');
    }
  }
}

/// Exception thrown when network operations fail due to connectivity issues
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
