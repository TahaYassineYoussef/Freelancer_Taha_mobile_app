import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';
import 'activity_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<FreelancerDashboard> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.freelancerDashboard();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthState>().user?.name ?? 'there';

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<FreelancerDashboard>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your dashboard.');
          }

          final data = snap.data ?? FreelancerDashboard(kpis: FreelancerKpis());
          final kpis = data.kpis;
          final counts = data.counts;

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text('Hi $name',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Your freelance dashboard overview',
                    style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // Tall enough for icon + value + label at large text scales;
                  // 1.5 clipped the label by a few pixels.
                  childAspectRatio: 1.25,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _KpiTile(
                      icon: Icons.payments_outlined,
                      value: '${_money(kpis.revenue)} ${kpis.currency}',
                      label: 'This Month Revenue',
                    ),
                    _KpiTile(
                      icon: Icons.assignment_turned_in_outlined,
                      value: '${kpis.accepted}',
                      label: 'Tasks Accepted',
                    ),
                    _KpiTile(
                      icon: Icons.schedule,
                      value: kpis.onTimePct == null ? '—' : '${kpis.onTimePct}%',
                      label: 'Delivered On Time',
                    ),
                    _KpiTile(
                      icon: Icons.people_outline,
                      value: '${kpis.clients}',
                      label: 'Clients',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ActivityChart(title: 'Task Progress', series: data.chart),
                _Card(
                  title: 'Queues',
                  child: Column(
                    children: [
                      _QueueRow(label: 'Open tasks', count: counts['open'] ?? 0),
                      _QueueRow(label: 'In progress', count: counts['in_progress'] ?? 0),
                      _QueueRow(label: 'Delivered', count: counts['delivered'] ?? 0),
                      _QueueRow(label: 'Revisions requested', count: counts['revisions'] ?? 0),
                      _QueueRow(
                          label: 'Payments to confirm', count: counts['pending_payments'] ?? 0),
                      _QueueRow(
                          label: 'Reviews to moderate', count: counts['pending_reviews'] ?? 0),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  title: 'Latest Clients',
                  child: data.latestClients.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No clients yet.',
                              style: TextStyle(color: AppColors.textMuted)),
                        )
                      : Column(
                          children: [
                            for (final client in data.latestClients) _ClientRow(client: client),
                          ],
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

/// Whole amounts read better without the ".0" Dart prints for doubles.
String _money(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _KpiTile({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 2),
          // Flexible so a long label or a large system font shrinks the text
          // instead of overflowing the fixed-ratio grid cell.
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final String label;
  final int count;
  const _QueueRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final color = active ? AppColors.gold : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final LatestClient client;
  const _ClientRow({required this.client});

  @override
  Widget build(BuildContext context) {
    final initial = client.name.isEmpty ? '?' : client.name.characters.first.toUpperCase();
    final paid = client.paid;
    final badgeColor = paid ? const Color(0xFF34D399) : AppColors.gold;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
            child: Text(initial,
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(client.task,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Badge(text: paid ? 'Paid' : 'Awaiting', color: badgeColor),
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
