// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiSettings _$AiSettingsFromJson(Map<String, dynamic> json) => AiSettings(
  isEnabled: json['isEnabled'] as bool? ?? false,
  openai: json['openai'] == null
      ? const OpenAiSettings()
      : OpenAiSettings.fromJson(json['openai'] as Map<String, dynamic>),
  webScraping: json['webScraping'] == null
      ? const WebScrapingSettings()
      : WebScrapingSettings.fromJson(
          json['webScraping'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$AiSettingsToJson(AiSettings instance) =>
    <String, dynamic>{
      'isEnabled': instance.isEnabled,
      'openai': instance.openai,
      'webScraping': instance.webScraping,
    };

OpenAiSettings _$OpenAiSettingsFromJson(Map<String, dynamic> json) =>
    OpenAiSettings(
      apiKey: json['apiKey'] as String?,
      descriptionMaxLength:
          (json['descriptionMaxLength'] as num?)?.toInt() ?? 80,
      maxTags: (json['maxTags'] as num?)?.toInt() ?? 3,
    );

Map<String, dynamic> _$OpenAiSettingsToJson(OpenAiSettings instance) =>
    <String, dynamic>{
      'apiKey': instance.apiKey,
      'descriptionMaxLength': instance.descriptionMaxLength,
      'maxTags': instance.maxTags,
    };

WebScrapingSettings _$WebScrapingSettingsFromJson(Map<String, dynamic> json) =>
    WebScrapingSettings(jinaApiKey: json['jinaApiKey'] as String?);

Map<String, dynamic> _$WebScrapingSettingsToJson(
  WebScrapingSettings instance,
) => <String, dynamic>{'jinaApiKey': instance.jinaApiKey};
