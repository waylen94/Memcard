import 'package:flutter/material.dart';

import '../data/card_provider.dart';
import '../data/card_store.dart';
import 'bucket_study_screen.dart';

class StudyTab extends StatefulWidget {
  const StudyTab({super.key});

  @override
  State<StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends State<StudyTab> {
  CardStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = CardProvider.of(context);
    if (_store != store) {
      _store?.removeListener(_rebuild);
      _store = store..addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _startStudy(List<StudyCard> cards) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BucketStudyScreen(title: 'My Cards', cards: cards),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _store ?? CardProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    final due = store.dueCards();
    final all = store.cards;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // Hero stat
          _StatBanner(due: due.length, total: all.length),
          const SizedBox(height: 28),

          if (due.isNotEmpty) ...[
            _SectionLabel('Due now'),
            const SizedBox(height: 12),
            _StudyActionCard(
              icon: Icons.flash_on_rounded,
              title: 'Study due cards',
              subtitle: '${due.length} card${due.length == 1 ? '' : 's'} waiting',
              color: cs.primary,
              onTap: () => _startStudy(
                due
                    .map((c) => StudyCard(front: c.front, back: c.back))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (all.isNotEmpty) ...[
            _SectionLabel('All cards'),
            const SizedBox(height: 12),
            _StudyActionCard(
              icon: Icons.library_books_outlined,
              title: 'Study all cards',
              subtitle: '${all.length} card${all.length == 1 ? '' : 's'} total',
              color: Colors.deepPurple,
              onTap: () => _startStudy(
                all
                    .map((c) => StudyCard(front: c.front, back: c.back))
                    .toList(),
              ),
            ),
          ],

          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.school_outlined,
                      size: 64, color: cs.primary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No cards to study',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Add cards in the Cards tab to get started',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatBanner extends StatelessWidget {
  const _StatBanner({required this.due, required this.total});
  final int due;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.6)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ready to study?',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('$due due  ·  $total total',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ],
            ),
          ),
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 48),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ));
  }
}

class _StudyActionCard extends StatelessWidget {
  const _StudyActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
