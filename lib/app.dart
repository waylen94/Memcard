import 'package:flutter/material.dart';

import 'data/card_provider.dart';
import 'ui/cards_tab.dart';
import 'ui/study_tab.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memcard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Memcard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cards'),
              Tab(text: 'Study'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [CardsTab(), StudyTab()],
        ),
      ),
    );
  }
}
