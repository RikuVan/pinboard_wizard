import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rate_limit_info.g.dart';

/// Represents GitHub API rate limit information.
///
/// GitHub provides rate limit information in response headers:
/// - X-RateLimit-Limit: Maximum requests per hour (5000 for authenticated)
/// - X-RateLimit-Remaining: Requests remaining in current window
/// - X-RateLimit-Reset: Unix timestamp when the limit resets
///
/// This model helps track API usage and warn users before limits are exhausted.
@JsonSerializable(createToJson: true)
class RateLimitInfo extends Equatable {
  /// Maximum number of requests allowed per hour (typically 5000 for authenticated requests)
  final int limit;

  /// Number of requests remaining in the current rate limit window
  final int remaining;

  /// When the rate limit window resets
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime resetAt;

  const RateLimitInfo({
    required this.limit,
    required this.remaining,
    required this.resetAt,
  });

  /// Creates a RateLimitInfo from JSON
  factory RateLimitInfo.fromJson(Map<String, dynamic> json) =>
      _$RateLimitInfoFromJson(json);

  /// Converts this RateLimitInfo to JSON
  Map<String, dynamic> toJson() => _$RateLimitInfoToJson(this);

  /// Creates a RateLimitInfo from GitHub API response headers
  factory RateLimitInfo.fromHeaders(Map<String, String> headers) {
    final limit = int.tryParse(headers['x-ratelimit-limit'] ?? '5000') ?? 5000;
    final remaining =
        int.tryParse(headers['x-ratelimit-remaining'] ?? '5000') ?? 5000;
    final resetTimestamp =
        int.tryParse(headers['x-ratelimit-reset'] ?? '0') ?? 0;

    return RateLimitInfo(
      limit: limit,
      remaining: remaining,
      resetAt: DateTime.fromMillisecondsSinceEpoch(resetTimestamp * 1000),
    );
  }

  /// Returns true if remaining requests are low (< 100)
  bool get isLow => remaining < 100;

  /// Returns true if the rate limit is completely exhausted
  bool get isExhausted => remaining == 0;

  /// Returns a percentage of remaining requests (0-100)
  double get remainingPercentage => (remaining / limit) * 100;

  /// Returns the number of minutes until the rate limit resets
  int get minutesUntilReset {
    final duration = resetAt.difference(DateTime.now());
    return duration.inMinutes.clamp(0, double.infinity).toInt();
  }

  /// Returns the number of hours until the rate limit resets
  int get hoursUntilReset {
    final duration = resetAt.difference(DateTime.now());
    return duration.inHours.clamp(0, double.infinity).toInt();
  }

  /// Returns a user-friendly message about the current rate limit status
  String get userMessage {
    if (isExhausted) {
      final wait = minutesUntilReset;
      if (wait > 60) {
        final hours = hoursUntilReset;
        return 'GitHub API limit reached. Resets in ${hours}h ${wait % 60}m.';
      }
      return 'GitHub API limit reached. Resets in $wait minutes.';
    }

    if (isLow) {
      return 'API calls low: $remaining/$limit remaining';
    }

    return 'API calls: $remaining/$limit remaining';
  }

  /// Returns a shorter status message for UI display
  String get shortMessage => '$remaining/$limit calls';

  static DateTime _dateTimeFromJson(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);

  static int _dateTimeToJson(DateTime dateTime) =>
      dateTime.millisecondsSinceEpoch;

  @override
  List<Object?> get props => [limit, remaining, resetAt];

  @override
  String toString() =>
      'RateLimitInfo(remaining: $remaining/$limit, resets: $resetAt)';
}
