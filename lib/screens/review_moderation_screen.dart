import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

const _published = Color(0xFF34D399);

const _filterLabels = {
  'all': 'All',
  'pending': 'Pending',
  'published': 'Published',
};

class ReviewModerationScreen extends StatefulWidget {
  const ReviewModerationScreen({super.key});

  @override
  State<ReviewModerationScreen> createState() => _ReviewModerationScreenState();
}

class _ReviewModerationScreenState extends State<ReviewModerationScreen> {
  late Future<List<ReviewRow>> _future;
  String _filter = 'all';

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.freelancerReviews();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  List<ReviewRow> _visible(List<ReviewRow> reviews) {
    if (_filter == 'pending') return reviews.where((r) => !r.approved).toList();
    if (_filter == 'published') return reviews.where((r) => r.approved).toList();
    return reviews;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: FutureBuilder<List<ReviewRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your reviews.');
          }

          final reviews = snap.data ?? const <ReviewRow>[];
          final visible = _visible(reviews);

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: Column(
              children: [
                _FilterChips(
                  counts: {
                    'all': reviews.length,
                    'pending': reviews.where((r) => !r.approved).length,
                    'published': reviews.where((r) => r.approved).length,
                  },
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _Empty(isFiltered: reviews.isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: visible.length,
                          itemBuilder: (_, i) => _ReviewCard(
                            review: visible[i],
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
  final Map<String, int> counts;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterChips({required this.counts, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final keys = _filterLabels.keys.toList();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final key = keys[i];
          final count = counts[key] ?? 0;
          final isSelected = key == selected;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelected(key),
            label: Text('${_filterLabels[key]} ($count)'),
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
        },
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final ReviewRow review;
  final ApiService api;
  final Future<void> Function() onChanged;

  const _ReviewCard({required this.review, required this.api, required this.onChanged});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _busy = false;

  ReviewRow get review => widget.review;

  /// Run a moderation call, showing its result message and refreshing the list.
  Future<void> _run(Future<String> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await action();
      messenger.showSnackBar(SnackBar(content: Text(message)));
      await widget.onChanged();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _Stars(rating: review.rating),
              const Spacer(),
              _Badge(
                text: review.approved ? 'Published' : 'Pending',
                color: review.approved ? _published : AppColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(review.body, style: const TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.author ?? 'Anonymous',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    if (review.roleTitle != null && review.roleTitle!.isNotEmpty)
                      Text(review.roleTitle!,
                          style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                  ],
                ),
              ),
              Text(_relativeTime(review.createdAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: review.approved
                  ? OutlinedButton(
                      onPressed: () => _run(() => widget.api.moderateReview(review.id, false)),
                      child: const Text('Hide'),
                    )
                  : ElevatedButton(
                      onPressed: () => _run(() => widget.api.moderateReview(review.id, true)),
                      child: const Text('Publish'),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Server timestamps arrive as ISO-8601 strings; anything unparseable shows blank.
String _relativeTime(String? iso) {
  if (iso == null) return '';
  final at = DateTime.tryParse(iso);
  if (at == null) return '';

  final diff = DateTime.now().difference(at.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  final local = at.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

class _Stars extends StatelessWidget {
  final int rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: AppColors.gold,
          size: 16,
        ),
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
            isFiltered ? 'No reviews match this filter.' : 'No reviews yet.',
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
