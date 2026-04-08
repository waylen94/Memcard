import 'package:flutter/material.dart';

import 'data/auth_provider.dart';
import 'services/api_service.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/register_screen.dart';
import 'ui/buckets_tab.dart';
import 'ui/cards_tab.dart';
import 'ui/market_tab.dart';
import 'ui/study_tab.dart';
import 'ui/vocab_tab.dart';

class MainApp extends StatelessWidget {
  const MainApp(
      {super.key, required this.authProvider, required this.apiService});

  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memcard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: authProvider,
        builder: (context, _) {
          switch (authProvider.status) {
            case AuthStatus.unknown:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case AuthStatus.unauthenticated:
              return _AuthGate(authProvider: authProvider);
            case AuthStatus.authenticated:
              return HomePage(
                  authProvider: authProvider, apiService: apiService);
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth gate — toggles between Login and Register
// ---------------------------------------------------------------------------

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.authProvider});
  final AuthProvider authProvider;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return LoginScreen(
        authProvider: widget.authProvider,
        onGoToRegister: () => setState(() => _showLogin = false),
      );
    }
    return RegisterScreen(
      authProvider: widget.authProvider,
      onGoToLogin: () => setState(() => _showLogin = true),
    );
  }
}

// ---------------------------------------------------------------------------
// Main home (authenticated)
// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage(
      {super.key, required this.authProvider, required this.apiService});
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Memcard'),
          actions: [
            PopupMenuButton<_AppMenuAction>(
              onSelected: (action) {
                if (action == _AppMenuAction.logout) authProvider.logout();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _AppMenuAction.logout,
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.style_outlined), text: 'Cards'),
              Tab(icon: Icon(Icons.school_outlined), text: 'Study'),
              Tab(icon: Icon(Icons.translate_outlined), text: 'Vocabulary'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Buckets'),
              Tab(icon: Icon(Icons.store_outlined), text: 'Market'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const CardsTab(),
            const StudyTab(),
            VocabTab(authProvider: authProvider, apiService: apiService),
            BucketsTab(authProvider: authProvider, apiService: apiService),
            MarketTab(authProvider: authProvider, apiService: apiService),
          ],
        ),
      ),
    );
  }
}

enum _AppMenuAction { logout }
