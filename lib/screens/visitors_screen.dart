import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

const _online = Color(0xFF34D399);

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  late Future<VisitorStats> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.visitors();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitors')),
      body: FutureBuilder<VisitorStats>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load visitor stats.');
          }

          final stats = snap.data ?? VisitorStats();
          final kpis = stats.kpis;

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
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
                      icon: Icons.circle,
                      iconColor: _online,
                      value: '${kpis['online'] ?? 0}',
                      label: 'Online now',
                    ),
                    _KpiTile(
                      icon: Icons.visibility_outlined,
                      value: '${kpis['today_views'] ?? 0}',
                      label: 'Views today',
                    ),
                    _KpiTile(
                      icon: Icons.person_outline,
                      value: '${kpis['today_visitors'] ?? 0}',
                      label: 'Visitors today',
                    ),
                    _KpiTile(
                      icon: Icons.fiber_new_outlined,
                      value: '${kpis['today_new'] ?? 0}',
                      label: 'New today',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  title: 'Last 30 days',
                  child: Column(
                    children: [
                      _StatRow(label: 'Views', count: kpis['month_views'] ?? 0),
                      _StatRow(label: 'Visitors', count: kpis['month_visitors'] ?? 0),
                      _StatRow(label: 'All-time views', count: kpis['total_views'] ?? 0),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ListCard(title: 'Top pages', rows: stats.topPages),
                const SizedBox(height: 12),
                _ListCard(title: 'Top referrers', rows: stats.topReferrers),
                const SizedBox(height: 12),
                _ListCard(title: 'Devices', rows: stats.devices),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _KpiTile({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.gold,
  });

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
          Icon(icon, size: 20, color: iconColor),
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

class _ListCard extends StatelessWidget {
  final String title;
  final List<LabelCount> rows;
  const _ListCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: title,
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No data yet.', style: TextStyle(color: AppColors.textMuted)),
            )
          : Column(
              children: [
                for (final row in rows) _StatRow(label: row.label, count: row.count),
              ],
            ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int count;
  const _StatRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
