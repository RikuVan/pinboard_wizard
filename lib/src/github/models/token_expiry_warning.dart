import 'package:equatable/equatable.dart';

/// Severity level for token expiry warnings
enum WarningSeverity {
  low, // 7+ days remaining
  medium, // 3-7 days remaining
  high, // 0-3 days remaining
}

/// Model for token expiry warning information
class TokenExpiryWarning extends Equatable {
  /// Warning message to display to the user
  final String message;

  /// Number of days remaining until token expires
  final int daysRemaining;

  /// Severity level of the warning
  final WarningSeverity severity;

  const TokenExpiryWarning({
    required this.message,
    required this.daysRemaining,
    required this.severity,
  });

  /// Create a warning from a config's expiry date
  factory TokenExpiryWarning.fromExpiry(DateTime expiryDate) {
    final daysRemaining = expiryDate.difference(DateTime.now()).inDays;
    final severity = daysRemaining <= 3
        ? WarningSeverity.high
        : daysRemaining <= 7
        ? WarningSeverity.medium
        : WarningSeverity.low;

    final message =
        'Your GitHub token expires in $daysRemaining day${daysRemaining == 1 ? '' : 's'}. '
        'Please renew it in Settings to avoid sync interruption.';

    return TokenExpiryWarning(
      message: message,
      daysRemaining: daysRemaining,
      severity: severity,
    );
  }

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [message, daysRemaining, severity];
}
