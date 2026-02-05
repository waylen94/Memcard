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
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final cards = store.cards;
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openEditor(context, store),
            child: const Icon(Icons.add),
          ),
          body: cards.isEmpty
              ? const Center(child: Text('No cards yet. Add your first one.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return ListTile(
                      tileColor: Theme.of(context).colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(card.back, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _openEditor(context, store, card: card),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await _confirmDelete(context);
                          if (confirmed) {
                            await store.deleteCard(card.id);
                          }
                        },
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: cards.length,
                ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, CardStore store, {Flashcard? card}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: _CardEditor(
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
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete card?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }
}

class _CardEditor extends StatefulWidget {
  const _CardEditor({this.card, required this.onSubmit});
  final Flashcard? card;
  final Future<void> Function(String front, String back) onSubmit;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final TextEditingController _front = TextEditingController(text: widget.card?.front ?? '');
  late final TextEditingController _back = TextEditingController(text: widget.card?.back ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.card == null ? 'New Card' : 'Edit Card', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: _front,
            decoration: const InputDecoration(labelText: 'Front'),
            maxLines: null,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter front text' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _back,
            decoration: const InputDecoration(labelText: 'Back'),
            maxLines: null,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter back text' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    await widget.onSubmit(_front.text.trim(), _back.text.trim());
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
