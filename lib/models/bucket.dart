import 'user.dart';

class Bucket {
  const Bucket({
    required this.id,
    required this.userId,
    required this.sourceType,
    required this.source,
    required this.vocabulariesCount,
    this.updatedAt,
    this.owner,
  });

  final int id;
  final int userId;
  final String sourceType;
  final String source;
  final int vocabulariesCount;
  final DateTime? updatedAt;

  /// Populated when the API includes owner details.
  final User? owner;

  factory Bucket.fromJson(Map<String, dynamic> json) => Bucket(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        sourceType: json['source_type'] as String,
        source: json['source'] as String,
        vocabulariesCount: json['vocabularies_count'] as int? ?? 0,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
        owner: json['user'] != null
            ? User.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );
}
