import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/card_provider.dart';
import 'data/card_store.dart';
import 'models/flashcard.dart';

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

  runApp(CardProvider(store: store, child: const MainApp()));
}
