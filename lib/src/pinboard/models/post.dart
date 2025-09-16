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
