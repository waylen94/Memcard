import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:memcard/data/card_store.dart';
import 'package:memcard/models/flashcard.dart';

void main() {
  const boxName = 'flashcards';
  late Box<Flashcard> box;
  late CardStore store;

  setUpAll(() {
    Hive.registerAdapter(FlashcardAdapter());
  });

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('memcard_test_');
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    box = await Hive.openBox<Flashcard>(boxName);
    store = CardStore(box);
    addTearDown(store.dispose);
  });

  test('adds, edits, persists, and deletes a local flashcard', () async {
    await store.addCard(front: 'Bonjour', back: 'Hello');
    final card = store.cards.single;
    expect(store.dueCards(now: card.createdAt).single.id, card.id);
    expect(card.lastReviewedAt, isNull);

    await store.updateCard(card.id, front: 'Bonsoir', back: 'Good evening');
    await box.close();
    final reopenedBox = await Hive.openBox<Flashcard>(boxName);
    final reopenedStore = CardStore(reopenedBox);
    addTearDown(reopenedStore.dispose);

    final persisted = reopenedStore.cards.single;
    expect(persisted.id, card.id);
    expect(persisted.front, 'Bonsoir');
    expect(persisted.back, 'Good evening');
    expect(persisted.lastReviewedAt, isNull);

    await reopenedStore.deleteCard(persisted.id);
    expect(reopenedStore.cards, isEmpty);
  });

  test('due cards include the cutoff and are ordered by due time', () async {
    final cutoff = DateTime(2026, 1, 1);
    final dates = {
      'at-cutoff': cutoff,
      'future': cutoff.add(const Duration(minutes: 1)),
      'overdue': cutoff.subtract(const Duration(minutes: 1)),
    };
    for (final entry in dates.entries) {
      await box.put(
        entry.key,
        Flashcard(
          id: entry.key,
          front: 'Question',
          back: 'Answer',
          createdAt: cutoff,
          dueAt: entry.value,
          intervalDays: 0.5,
        ),
      );
    }

    expect(store.dueCards(now: cutoff).map((card) => card.id), [
      'overdue',
      'at-cutoff',
    ]);
  });

  test('remembered and forgotten reviews reschedule the card', () async {
    await store.addCard(front: 'Bonjour', back: 'Hello');
    final card = store.cards.single;

    await store.recordReview(card, remembered: true);
    expect(card.intervalDays, closeTo(0.9, 0.000001));
    expect(
      card.dueAt.difference(card.lastReviewedAt!),
      const Duration(hours: 21, minutes: 36),
    );
    expect(store.dueCards(now: card.lastReviewedAt), isEmpty);

    await store.recordReview(card, remembered: false);
    expect(card.intervalDays, 0.1);
    expect(
      card.dueAt.difference(card.lastReviewedAt!),
      const Duration(hours: 2, minutes: 24),
    );
    expect(store.dueCards(now: card.dueAt).single.id, card.id);
  });
}
