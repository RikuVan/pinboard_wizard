import 'package:equatable/equatable.dart';

class BookmarkSuggestions extends Equatable {
  final String? title;
  final String? description;
  final List<String> tags;
  final double confidence;
  final DateTime generatedAt;
  final String sourceUrl;

  const BookmarkSuggestions({
    this.title,
    this.description,
    required this.tags,
    required this.confidence,
    required this.generatedAt,
    required this.sourceUrl,
  });

  BookmarkSuggestions copyWith({
    String? title,
    String? description,
    List<String>? tags,
    double? confidence,
    DateTime? generatedAt,
    String? sourceUrl,
  }) {
    return BookmarkSuggestions(
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      confidence: confidence ?? this.confidence,
      generatedAt: generatedAt ?? this.generatedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  bool get hasTitle => title?.isNotEmpty == true;
  bool get hasDescription => description?.isNotEmpty == true;
  bool get hasTags => tags.isNotEmpty;

  @override
  List<Object?> get props => [
    title,
    description,
    tags,
    confidence,
    generatedAt,
    sourceUrl,
  ];

  @override
  bool get stringify => true;
}

class OpenAiResponse extends Equatable {
  final String? title;
  final String? description;
  final List<String> tags;

  const OpenAiResponse({this.title, this.description, required this.tags});

  factory OpenAiResponse.fromJson(Map<String, dynamic> json) {
    return OpenAiResponse(
      title: json['title'] as String?,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'description': description, 'tags': tags};
  }

  BookmarkSuggestions toBookmarkSuggestions(String sourceUrl) {
    return BookmarkSuggestions(
      title: title,
      description: description,
      tags: tags,
      confidence: 0.8, // Default confidence for OpenAI responses
      generatedAt: DateTime.now(),
      sourceUrl: sourceUrl,
    );
  }

  @override
  List<Object?> get props => [title, description, tags];

  @override
  bool get stringify => true;
}
