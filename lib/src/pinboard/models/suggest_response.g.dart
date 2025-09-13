// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suggest_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SuggestResponse _$SuggestResponseFromJson(Map<String, dynamic> json) =>
    SuggestResponse(
      popular: (json['popular'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      recommended: (json['recommended'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SuggestResponseToJson(SuggestResponse instance) =>
    <String, dynamic>{
      'popular': instance.popular,
      'recommended': instance.recommended,
    };
