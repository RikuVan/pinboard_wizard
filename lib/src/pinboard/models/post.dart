import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'post.g.dart';

@JsonSerializable()
class Post extends Equatable {
  final String href;
  final String description;
  final String extended;
  final String meta;
  final String hash;
  final DateTime time;
  @JsonKey(fromJson: _stringToBool, toJson: _boolToString)
  final bool shared;
  @JsonKey(fromJson: _stringToBool, toJson: _boolToString)
  final bool toread;
  final String tags;

  const Post({
    required this.href,
    required this.description,
    required this.extended,
    required this.meta,
    required this.hash,
    required this.time,
    required this.shared,
    required this.toread,
    required this.tags,
  });

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
  Map<String, dynamic> toJson() => _$PostToJson(this);

  static bool _stringToBool(String value) {
    return value.toLowerCase() == 'yes';
  }

  static String _boolToString(bool value) {
    return value ? 'yes' : 'no';
  }

  List<String> get tagList {
    if (tags.trim().isEmpty) return [];
    return tags.split(' ').where((tag) => tag.isNotEmpty).toList();
  }

  bool hasTag(String tag) {
    return tagList.any((t) => t.toLowerCase() == tag.toLowerCase());
  }

  /// Check if this post has any pin-related tags (pin, pin:category, etc.)
  bool get isPinned {
    return tagList.any((tag) {
      final lowerTag = tag.toLowerCase();
      return lowerTag == 'pin' || lowerTag.startsWith('pin:');
    });
  }

  /// Get the pin category from pin tags. Returns null if not pinned.
  /// Examples:
  /// - "pin" -> null (general/uncategorized)
  /// - "pin:work" -> "Work"
  /// - "pin:work-pay" -> "Work pay"
  /// - "pin:personal-stuff" -> "Personal stuff"
  String? get pinCategory {
    final pinTags = tagList.where((tag) {
      final lowerTag = tag.toLowerCase();
      return lowerTag == 'pin' || lowerTag.startsWith('pin:');
    }).toList();
    if (pinTags.isEmpty) return null;

    // Look for categorized pin tags first
    for (final tag in pinTags) {
      if (tag.contains(':')) {
        final parts = tag.split(':');
        if (parts.length >= 2) {
          final categoryPart = parts[1];
          // Replace hyphens with spaces and capitalize each word
          return categoryPart
              .split('-')
              .map(
                (word) => word.isNotEmpty
                    ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                    : word,
              )
              .join(' ');
        }
      }
    }

    // If only "pin" tag exists, return null (will be grouped as "General")
    return null;
  }

  /// Get all pin-related tags for this post
  List<String> get pinTags {
    return tagList.where((tag) {
      final lowerTag = tag.toLowerCase();
      return lowerTag == 'pin' || lowerTag.startsWith('pin:');
    }).toList();
  }

  String get domain {
    try {
      final uri = Uri.parse(href);
      return uri.host;
    } catch (e) {
      return '';
    }
  }

  Post copyWith({
    String? href,
    String? description,
    String? extended,
    String? meta,
    String? hash,
    DateTime? time,
    bool? shared,
    bool? toread,
    String? tags,
  }) {
    return Post(
      href: href ?? this.href,
      description: description ?? this.description,
      extended: extended ?? this.extended,
      meta: meta ?? this.meta,
      hash: hash ?? this.hash,
      time: time ?? this.time,
      shared: shared ?? this.shared,
      toread: toread ?? this.toread,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
    href,
    description,
    extended,
    meta,
    hash,
    time,
    shared,
    toread,
    tags,
  ];

  @override
  bool get stringify => true;
}
