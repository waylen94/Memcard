import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../models/vocabulary_word.dart';
import '../services/api_service.dart';
import 'bucket_study_screen.dart';

class VocabTab extends StatefulWidget {
  const VocabTab(
      {super.key, required this.authProvider, required this.apiService});
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<VocabTab> createState() => _VocabTabState();
}

class _VocabTabState extends State<VocabTab> {
  List<VocabularyWord> _words = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync({bool incremental = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = widget.authProvider.token!;
      final result = await widget.apiService.syncVocabulary(
        token: token,
        since: incremental ? _lastSyncedAt : null,
      );
      setState(() {
        if (incremental) {
          final abandonedIds =
              result.words.where((w) => w.abandoned).map((w) => w.id).toSet();
          _words
            ..removeWhere((w) => abandonedIds.contains(w.id))
            ..addAll(result.words.where((w) => !w.abandoned));
          _words.sort((a, b) => a.word.compareTo(b.word));
        } else {
          _words = result.words..sort((a, b) => a.word.compareTo(b.word));
        }
        _lastSyncedAt = result.syncedAt;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to sync vocabulary.';
        _loading = false;
      });
    }
  }

  Future<void> _openAddDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddWordSheet(
        onSubmit: (word, meaning, sourceType, source) async {
          final token = widget.authProvider.token!;
          await widget.apiService.addVocabulary(
            token: token,
            word: word,
            meaning: meaning,
            sourceType: sourceType.isEmpty ? null : sourceType,
            source: source.isEmpty ? null : source,
          );
          if (ctx.mounted) Navigator.of(ctx).pop();
          await _sync(incremental: true);
        },
      ),
    );
  }

  Future<void> _abandon(VocabularyWord word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandon word?'),
        content: Text('"${word.word}" will be removed from your vocabulary.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abandon')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService
          .abandonWord(token: widget.authProvider.token!, id: word.id);
      setState(() => _words.removeWhere((w) => w.id == word.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _markRemembered(VocabularyWord word) async {
    try {
      await widget.apiService
          .rememberWord(token: widget.authProvider.token!, id: word.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as remembered ✓')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _startStudy() {
    if (_words.isEmpty) return;
    final cards = _words
        .map((w) => StudyCard(
              front: w.word,
              back: w.meaning,
              remoteId: w.id,
            ))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BucketStudyScreen(
          title: 'Vocabulary',
          cards: cards,
          authProvider: widget.authProvider,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_words.isNotEmpty)
            FloatingActionButton.small(
              heroTag: 'study_vocab',
              onPressed: _startStudy,
              tooltip: 'Study all',
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.play_arrow_rounded),
            ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_vocab',
            onPressed: _openAddDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Word'),
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _sync(),
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
              OutlinedButton(onPressed: _sync, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_words.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate_outlined,
                size: 64, color: cs.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No vocabulary yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Tap Add Word to get started',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _words.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final w = _words[i];
        return _VocabWordTile(
          word: w,
          onRemember: () => _markRemembered(w),
          onAbandon: () => _abandon(w),
        );
      },
    );
  }
}

// ── Vocab Word Tile ──────────────────────────────────────────────────────────

class _VocabWordTile extends StatelessWidget {
  const _VocabWordTile({
    required this.word,
    required this.onRemember,
    required this.onAbandon,
  });
  final VocabularyWord word;
  final VoidCallback onRemember;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviewSoon = word.nextReviewAt != null &&
        word.nextReviewAt!.isBefore(DateTime.now().add(const Duration(days: 1)));
    return Material(
      color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word.word,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        if (reviewSoon) ...[  
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Review',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(word.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                    if (word.source != null) ...[  
                      const SizedBox(height: 4),
                      Text(
                        '${word.sourceType ?? ''} · ${word.source}',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withOpacity(0.6)),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_WordAction>(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                icon:
                    Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                onSelected: (action) {
                  if (action == _WordAction.remember) onRemember();
                  if (action == _WordAction.abandon) onAbandon();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: _WordAction.remember,
                      child: Row(children: [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Mark remembered'),
                      ])),
                  PopupMenuItem(
                      value: _WordAction.abandon,
                      child: Row(children: [
                        Icon(Icons.block_outlined, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Abandon'),
                      ])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _WordAction { remember, abandon }

// ---------------------------------------------------------------------------
// Add-word bottom sheet
// ---------------------------------------------------------------------------

class _AddWordSheet extends StatefulWidget {
  const _AddWordSheet({required this.onSubmit});
  final Future<void> Function(
      String word, String meaning, String sourceType, String source) onSubmit;

  @override
  State<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<_AddWordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _wordCtrl = TextEditingController();
  final _meaningCtrl = TextEditingController();
  final _sourceTypeCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _wordCtrl.dispose();
    _meaningCtrl.dispose();
    _sourceTypeCtrl.dispose();
    _sourceCtrl.dispose();
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
        top: 16,
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
            const SizedBox(height: 14),
            Text('Add Word',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            TextFormField(
              controller: _wordCtrl,
              decoration: const InputDecoration(labelText: 'Word *'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the word' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meaningCtrl,
              decoration: const InputDecoration(labelText: 'Meaning *'),
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the meaning' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sourceTypeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Type (e.g. book)'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _sourceCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Source title'),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _loading = true);
                      await widget.onSubmit(
                        _wordCtrl.text.trim(),
                        _meaningCtrl.text.trim(),
                        _sourceTypeCtrl.text.trim(),
                        _sourceCtrl.text.trim(),
                      );
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
