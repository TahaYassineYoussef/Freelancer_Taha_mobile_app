import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late Future<List<InboxMessage>> _future;
  bool _unreadOnly = false;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.inbox();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: FutureBuilder<List<InboxMessage>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your inbox.');
          }

          final messages = snap.data ?? const <InboxMessage>[];
          final unread = messages.where((m) => !m.read).length;
          final visible = _unreadOnly ? messages.where((m) => !m.read).toList() : messages;

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: Column(
              children: [
                _FilterChips(
                  total: messages.length,
                  unread: unread,
                  unreadOnly: _unreadOnly,
                  onSelected: (v) => setState(() => _unreadOnly = v),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _Empty(isFiltered: _unreadOnly)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: visible.length,
                          itemBuilder: (_, i) => _MessageCard(
                            message: visible[i],
                            api: _api,
                            onChanged: _refresh,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final int total;
  final int unread;
  final bool unreadOnly;
  final ValueChanged<bool> onSelected;
  const _FilterChips({
    required this.total,
    required this.unread,
    required this.unreadOnly,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('All ($total)', !unreadOnly, () => onSelected(false)),
          const SizedBox(width: 8),
          _chip('Unread ($unread)', unreadOnly, () => onSelected(true)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => onTap(),
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.ink : Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: AppColors.ink700,
      selectedColor: AppColors.gold,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      showCheckmark: false,
    );
  }
}

class _MessageCard extends StatefulWidget {
  final InboxMessage message;
  final ApiService api;
  final Future<void> Function() onChanged;

  const _MessageCard({required this.message, required this.api, required this.onChanged});

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  bool _busy = false;

  InboxMessage get message => widget.message;

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
        title: const Text('Delete message?'),
        content: Text('The message from ${message.name} will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run(() => widget.api.deleteMessage(message.id));
  }

  @override
  Widget build(BuildContext context) {
    final dim = message.read;
    final subject = message.subject;

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
          // Reading is a one-way action, so only unread cards react to a tap.
          onTap: dim || _busy ? null : () => _run(() => widget.api.markMessageRead(message.id)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gold accent marks the unread ones.
              Container(width: 3, color: dim ? Colors.transparent : AppColors.gold),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.name,
                                  style: TextStyle(
                                    color: dim ? Colors.white70 : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.email,
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(message.createdAt),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          if (!dim) ...[
                            const SizedBox(width: 8),
                            Container(
                              margin: const EdgeInsets.only(top: 5),
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
                      if (subject != null && subject.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subject,
                          style: const TextStyle(
                              color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        message.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
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
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Color(0xFFF87171)),
                            tooltip: 'Delete',
                          ),
                        ),
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
  final bool isFiltered;
  const _Empty({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Text(
            isFiltered ? 'No unread messages.' : 'No messages yet.',
            style: const TextStyle(color: AppColors.textMuted),
          ),
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
