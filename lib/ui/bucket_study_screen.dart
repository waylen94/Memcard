import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    with TickerProviderStateMixin {
  late List<StudyCard> _queue;
  bool _showBack = false;
  int _remembered = 0;
  int _forgotten = 0;
  int _total = 0;

  // ── flip animation ────────────────────────────────────────────────────────
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;

  // ── swipe / drag ──────────────────────────────────────────────────────────
  double _dragX = 0;
  double _dragY = 0;
  bool _dragging = false;

  // ── swipe-out (card flying off screen) ───────────────────────────────────
  late final AnimationController _swipeOutCtrl;
  late Animation<Offset> _swipeOutAnim;
  bool _isSwiping = false;
  bool? _swipeAnswer; // true = remembered, false = forgotten

  // ── card entrance animation ───────────────────────────────────────────────
  late final AnimationController _enterCtrl;
  late final Animation<double> _enterScale;
  late final Animation<double> _enterOpacity;

  // ── button scale feedback ─────────────────────────────────────────────────
  late final AnimationController _gotItCtrl;
  late final AnimationController _forgotCtrl;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.cards)..shuffle();
    _total = _queue.length;

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim =
        CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutBack);

    _swipeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _swipeOutAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(600, 0),
    ).animate(
        CurvedAnimation(parent: _swipeOutCtrl, curve: Curves.easeIn));

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _enterScale = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.elasticOut));
    _enterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();

    _gotItCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        lowerBound: 0.88,
        upperBound: 1.0,
        value: 1.0);
    _forgotCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        lowerBound: 0.88,
        upperBound: 1.0,
        value: 1.0);
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _swipeOutCtrl.dispose();
    _enterCtrl.dispose();
    _gotItCtrl.dispose();
    _forgotCtrl.dispose();
    super.dispose();
  }

  // ── flip ──────────────────────────────────────────────────────────────────
  void _flip() {
    if (_flipCtrl.isAnimating || _isSwiping) return;
    HapticFeedback.lightImpact();
    if (_showBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _showBack = !_showBack);
  }

  // ── answer ────────────────────────────────────────────────────────────────
  Future<void> _answer(bool remembered) async {
    if (_queue.isEmpty || _isSwiping) return;
    final card = _queue.first;

    if (remembered) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    // Button press spring
    final btnCtrl = remembered ? _gotItCtrl : _forgotCtrl;
    btnCtrl.reverse().then((_) => btnCtrl.forward());

    // API call for remote vocab
    if (card.remoteId != null &&
        widget.authProvider != null &&
        widget.apiService != null) {
      try {
        if (remembered) {
          await widget.apiService!.rememberWord(
              token: widget.authProvider!.token!, id: card.remoteId!);
        }
      } catch (_) {}
    }

    if (remembered) {
      _remembered++;
    } else {
      _forgotten++;
    }

    // Animate card flying off
    setState(() => _isSwiping = true);
    _swipeAnswer = remembered;
    _swipeOutAnim = Tween<Offset>(
      begin: Offset(_dragX, _dragY * 0.3),
      end: Offset(remembered ? 700 : -700, _dragY * 0.3 - 80),
    ).animate(
        CurvedAnimation(parent: _swipeOutCtrl, curve: Curves.easeIn));

    await _swipeOutCtrl.forward();

    if (!mounted) return;
    setState(() {
      _queue.removeAt(0);
      if (!remembered) {
        final ri = min(3, _queue.length);
        _queue.insert(ri, card);
      }
      _showBack = false;
      _dragX = 0;
      _dragY = 0;
      _dragging = false;
      _isSwiping = false;
      _swipeAnswer = null;
    });
    _flipCtrl.reset();
    _swipeOutCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── keyboard ──────────────────────────────────────────────────────────────
  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_queue.isEmpty) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.arrowUp:
        _flip();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _answer(true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _answer(false);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty && !_isSwiping) return _doneScreen(context);

    final cs = Theme.of(context).colorScheme;
    final card = _queue.isNotEmpty ? _queue.first : null;
    final answeredCount =
        _total - _queue.length + (_isSwiping ? 1 : 0);
    final progress = answeredCount / _total.clamp(1, _total);

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: Text(widget.title),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // ── stats row ───────────────────────────────────────────
                _StatsRow(
                  remembered: _remembered,
                  forgotten: _forgotten,
                  current: answeredCount + 1,
                  total: _total,
                ),
                const SizedBox(height: 16),

                // ── card area ───────────────────────────────────────────
                Expanded(
                  child: card == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: _flip,
                          onHorizontalDragStart: (_) =>
                              setState(() => _dragging = true),
                          onHorizontalDragUpdate: (d) => setState(() {
                            _dragX += d.delta.dx;
                            _dragY += d.delta.dy * 0.4;
                          }),
                          onHorizontalDragEnd: (_) {
                            if (_dragX > 90) {
                              _answer(true);
                            } else if (_dragX < -90) {
                              _answer(false);
                            } else {
                              setState(() {
                                _dragX = 0;
                                _dragY = 0;
                                _dragging = false;
                              });
                            }
                          },
                          child: _CardStack(
                            card: card,
                            flipAnim: _flipAnim,
                            swipeOutAnim: _swipeOutAnim,
                            isSwiping: _isSwiping,
                            swipeAnswer: _swipeAnswer,
                            dragX: _dragX,
                            dragY: _dragY,
                            dragging: _dragging,
                            showBack: _showBack,
                            enterScale: _enterScale,
                            enterOpacity: _enterOpacity,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // ── animated hint ───────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    key: ValueKey(_showBack),
                    _showBack
                        ? '← Forgot  ·  Got it →  ·  tap to flip back'
                        : 'Tap to reveal  ·  then swipe or use buttons',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── action buttons ──────────────────────────────────────
                Row(
                  children: [
                    _ActionButton(
                      scaleCtrl: _forgotCtrl,
                      icon: Icons.close_rounded,
                      label: 'Forgot',
                      sublabel: '←',
                      color: cs.error,
                      onTap: () => _answer(false),
                    ),
                    const SizedBox(width: 12),
                    _FlipButton(onTap: _flip, showBack: _showBack),
                    const SizedBox(width: 12),
                    _ActionButton(
                      scaleCtrl: _gotItCtrl,
                      icon: Icons.check_rounded,
                      label: 'Got it',
                      sublabel: '→',
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
      ),
    );
  }

  // ── done screen ───────────────────────────────────────────────────────────
  Widget _doneScreen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct =
        _total == 0 ? 0 : (_remembered / _total * 100).round();
    final perfect = pct == 100;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (perfect ? Colors.amber : cs.primary)
                        .withOpacity(0.12),
                  ),
                  child: Icon(
                    perfect
                        ? Icons.star_rounded
                        : Icons.emoji_events_rounded,
                    size: 64,
                    color: perfect ? Colors.amber : cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                perfect ? 'Perfect round! 🎉' : 'Session complete!',
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _ScoreRow(
                remembered: _remembered,
                forgotten: _forgotten,
                total: _total,
                pct: pct,
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _queue = List.of(widget.cards)..shuffle();
                    _total = _queue.length;
                    _remembered = 0;
                    _forgotten = 0;
                    _showBack = false;
                    _flipCtrl.reset();
                    _enterCtrl.forward(from: 0);
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

// ═══════════════════════════════════════════════════════════════════════════
// Card Stack
// ═══════════════════════════════════════════════════════════════════════════

class _CardStack extends StatelessWidget {
  const _CardStack({
    required this.card,
    required this.flipAnim,
    required this.swipeOutAnim,
    required this.isSwiping,
    required this.swipeAnswer,
    required this.dragX,
    required this.dragY,
    required this.dragging,
    required this.showBack,
    required this.enterScale,
    required this.enterOpacity,
  });

  final StudyCard card;
  final Animation<double> flipAnim;
  final Animation<Offset> swipeOutAnim;
  final bool isSwiping;
  final bool? swipeAnswer;
  final double dragX;
  final double dragY;
  final bool dragging;
  final bool showBack;
  final Animation<double> enterScale;
  final Animation<double> enterOpacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        flipAnim,
        swipeOutAnim,
        enterScale,
        enterOpacity,
      ]),
      builder: (context, _) {
        final angle = flipAnim.value * pi;
        final isFront = angle <= pi / 2;

        // Slight tilt when dragging
        final tiltAngle = dragging ? (dragX / 800) : 0.0;
        final liftY = dragging ? (dragX.abs() / 400) * -18.0 : 0.0;

        final swipeOffset = isSwiping ? swipeOutAnim.value : Offset.zero;

        return ScaleTransition(
          scale: isSwiping
              ? const AlwaysStoppedAnimation(1.0)
              : enterScale,
          child: FadeTransition(
            opacity: isSwiping
                ? const AlwaysStoppedAnimation(1.0)
                : enterOpacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(
                    swipeOffset.dx + (dragging ? dragX : 0.0),
                    swipeOffset.dy + (dragging ? dragY : 0.0) + liftY)
                ..rotateZ(tiltAngle)
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: _FlipCardFace(
                isFront: isFront,
                front: card.front,
                back: card.back,
                dragX: dragging ? dragX : 0.0,
                swipeAnswer: isSwiping ? swipeAnswer : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Flip Card Face
// ═══════════════════════════════════════════════════════════════════════════

class _FlipCardFace extends StatelessWidget {
  const _FlipCardFace({
    required this.isFront,
    required this.front,
    required this.back,
    required this.dragX,
    this.swipeAnswer,
  });

  final bool isFront;
  final String front;
  final String back;
  final double dragX;
  final bool? swipeAnswer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Counter-rotate content on back face
    final content = Transform(
      alignment: Alignment.center,
      transform: isFront
          ? Matrix4.identity()
          : (Matrix4.identity()..rotateY(pi)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Label badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (isFront ? cs.primary : Colors.green)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFront ? 'FRONT' : 'BACK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: isFront
                        ? cs.primary
                        : Colors.green.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  isFront ? front : back,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.3,
                      ),
                ),
              ),
              if (!isFront) ...[
                const SizedBox(height: 16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Front: $front',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
          // Swipe overlay badge
          if (dragX.abs() > 24 || swipeAnswer != null)
            Positioned(
              top: 28,
              left:
                  (dragX > 0 || swipeAnswer == true) ? 24 : null,
              right:
                  (dragX < 0 || swipeAnswer == false) ? 24 : null,
              child: Transform.rotate(
                angle: (dragX > 0 || swipeAnswer == true)
                    ? -0.18
                    : 0.18,
                child: _SwipeOverlayBadge(
                  remembered: (dragX > 0 || swipeAnswer == true),
                  opacity: swipeAnswer != null
                      ? 1.0
                      : (dragX.abs() / 120).clamp(0.0, 1.0),
                ),
              ),
            ),
        ],
      ),
    );

    // Tint card during drag / swipe
    Color cardColor =
        isDark ? const Color(0xFF1C1C2E) : Colors.white;
    if (swipeAnswer == true) {
      cardColor =
          Color.lerp(cardColor, Colors.green.withOpacity(0.4), 0.6)!;
    } else if (swipeAnswer == false) {
      cardColor = Color.lerp(
          cardColor, cs.error.withOpacity(0.4), 0.6)!;
    } else if (dragX > 20) {
      cardColor = Color.lerp(cardColor,
          Colors.green.withOpacity(0.35), (dragX / 140).clamp(0, 1))!;
    } else if (dragX < -20) {
      cardColor = Color.lerp(cardColor, cs.error.withOpacity(0.35),
          (-dragX / 140).clamp(0, 1))!;
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

// ═══════════════════════════════════════════════════════════════════════════
// Swipe overlay badge
// ═══════════════════════════════════════════════════════════════════════════

class _SwipeOverlayBadge extends StatelessWidget {
  const _SwipeOverlayBadge(
      {required this.remembered, required this.opacity});

  final bool remembered;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = remembered
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          remembered ? 'GOT IT ✓' : 'FORGOT ✗',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stats row
// ═══════════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.remembered,
    required this.forgotten,
    required this.current,
    required this.total,
  });

  final int remembered;
  final int forgotten;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Pill(
            icon: Icons.check_circle_outline,
            label: '$remembered',
            color: Colors.green),
        Column(
          children: [
            Text(
              '$current / $total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'cards',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ],
        ),
        _Pill(
            icon: Icons.replay_rounded,
            label: '$forgotten',
            color: Colors.orange),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Flip button (centre of action row)
// ═══════════════════════════════════════════════════════════════════════════

class _FlipButton extends StatelessWidget {
  const _FlipButton({required this.onTap, required this.showBack});

  final VoidCallback onTap;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.primaryContainer,
        ),
        child: AnimatedRotation(
          turns: showBack ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          child: Icon(Icons.flip_rounded,
              color: cs.onPrimaryContainer, size: 22),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Action buttons
// ═══════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.scaleCtrl,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  final AnimationController scaleCtrl;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: scaleCtrl,
          builder: (_, child) =>
              Transform.scale(scale: scaleCtrl.value, child: child),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: color.withOpacity(0.35), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ],
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                      color: color.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Score row on done screen
// ═══════════════════════════════════════════════════════════════════════════

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.remembered,
    required this.forgotten,
    required this.total,
    required this.pct,
  });

  final int remembered;
  final int forgotten;
  final int total;
  final int pct;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ScoreTile(
            value: remembered, label: 'Got it', color: Colors.green),
        Container(
          width: 1,
          height: 40,
          color: cs.outlineVariant,
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        _ScoreTile(
            value: pct,
            label: 'Score',
            color: cs.primary,
            suffix: '%'),
        Container(
          width: 1,
          height: 40,
          color: cs.outlineVariant,
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        _ScoreTile(
            value: forgotten,
            label: 'Forgot',
            color: Colors.orange),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.value,
    required this.label,
    required this.color,
    this.suffix = '',
  });

  final int value;
  final String label;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (_, v, __) => Column(
        children: [
          Text(
            '${v.round()}$suffix',
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pill
// ═══════════════════════════════════════════════════════════════════════════

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
