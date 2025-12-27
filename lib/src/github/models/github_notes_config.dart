import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'github_notes_config.g.dart';

/// Enum representing the type of GitHub Personal Access Token
enum TokenType {
  @JsonValue('classic')
  classic,
  @JsonValue('fine_grained')
  fineGrained,
}

/// Configuration for GitHub-backed notes storage
@JsonSerializable(explicitToJson: true)
class GitHubNotesConfig extends Equatable {
  /// GitHub username or organization name
  final String owner;

  /// Repository name (e.g., "personal-notes")
  final String repo;

  /// Branch to sync from (default: "main")
  final String branch;

  /// Repo path to notes folder (default: "notes/")
  final String notesPath;

  /// Unique device identifier for this installation
  final String deviceId;

  /// Type of Personal Access Token ('classic' or 'fine_grained')
  final TokenType tokenType;

  /// Token expiration date (for monitoring and warnings)
  final DateTime? tokenExpiry;

  /// Whether the GitHub notes feature is fully configured
  final bool isConfigured;

  const GitHubNotesConfig({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.notesPath = 'notes/',
    required this.deviceId,
    this.tokenType = TokenType.fineGrained,
    this.tokenExpiry,
    this.isConfigured = false,
  });

  /// Create an empty/unconfigured instance
  factory GitHubNotesConfig.empty(String deviceId) {
    return GitHubNotesConfig(
      owner: '',
      repo: '',
      deviceId: deviceId,
      isConfigured: false,
    );
  }

  /// Create a copy with updated fields
  GitHubNotesConfig copyWith({
    String? owner,
    String? repo,
    String? branch,
    String? notesPath,
    String? deviceId,
    TokenType? tokenType,
    DateTime? tokenExpiry,
    bool? isConfigured,
  }) {
    return GitHubNotesConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      branch: branch ?? this.branch,
      notesPath: notesPath ?? this.notesPath,
      deviceId: deviceId ?? this.deviceId,
      tokenType: tokenType ?? this.tokenType,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }

  factory GitHubNotesConfig.fromJson(Map<String, dynamic> json) =>
      _$GitHubNotesConfigFromJson(json);

  Map<String, dynamic> toJson() => _$GitHubNotesConfigToJson(this);

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [
    owner,
    repo,
    branch,
    notesPath,
    deviceId,
    tokenType,
    tokenExpiry,
    isConfigured,
  ];
}
