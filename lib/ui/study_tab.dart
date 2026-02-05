import 'dart:math';

import 'package:flutter/material.dart';

import '../data/card_provider.dart';
import '../data/card_store.dart';
import '../models/flashcard.dart';

class StudyTab extends StatefulWidget {
  const StudyTab({super.key});

  @override
  State<StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends State<StudyTab> {
  List<Flashcard> _queue = [];
  bool _showBack = false;
  CardStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = CardProvider.of(context);
    if (_store != store) {
      _store?.removeListener(_onStoreChanged);
      _store = store
        ..addListener(_onStoreChanged);
      _rebuildQueue();
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _rebuildQueue() {
    final store = _store;
    if (store == null) return;
    final due = store.dueCards();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _queue = List.of(due);
        _showBack = false;
      });
    });
  }

  void _onStoreChanged() => _rebuildQueue();

  void _handleSwipe(bool remembered) {
    if (_queue.isEmpty) return;
    final store = _store ?? CardProvider.of(context);
    final current = _queue.first;
    store.recordReview(current, remembered: remembered);
    setState(() {
      _queue.removeAt(0);
      if (!remembered) {
        final reinsertionIndex = min(2, _queue.length);
        _queue.insert(reinsertionIndex, current);
      }
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = _store ?? CardProvider.of(context);
    if (_queue.isEmpty) {
      final dueLater = store.cards.length;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            dueLater == 0
                ? 'Add cards to start studying.'
                : 'All caught up. New cards will appear when they are due.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final card = _queue.first;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Dismissible(
              key: ValueKey(card.id),
              direction: DismissDirection.horizontal,
              background: const _SwipeBackground(label: 'Remember', alignment: Alignment.centerLeft, color: Colors.green),
              secondaryBackground: const _SwipeBackground(label: 'Forgot', alignment: Alignment.centerRight, color: Colors.red),
              onDismissed: (direction) => _handleSwipe(direction == DismissDirection.startToEnd),
              confirmDismiss: (direction) async {
                // Let the card animate away and handle in onDismissed.
                return true;
              },
              child: GestureDetector(
                onTap: () => setState(() => _showBack = !_showBack),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                        child: Text(
                          _showBack ? card.back : card.front,
                          key: ValueKey(_showBack),
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleSwipe(false),
                  icon: const Icon(Icons.close),
                  label: const Text('Forgot'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _handleSwipe(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Remember'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tap to flip. Swipe right = remember, left = forgot.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.label, required this.alignment, required this.color});
  final String label;
  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: color.withOpacity(0.15),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
