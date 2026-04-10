import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/auth_provider.dart';
import 'data/card_provider.dart';
import 'data/card_store.dart';
import 'data/vocab_store.dart';
import 'models/flashcard.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final docsDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(docsDir.path);
  }

  Hive.registerAdapter(FlashcardAdapter());
  final box = await Hive.openBox<Flashcard>('flashcards');
  final store = CardStore(box);

  final vocabBox = await Hive.openBox<String>('vocabulary');
  final prefs = await SharedPreferences.getInstance();
  final vocabStore = VocabStore(vocabBox, prefs);

  final apiService = ApiService();
  final authProvider = AuthProvider(apiService: apiService);
  await authProvider.tryRestoreSession();

  runApp(
    CardProvider(
      store: store,
      child: MainApp(
        authProvider: authProvider,
        apiService: apiService,
        vocabStore: vocabStore,
      ),
    ),
  );
}
