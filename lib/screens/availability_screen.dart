import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late Future<List<DaySchedule>> _future;

  /// Kept beside the future so a save can swap the whole week in place without
  /// re-fetching (the API returns the full updated schedule).
  List<DaySchedule>? _days;

  /// The weekday currently being saved, so only that row locks up.
  int? _savingDay;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _days = null;
    _future = _api.availability();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _save(DaySchedule day) async {
    // Captured before the await — a refresh can rebuild this subtree.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingDay = day.day);
    try {
      final schedule = await _api.saveAvailability(day);
      if (mounted) setState(() => _days = schedule);
      messenger.showSnackBar(const SnackBar(content: Text('Availability saved.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingDay = null);
    }
  }

  Future<void> _pickTime(DaySchedule day, {required bool isStart}) async {
    final current = _parse(isStart ? day.startTime : day.endTime);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final value = _format(picked);
    await _save(DaySchedule(
      day: day.day,
      name: day.name,
      isOpen: day.isOpen,
      startTime: isStart ? value : day.startTime,
      endTime: isStart ? day.endTime : value,
    ));
  }

  Future<void> _toggle(DaySchedule day, bool isOpen) {
    return _save(DaySchedule(
      day: day.day,
      name: day.name,
      isOpen: isOpen,
      startTime: day.startTime,
      endTime: day.endTime,
    ));
  }

  /// Falls back to midnight rather than throwing if the API sends something odd.
  TimeOfDay _parse(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour % 24, minute: minute % 60);
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: FutureBuilder<List<DaySchedule>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your availability.');
          }

          final days = _days ?? snap.data ?? const <DaySchedule>[];

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Text('Clients can book calls inside these hours.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                for (final day in days)
                  _DayCard(
                    day: day,
                    saving: _savingDay == day.day,
                    // Any row saving locks the rest — the API replies with the
                    // whole week, so two in-flight saves could fight each other.
                    locked: _savingDay != null,
                    onToggle: (value) => _toggle(day, value),
                    onPickStart: () => _pickTime(day, isStart: true),
                    onPickEnd: () => _pickTime(day, isStart: false),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DaySchedule day;
  final bool saving;
  final bool locked;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DayCard({
    required this.day,
    required this.saving,
    required this.locked,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final canEditTimes = day.isOpen && !locked;

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
            children: [
              Expanded(
                child: Text(day.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Switch(
                value: day.isOpen,
                onChanged: locked ? null : onToggle,
                activeColor: AppColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TimeButton(
                label: 'Start',
                time: day.startTime,
                onPressed: canEditTimes ? onPickStart : null,
              ),
              const SizedBox(width: 10),
              _TimeButton(
                label: 'End',
                time: day.endTime,
                onPressed: canEditTimes ? onPickEnd : null,
              ),
            ],
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
            ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback? onPressed;

  const _TimeButton({required this.label, required this.time, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.white.withValues(alpha: enabled ? 0.16 : 0.06)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: enabled ? 1 : 0.4),
                    fontSize: 11)),
            const SizedBox(height: 2),
            Text(time,
                style: TextStyle(
                    color: (enabled ? AppColors.gold : AppColors.textMuted)
                        .withValues(alpha: enabled ? 1 : 0.4),
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        ),
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
