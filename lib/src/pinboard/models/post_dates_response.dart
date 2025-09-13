import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'post_dates_response.g.dart';

@JsonSerializable()
class PostDatesResponse extends Equatable {
  @JsonKey(name: 'dates')
  final Map<String, int> dates;

  const PostDatesResponse({required this.dates});

  factory PostDatesResponse.fromJson(Map<String, dynamic> json) =>
      _$PostDatesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PostDatesResponseToJson(this);

  List<MapEntry<String, int>> get datesByTime {
    final entries = dates.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  List<MapEntry<String, int>> get datesByCount {
    final entries = dates.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  List<Object?> get props => [dates];

  @override
  bool get stringify => true;
}
