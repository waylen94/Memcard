import 'package:flutter/material.dart';

import '../data/card_provider.dart';
import '../data/card_store.dart';
import '../models/flashcard.dart';

class CardsTab extends StatefulWidget {
  const CardsTab({super.key});

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
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
          body: cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.style_outlined, size: 64, color: cs.primary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('No cards yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Tap the button below to add your first card',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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

