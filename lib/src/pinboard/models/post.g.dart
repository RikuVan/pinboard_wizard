// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Post _$PostFromJson(Map<String, dynamic> json) => Post(
  href: json['href'] as String,
  description: json['description'] as String,
  extended: json['extended'] as String,
  meta: json['meta'] as String,
  hash: json['hash'] as String,
  time: DateTime.parse(json['time'] as String),
  shared: Post._stringToBool(json['shared'] as String),
  toread: Post._stringToBool(json['toread'] as String),
  tags: json['tags'] as String,
);

Map<String, dynamic> _$PostToJson(Post instance) => <String, dynamic>{
  'href': instance.href,
  'description': instance.description,
  'extended': instance.extended,
  'meta': instance.meta,
  'hash': instance.hash,
  'time': instance.time.toIso8601String(),
  'shared': Post._boolToString(instance.shared),
  'toread': Post._boolToString(instance.toread),
  'tags': instance.tags,
};
