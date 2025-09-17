// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotesListResponse _$NotesListResponseFromJson(Map<String, dynamic> json) =>
    NotesListResponse(
      count: (json['count'] as num).toInt(),
      notes: (json['notes'] as List<dynamic>)
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$NotesListResponseToJson(NotesListResponse instance) =>
    <String, dynamic>{
      'count': instance.count,
      'notes': instance.notes.map((e) => e.toJson()).toList(),
    };

NoteDetailResponse _$NoteDetailResponseFromJson(Map<String, dynamic> json) =>
    NoteDetailResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      hash: json['hash'] as String,
      length: (json['length'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      text: json['text'] as String,
    );

Map<String, dynamic> _$NoteDetailResponseToJson(NoteDetailResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'hash': instance.hash,
      'length': instance.length,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'text': instance.text,
    };
