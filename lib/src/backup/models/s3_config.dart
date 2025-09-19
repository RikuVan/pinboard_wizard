import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 's3_config.g.dart';

@JsonSerializable()
class S3Config extends Equatable {
  const S3Config({
    this.accessKey = '',
    this.secretKey = '',
    this.region = '',
    this.bucketName = '',
    this.filePath = '',
  });

  final String accessKey;
  final String secretKey;
  final String region;
  final String bucketName;
  final String filePath;

  bool get isValid =>
      accessKey.isNotEmpty &&
      secretKey.isNotEmpty &&
      region.isNotEmpty &&
      bucketName.isNotEmpty;

  bool get isEmpty =>
      accessKey.isEmpty &&
      secretKey.isEmpty &&
      region.isEmpty &&
      bucketName.isEmpty &&
      filePath.isEmpty;

  S3Config copyWith({
    String? accessKey,
    String? secretKey,
    String? region,
    String? bucketName,
    String? filePath,
  }) {
    return S3Config(
      accessKey: accessKey ?? this.accessKey,
      secretKey: secretKey ?? this.secretKey,
      region: region ?? this.region,
      bucketName: bucketName ?? this.bucketName,
      filePath: filePath ?? this.filePath,
    );
  }

  Map<String, dynamic> toJson() => _$S3ConfigToJson(this);

  factory S3Config.fromJson(Map<String, dynamic> json) =>
      _$S3ConfigFromJson(json);

  @override
  List<Object?> get props => [
    accessKey,
    secretKey,
    region,
    bucketName,
    filePath,
  ];
}
