import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'tags_response.g.dart';

@JsonSerializable()
class TagsResponse extends Equatable {
  final Map<String, int> tags;

  const TagsResponse({required this.tags});

  factory TagsResponse.fromJson(Map<String, dynamic> json) =>
      _$TagsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TagsResponseToJson(this);

  List<String> get tagNames => tags.keys.toList();

  List<MapEntry<String, int>> get tagsByCount {
    final entries = tags.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<MapEntry<String, int>> get tagsByName {
    final entries = tags.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  int get totalTags => tags.length;

  int get totalBookmarks => tags.values.fold(0, (sum, count) => sum + count);

  @override
  List<Object?> get props => [tags];

  @override
  bool get stringify => true;
}
