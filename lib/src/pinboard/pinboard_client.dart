import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/models/posts_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/api_token_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/post_dates_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/add_post_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/tags_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/user_secret_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/suggest_response.dart';
import 'package:pinboard_wizard/src/pinboard/models/update_response.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

class PinboardException implements Exception {
  final String message;
  final int? statusCode;
  final String? response;

  const PinboardException(this.message, {this.statusCode, this.response});

  @override
  String toString() => 'PinboardException: $message';
}

class PinboardAuthException extends PinboardException {
  const PinboardAuthException(String message, {int? statusCode, String? response})
    : super(message, statusCode: statusCode, response: response);
}

class PinboardClient {
  static const String _baseUrl = 'https://api.pinboard.in/v1';

  final SecretStorage _secretStorage;
  final http.Client _httpClient;

  PinboardClient({required SecretStorage secretStorage, http.Client? httpClient})
    : _secretStorage = secretStorage,
      _httpClient = httpClient ?? http.Client();
  Future<Credentials?> _getCredentials() async {
    try {
      return await _secretStorage.read();
    } catch (e) {
      throw PinboardAuthException('Failed to retrieve credentials: $e');
    }
  }

  Uri _buildUrl(String endpoint) {
    return Uri.parse('$_baseUrl/$endpoint');
  }

  Map<String, String> _addRequiredParams(String authToken, [Map<String, String>? params]) {
    final allParams = <String, String>{'auth_token': authToken, 'format': 'json'};

    if (params != null) {
      allParams.addAll(params);
    }

    return allParams;
  }

  Future<dynamic> _get(String endpoint, [Map<String, String>? params]) async {
    final credentials = await _getCredentials();
    if (credentials == null) {
      throw PinboardAuthException('No credentials found. Please authenticate first.');
    }

    final requiredParams = _addRequiredParams(credentials.apiKey, params);
    final uri = _buildUrl(endpoint).replace(queryParameters: requiredParams);

    try {
      final response = await _httpClient.get(uri);
      return _handleResponse(response);
    } catch (e) {
      if (e is PinboardException) rethrow;
      throw PinboardException('Request failed: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw PinboardAuthException(
        'Authentication failed. Please check your API token.',
        statusCode: response.statusCode,
        response: response.body,
      );
    }

    if (response.statusCode == 429) {
      throw PinboardException(
        'Rate limit exceeded. Please try again later.',
        statusCode: response.statusCode,
        response: response.body,
      );
    }

    if (response.statusCode != 200) {
      throw PinboardException(
        'API request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        response: response.body,
      );
    }

    try {
      return json.decode(response.body);
    } catch (e) {
      throw PinboardException('Failed to parse response as JSON: $e');
    }
  }

  Future<bool> testAuthentication() async {
    try {
      await _get('user/api_token');
      return true;
    } on PinboardAuthException {
      return false;
    } catch (e) {
      // Other errors might indicate network issues, not auth issues
      rethrow;
    }
  }

  Future<ApiTokenResponse> getUserApiToken() async {
    final response = await _get('user/api_token');
    return ApiTokenResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<PostsResponse> getPosts({
    String? tag,
    int? start,
    int? results,
    DateTime? fromdt,
    DateTime? todt,
    int? meta,
  }) async {
    final params = <String, String>{};

    if (tag != null) params['tag'] = tag;
    if (start != null) params['start'] = start.toString();
    if (results != null) params['results'] = results.toString();
    if (fromdt != null) params['fromdt'] = fromdt.toIso8601String();
    if (todt != null) params['todt'] = todt.toIso8601String();
    if (meta != null) params['meta'] = meta.toString();

    final response = await _get('posts/all', params);

    // Handle different response formats - posts/all returns array directly
    if (response is List) {
      final posts = (response as List<dynamic>)
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
      return PostsResponse(
        date: DateTime.now(),
        user: '', // Not provided by posts/all
        posts: posts,
      );
    }

    return PostsResponse.fromJson(response);
  }

  Future<PostsResponse> getRecentPosts({String? tag, int? count}) async {
    final params = <String, String>{};

    if (tag != null) params['tag'] = tag;
    if (count != null) params['count'] = count.toString();

    final response = await _get('posts/recent', params);
    return PostsResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<PostDatesResponse> getPostDates({String? tag}) async {
    final params = <String, String>{};
    if (tag != null) params['tag'] = tag;

    final response = await _get('posts/dates', params);
    return PostDatesResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<PostsResponse> getPost({String? tag, DateTime? dt, String? url, String? meta}) async {
    final params = <String, String>{};

    if (tag != null) params['tag'] = tag;
    if (dt != null) params['dt'] = dt.toIso8601String().split('T')[0];
    if (url != null) params['url'] = url;
    if (meta != null) params['meta'] = meta;

    final response = await _get('posts/get', params);
    return PostsResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AddPostResponse> addPost({
    required String url,
    required String description,
    String? extended,
    String? tags,
    DateTime? dt,
    bool? replace,
    bool? shared,
    bool? toread,
  }) async {
    final params = <String, String>{'url': url, 'description': description};

    if (extended != null) params['extended'] = extended;
    if (tags != null) params['tags'] = tags;
    if (dt != null) params['dt'] = dt.toIso8601String();
    if (replace != null) params['replace'] = replace ? 'yes' : 'no';
    if (shared != null) params['shared'] = shared ? 'yes' : 'no';
    if (toread != null) params['toread'] = toread ? 'yes' : 'no';

    final response = await _get('posts/add', params);
    return AddPostResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AddPostResponse> deletePost(String url) async {
    final response = await _get('posts/delete', {'url': url});
    return AddPostResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<TagsResponse> getTags() async {
    final response = await _get('tags/get');
    return TagsResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AddPostResponse> deleteTag(String tag) async {
    final response = await _get('tags/delete', {'tag': tag});
    return AddPostResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AddPostResponse> renameTag({required String oldTag, required String newTag}) async {
    final response = await _get('tags/rename', {'old': oldTag, 'new': newTag});
    return AddPostResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<UserSecretResponse> getUserSecret() async {
    final response = await _get('user/secret');
    return UserSecretResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<SuggestResponse> getSuggestedTags(String url) async {
    final response = await _get('posts/suggest', {'url': url});
    return SuggestResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getNotes() async {
    final response = await _get('notes/list');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNote(String noteId) async {
    final response = await _get('notes/$noteId');
    return response;
  }

  Future<UpdateResponse> getLastUpdate() async {
    final response = await _get('posts/update');
    return UpdateResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<bool> isAuthenticated() async {
    try {
      final credentials = await _getCredentials();
      if (credentials == null) return false;
      return await testAuthentication();
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
