import 'package:hive/hive.dart';

class Flashcard extends HiveObject {
  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.createdAt,
    required this.dueAt,
    required this.intervalDays,
    this.lastReviewedAt,
  });

  String id;
  String front;
  String back;
  DateTime createdAt;
  DateTime dueAt;
  double intervalDays;
  DateTime? lastReviewedAt;
}

class FlashcardAdapter extends TypeAdapter<Flashcard> {
  @override
  final int typeId = 0;

  @override
  Flashcard read(BinaryReader reader) {
    final id = reader.readString();
    final front = reader.readString();
    final back = reader.readString();
    final createdMs = reader.readInt();
    final dueMs = reader.readInt();
    final interval = reader.readDouble();
    final lastReviewedMs = reader.readInt();
    return Flashcard(
      id: id,
      front: front,
      back: back,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      dueAt: DateTime.fromMillisecondsSinceEpoch(dueMs),
      intervalDays: interval,
      lastReviewedAt: lastReviewedMs == -1 ? null : DateTime.fromMillisecondsSinceEpoch(lastReviewedMs),
    );
  }

  @override
  void write(BinaryWriter writer, Flashcard obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.front)
      ..writeString(obj.back)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.dueAt.millisecondsSinceEpoch)
      ..writeDouble(obj.intervalDays)
      ..writeInt(obj.lastReviewedAt?.millisecondsSinceEpoch ?? -1);
  }
}
