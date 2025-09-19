import 'package:equatable/equatable.dart';

class ScrapedContent extends Equatable {
  final String url;
  final String? title;
  final String? content;
  final String? description;
  final List<String> images;
  final Map<String, String> metadata;
  final DateTime scrapedAt;
  final ScrapingSource source;

  const ScrapedContent({
    required this.url,
    this.title,
    this.content,
    this.description,
    required this.images,
    required this.metadata,
    required this.scrapedAt,
    required this.source,
  });

  ScrapedContent copyWith({
    String? url,
    String? title,
    String? content,
    String? description,
    List<String>? images,
    Map<String, String>? metadata,
    DateTime? scrapedAt,
    ScrapingSource? source,
  }) {
    return ScrapedContent(
      url: url ?? this.url,
      title: title ?? this.title,
      content: content ?? this.content,
      description: description ?? this.description,
      images: images ?? this.images,
      metadata: metadata ?? this.metadata,
      scrapedAt: scrapedAt ?? this.scrapedAt,
      source: source ?? this.source,
    );
  }

  bool get hasTitle => title?.isNotEmpty == true;
  bool get hasContent => content?.isNotEmpty == true;
  bool get hasDescription => description?.isNotEmpty == true;
  bool get hasImages => images.isNotEmpty;

  String get cleanContent {
    if (content == null) return '';
    // Remove excessive whitespace and newlines
    return content!.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String get previewContent {
    final clean = cleanContent;
    return clean.length > 500 ? '${clean.substring(0, 500)}...' : clean;
  }

  @override
  List<Object?> get props => [
    url,
    title,
    content,
    description,
    images,
    metadata,
    scrapedAt,
    source,
  ];

  @override
  bool get stringify => true;
}

class JinaResponse extends Equatable {
  final int code;
  final int status;
  final JinaData data;

  const JinaResponse({
    required this.code,
    required this.status,
    required this.data,
  });

  factory JinaResponse.fromJson(Map<String, dynamic> json) {
    return JinaResponse(
      code: json['code'] as int? ?? 200,
      status: json['status'] as int? ?? 200,
      data: JinaData.fromJson(json['data'] as Map<String, dynamic>? ?? json),
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'status': status, 'data': data.toJson()};
  }

  ScrapedContent toScrapedContent(String url) {
    return ScrapedContent(
      url: url,
      title: data.title,
      content: data.content,
      description: data.description,
      images: data.images ?? [],
      metadata: {
        if (data.publishedTime != null) 'publishedTime': data.publishedTime!,
        if (data.author != null) 'author': data.author!,
        if (data.siteName != null) 'siteName': data.siteName!,
        if (data.lang != null) 'lang': data.lang!,
      },
      scrapedAt: DateTime.now(),
      source: ScrapingSource.jina,
    );
  }

  @override
  List<Object?> get props => [code, status, data];

  @override
  bool get stringify => true;
}

class JinaData extends Equatable {
  final String? title;
  final String? content;
  final String? description;
  final String? publishedTime;
  final String? author;
  final String? siteName;
  final String? lang;
  final List<String>? images;

  const JinaData({
    this.title,
    this.content,
    this.description,
    this.publishedTime,
    this.author,
    this.siteName,
    this.lang,
    this.images,
  });

  factory JinaData.fromJson(Map<String, dynamic> json) {
    return JinaData(
      title: json['title'] as String?,
      content: json['content'] as String?,
      description: json['description'] as String?,
      publishedTime:
          json['publishedTime'] as String? ?? json['published_time'] as String?,
      author: json['author'] as String?,
      siteName: json['siteName'] as String? ?? json['site_name'] as String?,
      lang: json['lang'] as String?,
      images: (json['images'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'description': description,
      'publishedTime': publishedTime,
      'author': author,
      'siteName': siteName,
      'lang': lang,
      'images': images,
    };
  }

  @override
  List<Object?> get props => [
    title,
    content,
    description,
    publishedTime,
    author,
    siteName,
    lang,
    images,
  ];

  @override
  bool get stringify => true;
}

enum ScrapingSource { jina, fallback, manual }
