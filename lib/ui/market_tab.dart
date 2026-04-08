import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../models/bucket.dart';
import '../models/vocabulary_word.dart';
import '../services/api_service.dart';
import 'bucket_study_screen.dart';

class MarketTab extends StatefulWidget {
  const MarketTab(
      {super.key, required this.authProvider, required this.apiService});
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  List<Bucket> _buckets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final buckets = await widget.apiService
          .browseMarket(token: widget.authProvider.token!);
      setState(() {
        _buckets = buckets;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load market.';
        _loading = false;
      });
    }
  }

  Future<void> _openBucket(Bucket bucket) async {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketBucketWordsScreen(
          bucket: bucket,
          authProvider: widget.authProvider,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_buckets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined,
                size: 64, color: cs.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No public buckets yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Be the first to publish your vocabulary!',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _buckets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _MarketBucketTile(
        bucket: _buckets[i],
        onTap: () => _openBucket(_buckets[i]),
      ),
    );
  }
}

// ── Market Bucket Tile ────────────────────────────────────────────────────────

class _MarketBucketTile extends StatelessWidget {
  const _MarketBucketTile({required this.bucket, required this.onTap});
  final Bucket bucket;
  final VoidCallback onTap;

  static const _palette = [
    Color(0xFF6C63FF),
    Color(0xFF43AFFF),
    Color(0xFFFF6584),
    Color(0xFF43C6AC),
    Color(0xFFFFB347),
    Color(0xFFB067E9),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _palette[bucket.id % _palette.length];

    return Material(
      color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Left accent strip
            Container(
              width: 6,
              height: 90,
              color: accent,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bucket.source,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bucket.sourceType} · ${bucket.vocabulariesCount} word${bucket.vocabulariesCount == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    if (bucket.owner != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13, color: cs.onSurfaceVariant.withOpacity(0.6)),
                          const SizedBox(width: 3),
                          Text(
                            bucket.owner!.name,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Market Bucket Words — browse + study
// ---------------------------------------------------------------------------

class MarketBucketWordsScreen extends StatefulWidget {
  const MarketBucketWordsScreen({
    super.key,
    required this.bucket,
    required this.authProvider,
    required this.apiService,
  });
  final Bucket bucket;
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<MarketBucketWordsScreen> createState() =>
      _MarketBucketWordsScreenState();
}

class _MarketBucketWordsScreenState extends State<MarketBucketWordsScreen> {
  List<VocabularyWord> _words = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.apiService.getMarketBucketWords(
          token: widget.authProvider.token!, bucketId: widget.bucket.id);
      setState(() {
        _words = result.words;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load words.';
        _loading = false;
      });
    }
  }

  void _startStudy() {
    if (_words.isEmpty) return;
    final cards = _words
        .map((w) => StudyCard(front: w.word, back: w.meaning))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BucketStudyScreen(
          title: widget.bucket.source,
          cards: cards,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bucket.source),
        actions: [
          if (_words.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: _startStudy,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Study'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_words.isEmpty) {
      return const Center(child: Text('No words in this bucket.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _words.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final w = _words[i];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.word,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(w.meaning,
                    style: TextStyle(
                        fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
  }
}
