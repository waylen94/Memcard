import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/flashcard.dart';

class CardStore extends ChangeNotifier {
  CardStore(this._box);
  final Box<Flashcard> _box;

  List<Flashcard> get cards {
    final list = _box.values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<Flashcard> dueCards({DateTime? now}) {
    final nowTs = now ?? DateTime.now();
    final list = cards
        .where((c) => c.dueAt.isBefore(nowTs) || c.dueAt.isAtSameMomentAs(nowTs))
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return list;
  }

  Future<void> addCard({required String front, required String back}) async {
    final now = DateTime.now();
    final card = Flashcard(
      id: now.microsecondsSinceEpoch.toString(),
      front: front,
      back: back,
      createdAt: now,
      dueAt: now,
      intervalDays: 0.5,
    );
    await _box.put(card.id, card);
    notifyListeners();
  }

  Future<void> updateCard(String id, {required String front, required String back}) async {
    final card = _box.get(id);
    if (card == null) return;
    card.front = front;
    card.back = back;
    await card.save();
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  Future<void> recordReview(Flashcard card, {required bool remembered}) async {
    final now = DateTime.now();
    final currentInterval = card.intervalDays;
    final nextInterval = remembered ? max(0.7, currentInterval * 1.8) : 0.1;
    card.intervalDays = nextInterval;
    card.dueAt = now.add(Duration(milliseconds: (nextInterval * 24 * 60 * 60 * 1000).round()));
    card.lastReviewedAt = now;
    await card.save();
    notifyListeners();
  }
}
