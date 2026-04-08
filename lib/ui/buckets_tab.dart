import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../models/bucket.dart';
import '../models/vocabulary_word.dart';
import '../services/api_service.dart';
import 'bucket_study_screen.dart';

class BucketsTab extends StatefulWidget {
  const BucketsTab(
      {super.key, required this.authProvider, required this.apiService});
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<BucketsTab> createState() => _BucketsTabState();
}

class _BucketsTabState extends State<BucketsTab> {
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
          .listBuckets(token: widget.authProvider.token!);
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
        _error = 'Failed to load buckets.';
        _loading = false;
      });
    }
  }

  Future<void> _togglePublic(Bucket bucket) async {
    try {
      final updated = await widget.apiService.updateBucket(
        token: widget.authProvider.token!,
        bucketId: bucket.id,
        isPublic: !bucket.isPublic,
      );
      setState(() {
        final idx = _buckets.indexWhere((b) => b.id == updated.id);
        if (idx != -1) _buckets[idx] = updated;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(Bucket bucket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete bucket?'),
        content: Text(
            '"${bucket.source}" will be deleted. Words will remain but will no longer be grouped.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService.deleteBucket(
          token: widget.authProvider.token!, bucketId: bucket.id);
      setState(() => _buckets.removeWhere((b) => b.id == bucket.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _studyBucket(Bucket bucket) async {
    // Fetch words for this bucket via the market endpoint if public,
    // otherwise fall back to full sync and filter by bucket_id.
    List<VocabularyWord> words;
    try {
      if (bucket.isPublic) {
        final result = await widget.apiService.getMarketBucketWords(
            token: widget.authProvider.token!, bucketId: bucket.id);
        words = result.words;
      } else {
        final result = await widget.apiService
            .syncVocabulary(token: widget.authProvider.token!);
        words = result.words
            .where((w) => w.bucketId == bucket.id && !w.abandoned)
            .toList();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load words for study')));
      }
      return;
    }
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No words in this bucket')));
      }
      return;
    }
    if (!mounted) return;
    final cards = words
        .map((w) => StudyCard(front: w.word, back: w.meaning, remoteId: w.id))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BucketStudyScreen(
          title: bucket.source,
          cards: cards,
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
            Icon(Icons.folder_outlined,
                size: 64, color: cs.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No buckets yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Add words with a source to create a bucket',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.88,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _buckets.length,
      itemBuilder: (context, i) => _BucketCard(
        bucket: _buckets[i],
        onStudy: () => _studyBucket(_buckets[i]),
        onTogglePublic: () => _togglePublic(_buckets[i]),
        onDelete: () => _delete(_buckets[i]),
      ),
    );
  }
}

// ── Bucket Card ───────────────────────────────────────────────────────────────

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.bucket,
    required this.onStudy,
    required this.onTogglePublic,
    required this.onDelete,
  });

  final Bucket bucket;
  final VoidCallback onStudy;
  final VoidCallback onTogglePublic;
  final VoidCallback onDelete;

  // Deterministic color from bucket id
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
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStudy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coloured header strip
            Container(
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.black, 0.2)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      bucket.sourceType,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8),
                    ),
                  ),
                  PopupMenuButton<_BucketAction>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.white70, size: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (a) {
                      if (a == _BucketAction.togglePublic) onTogglePublic();
                      if (a == _BucketAction.delete) onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _BucketAction.togglePublic,
                        child: Row(children: [
                          Icon(bucket.isPublic
                              ? Icons.lock_outline
                              : Icons.public),
                          const SizedBox(width: 8),
                          Text(bucket.isPublic ? 'Make private' : 'Publish'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: _BucketAction.delete,
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bucket.source,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bucket.vocabulariesCount} word${bucket.vocabulariesCount == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (bucket.isPublic)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Public',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green)),
                          ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onStudy,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.play_arrow_rounded,
                                color: accent, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BucketAction { togglePublic, delete }
