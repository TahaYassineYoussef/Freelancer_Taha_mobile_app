import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

const _statusColors = {
  'pending': AppColors.gold,
  'confirmed': Color(0xFF34D399),
  'declined': Color(0xFFF87171),
  'cancelled': AppColors.textMuted,
};

const _statusLabels = {
  'pending': 'Pending',
  'confirmed': 'Confirmed',
  'declined': 'Declined',
  'cancelled': 'Cancelled',
};

// Local name tables keep the date formatting dependency-free (no intl).
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 'Mon 21 Jul · 14:00', or '—' when the API sent no/unparsable timestamp.
String _formatWhen(String? iso) {
  if (iso == null) return '—';
  final at = DateTime.tryParse(iso);
  if (at == null) return '—';
  final local = at.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${_weekdays[local.weekday - 1]} ${local.day} ${_months[local.month - 1]} · $hh:$mm';
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late Future<BookingsPage> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.bookings();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: FutureBuilder<BookingsPage>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your bookings.');
          }

          final page = snap.data ?? BookingsPage();
          final bookings = page.bookings;

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    _StatTile(value: '${page.pending}', label: 'Pending'),
                    const SizedBox(width: 10),
                    _StatTile(value: '${page.confirmed}', label: 'Confirmed'),
                  ],
                ),
                const SizedBox(height: 16),
                if (bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No bookings yet.',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  for (final b in bookings)
                    _BookingCard(booking: b, api: _api, onChanged: _refresh),
              ],
            ),
          );
        },
      ),
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

class _BookingCard extends StatefulWidget {
  final BookingRow booking;
  final ApiService api;
  final Future<void> Function() onChanged;

  const _BookingCard({required this.booking, required this.api, required this.onChanged});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _busy = false;

  BookingRow get booking => widget.booking;

  /// Review the booking, surfacing the API's message and refreshing the list after.
  Future<void> _run(String status) async {
    // Captured before the await — the card can be rebuilt away by the refresh.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await widget.api.reviewBooking(booking.id, status);
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
    final status = booking.status.toLowerCase();
    final color = _statusColors[status] ?? AppColors.textMuted;
    final topic = booking.topic;
    final note = booking.note;
    final email = booking.email;

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
              Expanded(
                child: Text(_formatWhen(booking.startsAt),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _Badge(text: _statusLabels[status] ?? booking.status, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text('${booking.durationMin} min',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Text(booking.client ?? 'Unknown client',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          if (topic != null && topic.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(topic,
                style: const TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
            )
          else if (booking.isPending)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ElevatedButton(
                    onPressed: () => _run('confirmed'),
                    child: const Text('Confirm'),
                  ),
                  OutlinedButton(
                    onPressed: () => _run('declined'),
                    child: const Text('Decline'),
                  ),
                ],
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
