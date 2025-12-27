// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitHubFile _$GitHubFileFromJson(Map<String, dynamic> json) => GitHubFile(
  path: json['path'] as String,
  sha: json['sha'] as String,
  size: (json['size'] as num).toInt(),
  type: json['type'] as String,
  content: json['content'] as String?,
);

Map<String, dynamic> _$GitHubFileToJson(GitHubFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'sha': instance.sha,
      'size': instance.size,
      'type': instance.type,
      'content': instance.content,
    };
