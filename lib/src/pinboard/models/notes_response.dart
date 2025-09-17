import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pinboard_wizard/src/pinboard/models/note.dart';

part 'notes_response.g.dart';

@JsonSerializable(explicitToJson: true)
class NotesListResponse extends Equatable {
  final int count;
  final List<Note> notes;

  const NotesListResponse({required this.count, required this.notes});

  factory NotesListResponse.fromJson(Map<String, dynamic> json) =>
      _$NotesListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$NotesListResponseToJson(this);

  @override
  List<Object?> get props => [count, notes];
}

@JsonSerializable(explicitToJson: true)
class NoteDetailResponse extends Equatable {
  final String id;
  final String title;
  final String hash;
  final int length;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  final String text;

  const NoteDetailResponse({
    required this.id,
    required this.title,
    required this.hash,
    required this.length,
    required this.createdAt,
    required this.updatedAt,
    required this.text,
  });

  factory NoteDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$NoteDetailResponseFromJson(json);
  Map<String, dynamic> toJson() => _$NoteDetailResponseToJson(this);

  @override
  List<Object?> get props => [
    id,
    title,
    hash,
    length,
    createdAt,
    updatedAt,
    text,
  ];
}
