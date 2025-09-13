import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'post.dart';

part 'posts_response.g.dart';

@JsonSerializable()
class PostsResponse extends Equatable {
  final DateTime date;
  final String user;
  final List<Post> posts;

  const PostsResponse({
    required this.date,
    required this.user,
    required this.posts,
  });

  factory PostsResponse.fromJson(Map<String, dynamic> json) =>
      _$PostsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PostsResponseToJson(this);

  @override
  List<Object?> get props => [date, user, posts];

  @override
  bool get stringify => true;
}
