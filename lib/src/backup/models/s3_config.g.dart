// GENERATED CODE - DO NOT MODIFY BY HAND

part of 's3_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

S3Config _$S3ConfigFromJson(Map<String, dynamic> json) => S3Config(
  accessKey: json['accessKey'] as String? ?? '',
  secretKey: json['secretKey'] as String? ?? '',
  region: json['region'] as String? ?? '',
  bucketName: json['bucketName'] as String? ?? '',
  filePath: json['filePath'] as String? ?? '',
);

Map<String, dynamic> _$S3ConfigToJson(S3Config instance) => <String, dynamic>{
  'accessKey': instance.accessKey,
  'secretKey': instance.secretKey,
  'region': instance.region,
  'bucketName': instance.bucketName,
  'filePath': instance.filePath,
};
