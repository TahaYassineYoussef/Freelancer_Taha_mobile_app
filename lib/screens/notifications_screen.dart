import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<NotificationFeed> _future;
  int _unread = 0;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.notifications();
    // The app bar action depends on the unread count, so mirror it into state.
    _future.then(
      (feed) {
        if (mounted && _unread != feed.unread) setState(() => _unread = feed.unread);
      },
      onError: (_) {/* the FutureBuilder renders the failure */},
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  /// Run an API action, surfacing failures and refreshing the feed after.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: () => _run(_api.markAllNotificationsRead),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: FutureBuilder<NotificationFeed>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your notifications.');
          }

          final feed = snap.data ?? NotificationFeed();

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: feed.items.isEmpty
                ? const _Empty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: feed.items.length,
                    itemBuilder: (_, i) => _NotificationCard(
                      item: feed.items[i],
                      onRead: () => _run(() => _api.markNotificationRead(feed.items[i].id)),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onRead;
  const _NotificationCard({required this.item, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final dim = item.read;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.ink700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: dim ? null : onRead,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gold accent marks the unread ones.
              Container(width: 3, color: dim ? Colors.transparent : AppColors.gold),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Glyph(icon: item.icon, dim: dim),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                color: dim ? Colors.white70 : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.message,
                              style: const TextStyle(
                                  color: AppColors.textMuted, height: 1.4, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _relativeTime(item.createdAt),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (!dim) ...[
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  final String? icon;
  final bool dim;
  const _Glyph({required this.icon, required this.dim});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon == null
          ? Icon(Icons.notifications_none,
              size: 18, color: dim ? AppColors.textMuted : AppColors.gold)
          : Text(icon!, style: const TextStyle(fontSize: 16)),
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

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Text('No notifications yet.', style: TextStyle(color: AppColors.textMuted)),
        ),
      ],
    );
  }
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
