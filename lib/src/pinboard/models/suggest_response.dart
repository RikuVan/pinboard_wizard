import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'suggest_response.g.dart';

@JsonSerializable()
class SuggestResponse extends Equatable {
  final List<String> popular;
  final List<String> recommended;

  const SuggestResponse({required this.popular, required this.recommended});

  factory SuggestResponse.fromJson(Map<String, dynamic> json) =>
      _$SuggestResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SuggestResponseToJson(this);

  List<String> get allSuggestions {
    final all = <String>[...popular, ...recommended];
    return all.toSet().toList();
  }

  @override
  List<Object?> get props => [popular, recommended];

  @override
  bool get stringify => true;
}
