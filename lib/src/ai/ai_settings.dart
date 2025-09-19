import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'ai_settings.g.dart';

@JsonSerializable()
class AiSettings extends Equatable {
  final bool isEnabled;
  final OpenAiSettings openai;
  final WebScrapingSettings webScraping;

  const AiSettings({
    this.isEnabled = false,
    this.openai = const OpenAiSettings(),
    this.webScraping = const WebScrapingSettings(),
  });

  factory AiSettings.fromJson(Map<String, dynamic> json) =>
      _$AiSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AiSettingsToJson(this);

  AiSettings copyWith({
    bool? isEnabled,
    OpenAiSettings? openai,
    WebScrapingSettings? webScraping,
  }) {
    return AiSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      openai: openai ?? this.openai,
      webScraping: webScraping ?? this.webScraping,
    );
  }

  bool get canUseAi => isEnabled && openai.hasApiKey;

  @override
  List<Object?> get props => [isEnabled, openai, webScraping];

  @override
  bool get stringify => true;
}

@JsonSerializable()
class OpenAiSettings extends Equatable {
  final String? apiKey;
  final int descriptionMaxLength;
  final int maxTags;

  const OpenAiSettings({
    this.apiKey,
    this.descriptionMaxLength = 80,
    this.maxTags = 3,
  });

  factory OpenAiSettings.fromJson(Map<String, dynamic> json) =>
      _$OpenAiSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$OpenAiSettingsToJson(this);

  OpenAiSettings copyWith({
    String? apiKey,
    int? descriptionMaxLength,
    int? maxTags,
  }) {
    return OpenAiSettings(
      apiKey: apiKey ?? this.apiKey,
      descriptionMaxLength: descriptionMaxLength ?? this.descriptionMaxLength,
      maxTags: maxTags ?? this.maxTags,
    );
  }

  bool get hasApiKey => apiKey?.isNotEmpty == true;

  @override
  List<Object?> get props => [apiKey, descriptionMaxLength, maxTags];

  @override
  bool get stringify => true;
}

@JsonSerializable()
class WebScrapingSettings extends Equatable {
  final String? jinaApiKey;

  const WebScrapingSettings({this.jinaApiKey});

  factory WebScrapingSettings.fromJson(Map<String, dynamic> json) =>
      _$WebScrapingSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$WebScrapingSettingsToJson(this);

  WebScrapingSettings copyWith({String? jinaApiKey}) {
    return WebScrapingSettings(jinaApiKey: jinaApiKey ?? this.jinaApiKey);
  }

  bool get hasJinaKey => jinaApiKey?.isNotEmpty == true;

  @override
  List<Object?> get props => [jinaApiKey];

  @override
  bool get stringify => true;
}
