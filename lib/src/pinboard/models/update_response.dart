import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'update_response.g.dart';

@JsonSerializable()
class UpdateResponse extends Equatable {
  @JsonKey(name: 'update_time')
  final DateTime updateTime;

  const UpdateResponse({required this.updateTime});

  factory UpdateResponse.fromJson(Map<String, dynamic> json) =>
      _$UpdateResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateResponseToJson(this);

  @override
  List<Object?> get props => [updateTime];

  @override
  bool get stringify => true;
}
