import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

const _statusColors = {
  'delivered': Color(0xFFA78BFA),
  'completed': Color(0xFF34D399),
};

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  late Future<List<Delivery>> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.deliveries();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deliveries')),
      body: FutureBuilder<List<Delivery>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your deliveries.');
          }

          final deliveries = snap.data ?? const <Delivery>[];

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: deliveries.isEmpty
                ? const _Empty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: deliveries.length,
                    itemBuilder: (_, i) => _DeliveryCard(delivery: deliveries[i]),
                  ),
          );
        },
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Delivery delivery;
  const _DeliveryCard({required this.delivery});

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[delivery.status] ?? AppColors.textMuted;
    final note = delivery.note;

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
                child: Text(delivery.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _Badge(text: delivery.status, color: color),
            ],
          ),
          if (delivery.deliveredAt != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('Delivered ${delivery.deliveredAt}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(note, style: const TextStyle(color: Colors.white70, height: 1.4)),
          ],
          if (delivery.fileUrl != null || delivery.link != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (delivery.fileUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(delivery.fileUrl!),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                  ),
                if (delivery.link != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(delivery.link!),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open link'),
                  ),
              ],
            ),
          ],
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

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Text('Nothing delivered yet.', style: TextStyle(color: AppColors.textMuted)),
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
