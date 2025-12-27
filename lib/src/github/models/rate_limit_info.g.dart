// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rate_limit_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RateLimitInfo _$RateLimitInfoFromJson(Map<String, dynamic> json) =>
    RateLimitInfo(
      limit: (json['limit'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      resetAt: RateLimitInfo._dateTimeFromJson(
        (json['resetAt'] as num).toInt(),
      ),
    );

Map<String, dynamic> _$RateLimitInfoToJson(RateLimitInfo instance) =>
    <String, dynamic>{
      'limit': instance.limit,
      'remaining': instance.remaining,
      'resetAt': RateLimitInfo._dateTimeToJson(instance.resetAt),
    };
