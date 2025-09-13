import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'add_post_response.g.dart';

@JsonSerializable()
class AddPostResponse extends Equatable {
  @JsonKey(name: 'result_code')
  final String resultCode;

  const AddPostResponse({required this.resultCode});

  factory AddPostResponse.fromJson(Map<String, dynamic> json) =>
      _$AddPostResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AddPostResponseToJson(this);

  bool get wasSuccessful => resultCode == 'done';

  @override
  List<Object?> get props => [resultCode];

  @override
  bool get stringify => true;
}
