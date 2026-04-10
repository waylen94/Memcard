import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'data/auth_provider.dart';
import 'data/vocab_store.dart';
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
      {super.key,
      required this.authProvider,
      required this.apiService,
      required this.vocabStore});

  final AuthProvider authProvider;
  final ApiService apiService;
  final VocabStore vocabStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memcard',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: AnimatedBuilder(
        animation: authProvider,
        builder: (context, _) {
          switch (authProvider.status) {
            case AuthStatus.unknown:
              return const _SplashScreen();
            case AuthStatus.unauthenticated:
              return _AuthGate(authProvider: authProvider);
            case AuthStatus.authenticated:
              return HomePage(
                  authProvider: authProvider,
                  apiService: apiService,
                  vocabStore: vocabStore);
          }
        },
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seed = Color(0xFF6C63FF); // vibrant purple
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      // iOS-style smooth page transitions everywhere
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F4FB),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F4FB),
        foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF16162A) : Colors.white,
        indicatorColor: seed.withOpacity(0.18),
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C2E) : const Color(0xFFEEEEF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: seed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Splash
// ---------------------------------------------------------------------------

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_rounded, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text('Memcard',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    )),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showLogin
          ? LoginScreen(
              key: const ValueKey('login'),
              authProvider: widget.authProvider,
              onGoToRegister: () => setState(() => _showLogin = false),
            )
          : RegisterScreen(
              key: const ValueKey('register'),
              authProvider: widget.authProvider,
              onGoToLogin: () => setState(() => _showLogin = true),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main home (authenticated) — bottom NavigationBar
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage(
      {super.key,
      required this.authProvider,
      required this.apiService,
      required this.vocabStore});
  final AuthProvider authProvider;
  final ApiService apiService;
  final VocabStore vocabStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.style_outlined),
      selectedIcon: Icon(Icons.style),
      label: 'Cards',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: 'Study',
    ),
    NavigationDestination(
      icon: Icon(Icons.translate_outlined),
      selectedIcon: Icon(Icons.translate),
      label: 'Vocab',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: 'Buckets',
    ),
    NavigationDestination(
      icon: Icon(Icons.store_outlined),
      selectedIcon: Icon(Icons.store),
      label: 'Market',
    ),
  ];

  static const _titles = ['Cards', 'Study', 'Vocabulary', 'Buckets', 'Market'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<_AppMenuAction>(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary.withOpacity(0.15),
                child: Icon(Icons.person_outline, color: cs.primary, size: 20),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (action) {
                if (action == _AppMenuAction.logout) widget.authProvider.logout();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _AppMenuAction.logout,
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: cs.error),
                      const SizedBox(width: 10),
                      Text('Sign out',
                          style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          CardsTab(authProvider: widget.authProvider, apiService: widget.apiService),
          const StudyTab(),
          VocabTab(authProvider: widget.authProvider, apiService: widget.apiService, vocabStore: widget.vocabStore),
          BucketsTab(authProvider: widget.authProvider, apiService: widget.apiService),
          MarketTab(authProvider: widget.authProvider, apiService: widget.apiService),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 0.5, thickness: 0.5,
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.1)),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: _destinations,
          ),
        ],
      ),
    );
  }
}

enum _AppMenuAction { logout }
