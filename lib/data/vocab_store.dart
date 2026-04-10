import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vocabulary_word.dart';

/// Persists vocabulary words in a local Hive box so the app can display them
/// instantly on startup without hitting the network.
///
/// [lastSyncedAt] is stored in SharedPreferences and is passed as `since` to
/// the API for incremental syncs — making it easy to later add a once-per-day
/// gate: just check [lastSyncedAt] before calling the server.
class VocabStore {
  VocabStore(this._box, this._prefs);

  final Box<String> _box;
  final SharedPreferences _prefs;

  static const _lastSyncKey = 'vocab_last_sync';

  /// All locally cached words, sorted alphabetically.
  List<VocabularyWord> get words {
    return _box.values
        .map((s) => VocabularyWord.fromJson(
            jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.word.compareTo(b.word));
  }

  /// Timestamp of the last successful sync, or null if never synced.
  DateTime? get lastSyncedAt {
    final s = _prefs.getString(_lastSyncKey);
    return s != null ? DateTime.parse(s) : null;
  }

  /// Apply a batch received from the server:
  /// - deletes abandoned words from the local cache
  /// - upserts active words
  /// - records the sync timestamp
  Future<void> applySync(
      List<VocabularyWord> incoming, DateTime syncedAt) async {
    final toDelete = incoming
        .where((w) => w.abandoned)
        .map((w) => w.id.toString())
        .toList();
    final toSave = {
      for (final w in incoming.where((w) => !w.abandoned))
        w.id.toString(): jsonEncode(w.toJson()),
    };
    await _box.deleteAll(toDelete);
    await _box.putAll(toSave);
    await _prefs.setString(_lastSyncKey, syncedAt.toIso8601String());
  }

  /// Persist a single newly-added word immediately (no extra network call).
  Future<void> saveWord(VocabularyWord word) async {
    await _box.put(word.id.toString(), jsonEncode(word.toJson()));
  }

  /// Remove a word from the local cache (called after a successful abandon).
  Future<void> removeWord(int id) async {
    await _box.delete(id.toString());
  }
}
