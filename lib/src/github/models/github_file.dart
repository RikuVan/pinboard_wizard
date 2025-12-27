import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'github_file.g.dart';

/// Represents a file in a GitHub repository.
///
/// This model is used to represent files returned from the GitHub API,
/// including both metadata (from tree API) and full content (from contents API).
@JsonSerializable(createToJson: true)
class GitHubFile extends Equatable {
  /// The file path relative to the repository root (e.g., "notes/flutter-state.md")
  final String path;

  /// The GitHub blob SHA for this file version
  final String sha;

  /// File size in bytes
  final int size;

  /// Type of the object ("file", "dir", or "blob")
  final String type;

  /// Base64 encoded content (only present in full file responses from contents API)
  final String? content;

  const GitHubFile({
    required this.path,
    required this.sha,
    required this.size,
    required this.type,
    this.content,
  });

  /// Creates a GitHubFile from JSON returned by the GitHub API
  factory GitHubFile.fromJson(Map<String, dynamic> json) =>
      _$GitHubFileFromJson(json);

  /// Converts this GitHubFile to JSON
  Map<String, dynamic> toJson() => _$GitHubFileToJson(this);

  /// Decodes the base64 content to a UTF-8 string
  ///
  /// Returns null if content is not present.
  /// Throws [FormatException] if content is not valid base64.
  String? get decodedContent {
    if (content == null) return null;

    try {
      // GitHub returns base64 with newlines, so remove them first
      final cleanContent = content!.replaceAll('\n', '').replaceAll('\r', '');
      return utf8.decode(base64.decode(cleanContent));
    } catch (e) {
      throw FormatException('Failed to decode file content: $e');
    }
  }

  /// Gets the filename from the path (e.g., "flutter-state.md" from "notes/flutter-state.md")
  String get filename {
    final parts = path.split('/');
    return parts.isEmpty ? path : parts.last;
  }

  /// Checks if this is a markdown file based on extension
  bool get isMarkdown =>
      path.toLowerCase().endsWith('.md') ||
      path.toLowerCase().endsWith('.markdown');

  @override
  List<Object?> get props => [path, sha, size, type, content];

  @override
  String toString() =>
      'GitHubFile(path: $path, sha: ${sha.substring(0, 7)}, size: $size)';
}
