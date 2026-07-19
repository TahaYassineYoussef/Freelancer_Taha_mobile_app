import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

const _statusColors = {
  'completed': Color(0xFF34D399),
  'pending': AppColors.gold,
  'failed': Color(0xFFF87171),
};

const _providerLabels = {
  'paypal': 'PayPal',
  'd17': 'D17',
};

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<PaymentsPage> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.freelancerPayments();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Paid')),
      body: FutureBuilder<PaymentsPage>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your payments.');
          }

          final page = snap.data ?? PaymentsPage();
          final payments = page.payments;

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _Stats(page: page),
                const SizedBox(height: 16),
                if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No payments yet.',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  for (final p in payments)
                    _PaymentCard(payment: p, api: _api, onChanged: _refresh),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final PaymentsPage page;
  const _Stats({required this.page});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          value: '${page.totalReceived.toStringAsFixed(2)} ${page.currency}',
          label: 'Total received',
        ),
        const SizedBox(width: 10),
        _StatTile(value: '${page.completedCount}', label: 'Completed'),
        const SizedBox(width: 10),
        _StatTile(value: '${page.pendingCount}', label: 'Pending'),
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

class _PaymentCard extends StatefulWidget {
  final PaymentRow payment;
  final ApiService api;
  final Future<void> Function() onChanged;

  const _PaymentCard({required this.payment, required this.api, required this.onChanged});

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _busy = false;

  PaymentRow get payment => widget.payment;

  /// Review the payment, surfacing the API's message and refreshing the list after.
  Future<void> _run(String status) async {
    // Captured before the await — the card can be rebuilt away by the refresh.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await widget.api.reviewPayment(payment.id, status);
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
    final color = _statusColors[payment.status] ?? AppColors.textMuted;
    final provider = _providerLabels[payment.provider.toLowerCase()] ??
        payment.provider.toUpperCase();
    final reference = payment.reference;

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
                child: Text(payment.taskTitle ?? 'Payment',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _Badge(text: payment.status, color: color),
            ],
          ),
          if (payment.clientName != null) ...[
            const SizedBox(height: 4),
            Text('from ${payment.clientName}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${payment.amount} ${payment.currency}',
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 10),
              _Badge(text: provider, color: AppColors.textMuted),
            ],
          ),
          if (reference != null && reference.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Ref $reference',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          if (payment.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(payment.createdAt!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
            )
          else if (payment.isPending)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ElevatedButton(
                    onPressed: () => _run('completed'),
                    child: const Text('Confirm'),
                  ),
                  OutlinedButton(
                    onPressed: () => _run('failed'),
                    child: const Text('Reject'),
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
