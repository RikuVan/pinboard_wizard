import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'credentials.g.dart';

@JsonSerializable(explicitToJson: true)
class Credentials extends Equatable {
  final String apiKey;

  const Credentials({required this.apiKey});

  factory Credentials.fromJson(Map<String, dynamic> json) =>
      _$CredentialsFromJson(json);
  Map<String, dynamic> toJson() => _$CredentialsToJson(this);

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [apiKey];
}
