import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../models/bucket.dart';
import '../models/vocabulary_word.dart';
import '../services/api_service.dart';

class MarketTab extends StatefulWidget {
  const MarketTab(
      {super.key, required this.authProvider, required this.apiService});
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
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
      final buckets =
          await widget.apiService.browseMarket(token: widget.authProvider.token!);
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
        _error = 'Failed to load market.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_buckets.isEmpty) {
      return const Center(
          child: Text('No public buckets yet.',
              textAlign: TextAlign.center));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _buckets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final b = _buckets[i];
        return Card(
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.public)),
            title: Text(b.source,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${b.sourceType} · ${b.vocabulariesCount} word${b.vocabulariesCount == 1 ? '' : 's'}'
                '${b.owner != null ? ' · by ${b.owner!.name}' : ''}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openBucket(b),
          ),
        );
      },
    );
  }

  void _openBucket(Bucket bucket) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketBucketWordsScreen(
          title: bucket.source,
          bucketId: bucket.id,
          authProvider: widget.authProvider,
          apiService: widget.apiService,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared detail screen — reused by BucketsTab and MarketTab
// ---------------------------------------------------------------------------

class MarketBucketWordsScreen extends StatefulWidget {
  const MarketBucketWordsScreen({
    super.key,
    required this.title,
    required this.bucketId,
    required this.authProvider,
    required this.apiService,
  });
  final String title;
  final int bucketId;
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<MarketBucketWordsScreen> createState() =>
      _MarketBucketWordsScreenState();
}

class _MarketBucketWordsScreenState extends State<MarketBucketWordsScreen> {
  List<VocabularyWord> _words = [];
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
      final result = await widget.apiService.getMarketBucketWords(
          token: widget.authProvider.token!, bucketId: widget.bucketId);
      setState(() {
        _words = result.words;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load words.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_words.isEmpty) {
      return const Center(child: Text('No words in this bucket.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _words.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final w = _words[i];
        return ListTile(
          tileColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(w.word,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(w.meaning,
              maxLines: 3, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}
