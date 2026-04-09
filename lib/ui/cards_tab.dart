import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_provider.dart';
import '../data/card_provider.dart';
import '../data/card_store.dart';
import '../models/flashcard.dart';
import '../services/api_service.dart';
import 'bucket_study_screen.dart';

const _kLastBucketId = 'last_bucket_id';
const _kLastBucketName = 'last_bucket_name';

class CardsTab extends StatefulWidget {
  const CardsTab({
    super.key,
    required this.authProvider,
    required this.apiService,
  });

  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  int? _continueBucketId;
  String? _continueBucketName;
  bool _loadingContinue = true;
  bool _studyLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContinueBucket();
  }

  Future<void> _loadContinueBucket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt(_kLastBucketId);
      final savedName = prefs.getString(_kLastBucketName);

      if (savedId != null && savedName != null) {
        if (mounted) {
          setState(() {
            _continueBucketId = savedId;
            _continueBucketName = savedName;
            _loadingContinue = false;
          });
        }
        return;
      }

      // No saved bucket – fall back to the first bucket from the API
      final token = widget.authProvider.token;
      if (token != null) {
        final buckets = await widget.apiService.listBuckets(token: token);
        if (buckets.isNotEmpty && mounted) {
          setState(() {
            _continueBucketId = buckets.first.id;
            _continueBucketName = buckets.first.source;
            _loadingContinue = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingContinue = false);
  }

  Future<void> _studyContinueBucket() async {
    if (_continueBucketId == null || _studyLoading) return;
    setState(() => _studyLoading = true);
    try {
      final token = widget.authProvider.token!;
      List<StudyCard> cards;
      // Try the market/public endpoint first; fall back to sync+filter
      try {
        final result = await widget.apiService.getMarketBucketWords(
          token: token,
          bucketId: _continueBucketId!,
        );
        cards = result.words
            .map((w) => StudyCard(front: w.word, back: w.meaning, remoteId: w.id))
            .toList();
      } catch (_) {
        final result = await widget.apiService.syncVocabulary(token: token);
        cards = result.words
            .where((w) => w.bucketId == _continueBucketId && !w.abandoned)
            .map((w) => StudyCard(front: w.word, back: w.meaning, remoteId: w.id))
            .toList();
      }

      if (!mounted) return;
      if (cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No words in this bucket yet')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BucketStudyScreen(
            title: _continueBucketName ?? 'Study',
            cards: cards,
            authProvider: widget.authProvider,
            apiService: widget.apiService,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load study session')),
        );
      }
    } finally {
      if (mounted) setState(() => _studyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CardProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final cards = store.cards;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(context, store),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Card'),
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
          ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Continue Learning banner ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _ContinueLearningCard(
                    loading: _loadingContinue,
                    studyLoading: _studyLoading,
                    bucketName: _continueBucketName,
                    onTap: _studyContinueBucket,
                  ),
                ),
              ),

              if (cards.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.style_outlined,
                            size: 64, color: cs.primary.withOpacity(0.35)),
                        const SizedBox(height: 16),
                        Text('No local cards yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Tap + below to create your first flashcard',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              else ...[
                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          'MY CARDS',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${cards.length}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Card list
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return _CardTile(
                        card: card,
                        onTap: () => _openEditor(context, store, card: card),
                        onDelete: () async {
                          final confirmed = await _confirmDelete(context);
                          if (confirmed) await store.deleteCard(card.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, CardStore store,
      {Flashcard? card}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CardEditorSheet(
        card: card,
        onSubmit: (front, back) async {
          if (card == null) {
            await store.addCard(front: front, back: back);
          } else {
            await store.updateCard(card.id, front: front, back: back);
          }
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete card?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size(80, 40),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }
}

// ── Continue Learning Banner ──────────────────────────────────────────────────

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({
    required this.loading,
    required this.studyLoading,
    required this.bucketName,
    required this.onTap,
  });

  final bool loading;
  final bool studyLoading;
  final String? bucketName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (bucketName == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: studyLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary,
              Color.lerp(cs.primary, cs.tertiary, 0.55)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: studyLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTINUE LEARNING',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    bucketName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 15),
          ],
        ),
      ),
    );
  }
}

// ── Card Tile ────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  const _CardTile(
      {required this.card, required this.onTap, required this.onDelete});
  final Flashcard card;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDue = card.dueAt.isBefore(DateTime.now());
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.front,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(card.back,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isDue)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Due',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: cs.onSurfaceVariant, size: 20),
                onPressed: onDelete,
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Editor Sheet ─────────────────────────────────────────────────────────────

class _CardEditorSheet extends StatefulWidget {
  const _CardEditorSheet({this.card, required this.onSubmit});
  final Flashcard? card;
  final Future<void> Function(String front, String back) onSubmit;

  @override
  State<_CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<_CardEditorSheet> {
  late final TextEditingController _front =
      TextEditingController(text: widget.card?.front ?? '');
  late final TextEditingController _back =
      TextEditingController(text: widget.card?.back ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.card == null ? 'New Card' : 'Edit Card',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _front,
              decoration: const InputDecoration(labelText: 'Front side'),
              maxLines: null,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter front text' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _back,
              decoration: const InputDecoration(labelText: 'Back side'),
              maxLines: null,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter back text' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _loading = true);
                      await widget.onSubmit(
                          _front.text.trim(), _back.text.trim());
                      if (mounted) setState(() => _loading = false);
                    },
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

