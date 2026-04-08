import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../models/vocabulary_word.dart';
import '../services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        tooltip: 'Add word',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => _sync(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _sync, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_words.isEmpty) {
      return const Center(
          child: Text('No vocabulary yet.\nTap + to add a word.',
              textAlign: TextAlign.center));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _words.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final w = _words[i];
        return ListTile(
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(w.word, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(w.meaning, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: PopupMenuButton<_WordAction>(
            onSelected: (action) {
              if (action == _WordAction.remember) _markRemembered(w);
              if (action == _WordAction.abandon) _abandon(w);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _WordAction.remember,
                  child: Text('Mark remembered')),
              PopupMenuItem(
                  value: _WordAction.abandon, child: Text('Abandon')),
            ],
          ),
        );
      },
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Word',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextFormField(
              controller: _wordCtrl,
              decoration: const InputDecoration(
                  labelText: 'Word *', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the word' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meaningCtrl,
              decoration: const InputDecoration(
                  labelText: 'Meaning *', border: OutlineInputBorder()),
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the meaning' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sourceTypeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Source type (e.g. book)',
                  border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sourceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Source (e.g. Harry Potter)',
                  border: OutlineInputBorder()),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
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
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
