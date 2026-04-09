import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bucket.dart';
import '../models/user.dart';
import '../models/vocabulary_word.dart';

/// Base URL for all API calls. Change this to your server address.
const String kBaseUrl = 'https://weilunliu.com';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class SyncResult {
  const SyncResult({
    required this.syncedAt,
    required this.count,
    required this.words,
  });
  final DateTime syncedAt;
  final int count;
  final List<VocabularyWord> words;
}

class MarketBucketWords {
  const MarketBucketWords({
    required this.bucket,
    required this.count,
    required this.words,
  });
  final Bucket bucket;
  final int count;
  final List<VocabularyWord> words;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(kBaseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: '/api$path',
      queryParameters: query,
    );
  }

  void _assertSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['message'] as String? ??
          body['error'] as String? ??
          response.reasonPhrase ??
          'Unknown error';
    } catch (_) {
      message = response.reasonPhrase ?? 'Unknown error';
    }
    throw ApiException(response.statusCode, message);
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// POST /api/auth/register
  Future<({User user, String token})> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post(
      _uri('/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    _assertSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  }

  /// POST /api/auth/login
  Future<({User user, String token})> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _assertSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  }

  /// POST /api/auth/logout
  Future<void> logout({required String token}) async {
    final response = await _client.post(
      _uri('/auth/logout'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
  }

  /// GET /api/auth/me
  Future<User> getMe({required String token}) async {
    final response = await _client.get(
      _uri('/auth/me'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Vocabulary
  // ---------------------------------------------------------------------------

  /// GET /api/mobile/vocabulary/sync
  /// Pass [since] for incremental sync (returns abandoned words too for deletion).
  Future<SyncResult> syncVocabulary({
    required String token,
    DateTime? since,
  }) async {
    final query = since != null
        ? {'since': since.toUtc().toIso8601String()}
        : null;
    final response = await _client.get(
      _uri('/mobile/vocabulary/sync', query),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return SyncResult(
      syncedAt: DateTime.parse(json['synced_at'] as String),
      count: json['count'] as int,
      words: (json['words'] as List<dynamic>)
          .map((e) => VocabularyWord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// POST /api/mobile/vocabulary
  Future<VocabularyWord> addVocabulary({
    required String token,
    required String word,
    required String meaning,
    String? sourceType,
    String? source,
  }) async {
    final body = <String, dynamic>{'word': word, 'meaning': meaning};
    if (sourceType != null) body['source_type'] = sourceType;
    if (source != null) body['source'] = source;
    final response = await _client.post(
      _uri('/mobile/vocabulary'),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    _assertSuccess(response);
    return VocabularyWord.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// POST /api/mobile/vocabulary/{id}/remember
  Future<void> rememberWord({required String token, required int id}) async {
    final response = await _client.post(
      _uri('/mobile/vocabulary/$id/remember'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
  }

  /// POST /api/mobile/vocabulary/{id}/abandon
  Future<void> abandonWord({required String token, required int id}) async {
    final response = await _client.post(
      _uri('/mobile/vocabulary/$id/abandon'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
  }

  // ---------------------------------------------------------------------------
  // Buckets
  // ---------------------------------------------------------------------------

  /// GET /api/mobile/buckets
  Future<List<Bucket>> listBuckets({required String token}) async {
    final response = await _client.get(
      _uri('/mobile/buckets'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Bucket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /api/mobile/buckets/{bucket}
  Future<Bucket> updateBucket({
    required String token,
    required int bucketId,
    required bool isPublic,
  }) async {
    final response = await _client.patch(
      _uri('/mobile/buckets/$bucketId'),
      headers: _headers(token: token),
      body: jsonEncode({'is_public': isPublic}),
    );
    _assertSuccess(response);
    return Bucket.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// DELETE /api/mobile/buckets/{bucket}
  Future<void> deleteBucket({
    required String token,
    required int bucketId,
  }) async {
    final response = await _client.delete(
      _uri('/mobile/buckets/$bucketId'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
  }

  // ---------------------------------------------------------------------------
  // Market
  // ---------------------------------------------------------------------------

  /// GET /api/mobile/market
  Future<List<Bucket>> browseMarket({required String token}) async {
    final response = await _client.get(
      _uri('/mobile/market'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Bucket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/mobile/market/{bucket}/words
  Future<MarketBucketWords> getMarketBucketWords({
    required String token,
    required int bucketId,
  }) async {
    final response = await _client.get(
      _uri('/mobile/market/$bucketId/words'),
      headers: _headers(token: token),
    );
    _assertSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return MarketBucketWords(
      bucket: Bucket.fromJson(json['bucket'] as Map<String, dynamic>),
      count: json['count'] as int,
      words: (json['words'] as List<dynamic>)
          .map((e) => VocabularyWord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
