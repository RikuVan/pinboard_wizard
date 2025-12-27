// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github_notes_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitHubNotesConfig _$GitHubNotesConfigFromJson(Map<String, dynamic> json) =>
    GitHubNotesConfig(
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      branch: json['branch'] as String? ?? 'main',
      notesPath: json['notesPath'] as String? ?? 'notes/',
      deviceId: json['deviceId'] as String,
      tokenType:
          $enumDecodeNullable(_$TokenTypeEnumMap, json['tokenType']) ??
          TokenType.fineGrained,
      tokenExpiry: json['tokenExpiry'] == null
          ? null
          : DateTime.parse(json['tokenExpiry'] as String),
      isConfigured: json['isConfigured'] as bool? ?? false,
    );

Map<String, dynamic> _$GitHubNotesConfigToJson(GitHubNotesConfig instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'repo': instance.repo,
      'branch': instance.branch,
      'notesPath': instance.notesPath,
      'deviceId': instance.deviceId,
      'tokenType': _$TokenTypeEnumMap[instance.tokenType]!,
      'tokenExpiry': instance.tokenExpiry?.toIso8601String(),
      'isConfigured': instance.isConfigured,
    };

const _$TokenTypeEnumMap = {
  TokenType.classic: 'classic',
  TokenType.fineGrained: 'fine_grained',
};
