import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'api_token_response.g.dart';

@JsonSerializable()
class ApiTokenResponse extends Equatable {
  @JsonKey(name: 'result')
  final String result;

  const ApiTokenResponse({required this.result});

  factory ApiTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiTokenResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ApiTokenResponseToJson(this);

  String get apiToken => result;

  @override
  List<Object?> get props => [result];

  @override
  bool get stringify => true;
}
