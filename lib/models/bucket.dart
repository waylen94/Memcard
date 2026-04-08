import 'user.dart';

class Bucket {
  const Bucket({
    required this.id,
    required this.userId,
    required this.sourceType,
    required this.source,
    required this.isPublic,
    required this.vocabulariesCount,
    this.updatedAt,
    this.owner,
  });

  final int id;
  final int userId;
  final String sourceType;
  final String source;
  final bool isPublic;
  final int vocabulariesCount;
  final DateTime? updatedAt;

  /// Populated only in market listings.
  final User? owner;

  factory Bucket.fromJson(Map<String, dynamic> json) => Bucket(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        sourceType: json['source_type'] as String,
        source: json['source'] as String,
        isPublic: json['is_public'] == true || json['is_public'] == 1,
        vocabulariesCount: json['vocabularies_count'] as int? ?? 0,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
        owner: json['user'] != null
            ? User.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );

  Bucket copyWith({bool? isPublic}) => Bucket(
        id: id,
        userId: userId,
        sourceType: sourceType,
        source: source,
        isPublic: isPublic ?? this.isPublic,
        vocabulariesCount: vocabulariesCount,
        updatedAt: updatedAt,
        owner: owner,
      );
}
