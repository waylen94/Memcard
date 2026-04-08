class VocabularyWord {
  const VocabularyWord({
    required this.id,
    required this.bucketId,
    required this.word,
    required this.meaning,
    this.sourceType,
    this.source,
    this.nextReviewAt,
    required this.abandoned,
    required this.updatedAt,
  });

  final int id;
  final int? bucketId;
  final String word;
  final String meaning;
  final String? sourceType;
  final String? source;
  final DateTime? nextReviewAt;
  final bool abandoned;
  final DateTime updatedAt;

  factory VocabularyWord.fromJson(Map<String, dynamic> json) => VocabularyWord(
        id: json['id'] as int,
        bucketId: json['bucket_id'] as int?,
        word: json['word'] as String,
        meaning: json['meaning'] as String,
        sourceType: json['source_type'] as String?,
        source: json['source'] as String?,
        nextReviewAt: json['next_review_at'] != null
            ? DateTime.parse(json['next_review_at'] as String)
            : null,
        abandoned: json['abandoned'] == true || json['abandoned'] == 1,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bucket_id': bucketId,
        'word': word,
        'meaning': meaning,
        'source_type': sourceType,
        'source': source,
        'next_review_at': nextReviewAt?.toIso8601String(),
        'abandoned': abandoned,
        'updated_at': updatedAt.toIso8601String(),
      };
}
