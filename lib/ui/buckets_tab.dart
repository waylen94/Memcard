import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../models/bucket.dart';
import '../services/api_service.dart';
import 'market_tab.dart';

class BucketsTab extends StatefulWidget {
  const BucketsTab(
      {super.key, required this.authProvider, required this.apiService});
  final AuthProvider authProvider;
  final ApiService apiService;

  @override
  State<BucketsTab> createState() => _BucketsTabState();
}

class _BucketsTabState extends State<BucketsTab> {
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
      final buckets = await widget.apiService
          .listBuckets(token: widget.authProvider.token!);
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
        _error = 'Failed to load buckets.';
        _loading = false;
      });
    }
  }

  Future<void> _togglePublic(Bucket bucket) async {
    try {
      final updated = await widget.apiService.updateBucket(
        token: widget.authProvider.token!,
        bucketId: bucket.id,
        isPublic: !bucket.isPublic,
      );
      setState(() {
        final idx = _buckets.indexWhere((b) => b.id == updated.id);
        if (idx != -1) _buckets[idx] = updated;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(Bucket bucket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bucket?'),
        content: Text(
            '"${bucket.source}" will be deleted. Words will remain but will no longer be grouped.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService.deleteBucket(
          token: widget.authProvider.token!, bucketId: bucket.id);
      setState(() => _buckets.removeWhere((b) => b.id == bucket.id));
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
          child: Text('No buckets yet.\nAdd words with a source to create one.',
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
            title: Text(b.source,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${b.sourceType} · ${b.vocabulariesCount} word${b.vocabulariesCount == 1 ? '' : 's'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: b.isPublic ? 'Published' : 'Private',
                  child: IconButton(
                    icon: Icon(
                      b.isPublic ? Icons.public : Icons.lock_outline,
                      color: b.isPublic
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: () => _togglePublic(b),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(b),
                ),
              ],
            ),
            onTap: () => _openBucketWords(b),
          ),
        );
      },
    );
  }

  void _openBucketWords(Bucket bucket) {
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
