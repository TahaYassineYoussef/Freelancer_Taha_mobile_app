import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

const _red = Color(0xFFF87171);

/// Scam-ish categories read red, tone problems gold, anything else stays muted.
const _categoryColors = {
  'scam': _red,
  'spam': _red,
  'profanity': AppColors.gold,
  'insult': AppColors.gold,
};

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  late Future<BlockedPage> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.blocked();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked')),
      body: FutureBuilder<BlockedPage>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load the blocked log.');
          }

          final page = snap.data ?? BlockedPage();
          final logs = page.logs;

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _Stats(stats: page.stats),
                const SizedBox(height: 16),
                if (logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('Nothing has been blocked.',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  for (final log in logs)
                    _LogCard(entry: log, api: _api, onChanged: _refresh),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final Map<String, int> stats;
  const _Stats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(value: '${stats['total'] ?? 0}', label: 'Total'),
        const SizedBox(width: 10),
        _StatTile(value: '${stats['scam'] ?? 0}', label: 'Scam'),
        const SizedBox(width: 10),
        _StatTile(value: '${stats['profanity'] ?? 0}', label: 'Profanity'),
        const SizedBox(width: 10),
        _StatTile(value: '${stats['by_ai'] ?? 0}', label: 'By AI'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.ink700,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatefulWidget {
  final BlockedEntry entry;
  final ApiService api;
  final Future<void> Function() onChanged;

  const _LogCard({required this.entry, required this.api, required this.onChanged});

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _busy = false;

  BlockedEntry get entry => widget.entry;

  /// Run an API action, surfacing failures and refreshing the list after.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ink800,
        title: const Text('Delete log entry?'),
        content: const Text('This blocked submission will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run(() => widget.api.deleteBlocked(entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final category = entry.category;
    final color = _categoryColors[(category ?? '').toLowerCase()] ?? AppColors.textMuted;
    final author = entry.author;
    final content = entry.content;
    final reason = entry.reason;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(text: category ?? 'blocked', color: color),
              const Spacer(),
              Text(
                _relativeTime(entry.createdAt),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          if (entry.detectedBy != null && entry.detectedBy!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('detected by ${entry.detectedBy}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          if (author != null && author.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(author,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
          if (content != null && content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(
                  color: AppColors.textMuted, fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, size: 20, color: _red),
                tooltip: 'Delete',
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// "just now" / "5m ago" / "3h ago" / "2d ago", falling back to the date.
String _relativeTime(String? iso) {
  if (iso == null) return '';
  final at = DateTime.tryParse(iso);
  if (at == null) return '';

  final diff = DateTime.now().difference(at.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  final d = at.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _Retry extends StatelessWidget {
  final Future<void> Function() onRetry;
  final String message;
  const _Retry({required this.onRetry, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
