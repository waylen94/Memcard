import 'dart:math';

import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../services/api_service.dart';

/// A word-pair used by the study screen.
class StudyCard {
  const StudyCard({required this.front, required this.back, this.remoteId});

  /// e.g. the word
  final String front;

  /// e.g. the meaning
  final String back;

  /// If non-null this is a remote vocabulary word — used to call remember/abandon.
  final int? remoteId;
}

/// Full-screen study session that works for both local flashcards and
/// remote vocabulary words.  Pass [authProvider] + [apiService] only when
/// dealing with remote vocabulary words (remoteId != null).
class BucketStudyScreen extends StatefulWidget {
  const BucketStudyScreen({
    super.key,
    required this.title,
    required this.cards,
    this.authProvider,
    this.apiService,
  });

  final String title;
  final List<StudyCard> cards;
  final AuthProvider? authProvider;
  final ApiService? apiService;

  @override
  State<BucketStudyScreen> createState() => _BucketStudyScreenState();
}

class _BucketStudyScreenState extends State<BucketStudyScreen>
    with SingleTickerProviderStateMixin {
  late List<StudyCard> _queue;
  bool _showBack = false;
  int _remembered = 0;
  int _total = 0;

  // For the 3-D flip
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;

  // For card-swipe exit
  double _dragX = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.cards)..shuffle();
    _total = _queue.length;
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipCtrl.isAnimating) return;
    if (_showBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _showBack = !_showBack);
  }

  Future<void> _answer(bool remembered) async {
    if (_queue.isEmpty) return;
    final card = _queue.first;

    // Call API if this is a remote vocab word
    if (card.remoteId != null &&
        widget.authProvider != null &&
        widget.apiService != null) {
      try {
        if (remembered) {
          await widget.apiService!
              .rememberWord(token: widget.authProvider!.token!, id: card.remoteId!);
        }
      } catch (_) {
        // non-blocking
      }
    }

    if (remembered) _remembered++;

    setState(() {
      _queue.removeAt(0);
      if (!remembered) {
        final ri = min(3, _queue.length);
        _queue.insert(ri, card);
      }
      _showBack = false;
      _dragX = 0;
      _dragging = false;
    });
    _flipCtrl.reset();
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) return _doneScreen(context);

    final cs = Theme.of(context).colorScheme;
    final card = _queue.first;
    final progress = 1 - (_queue.length / _total.clamp(1, _total));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 400),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Pill(
                      icon: Icons.check_circle_outline,
                      label: '$_remembered',
                      color: Colors.green),
                  Text(
                    '${_total - _queue.length + 1} / $_total',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  _Pill(
                      icon: Icons.replay,
                      label: '${_queue.length - 1 < 0 ? 0 : _queue.length - 1}',
                      color: Colors.orange),
                ],
              ),
              const SizedBox(height: 16),

              // card
              Expanded(
                child: GestureDetector(
                  onTap: _flip,
                  onHorizontalDragStart: (_) => setState(() => _dragging = true),
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _dragX += d.delta.dx),
                  onHorizontalDragEnd: (_) {
                    if (_dragX > 80) {
                      _answer(true);
                    } else if (_dragX < -80) {
                      _answer(false);
                    } else {
                      setState(() {
                        _dragX = 0;
                        _dragging = false;
                      });
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _flipAnim,
                    builder: (_, __) {
                      final angle = _flipAnim.value * pi;
                      final isFront = angle <= pi / 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle)
                          ..translate(_dragging ? _dragX : 0.0),
                        child: _FlipCardFace(
                          isFront: isFront,
                          front: card.front,
                          back: card.back,
                          dragX: _dragX,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _hint(context),
              const SizedBox(height: 12),

              // buttons
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.close_rounded,
                    label: 'Forgot',
                    color: cs.error,
                    onTap: () => _answer(false),
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.check_rounded,
                    label: 'Got it',
                    color: Colors.green,
                    onTap: () => _answer(true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(BuildContext context) {
    return Text(
      _showBack
          ? 'Swipe right = got it  ·  swipe left = forgot'
          : 'Tap to reveal  ·  swipe to answer',
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  Widget _doneScreen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = _total == 0 ? 0 : (_remembered / _total * 100).round();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, size: 80, color: cs.primary),
              const SizedBox(height: 20),
              Text('Session complete!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('$_remembered / $_total remembered · $pct%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _queue = List.of(widget.cards)..shuffle();
                    _total = _queue.length;
                    _remembered = 0;
                    _showBack = false;
                    _flipCtrl.reset();
                  });
                },
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Study Again'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── sub-widgets ──────────────────────────────────────────────────────────────

class _FlipCardFace extends StatelessWidget {
  const _FlipCardFace({
    required this.isFront,
    required this.front,
    required this.back,
    required this.dragX,
  });

  final bool isFront;
  final String front;
  final String back;
  final double dragX;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // When the card is showing the back side it is Y-flipped by 180° from
    // the animation, so we counter-flip the content to keep it readable.
    final content = Transform(
      alignment: Alignment.center,
      transform: isFront ? Matrix4.identity() : (Matrix4.identity()..rotateY(pi)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isFront ? 'WORD' : 'MEANING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: isFront ? cs.primary : Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFront ? front : back,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.3,
                ),
          ),
        ],
      ),
    );

    // Tint the card based on drag direction
    Color cardColor = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    if (dragX > 20) {
      cardColor = Color.lerp(cardColor, Colors.green.withOpacity(0.3),
          (dragX / 120).clamp(0, 1))!;
    } else if (dragX < -20) {
      cardColor = Color.lerp(cardColor, cs.error.withOpacity(0.3),
          (-dragX / 120).clamp(0, 1))!;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
