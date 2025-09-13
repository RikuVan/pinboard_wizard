import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'user_secret_response.g.dart';

@JsonSerializable()
class UserSecretResponse extends Equatable {
  @JsonKey(name: 'result')
  final String result;

  const UserSecretResponse({required this.result});

  factory UserSecretResponse.fromJson(Map<String, dynamic> json) =>
      _$UserSecretResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UserSecretResponseToJson(this);

  String get secret => result;

  @override
  List<Object?> get props => [result];

  @override
  bool get stringify => true;
}
