import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

const _statusColors = {
  'open': Color(0xFF60A5FA),
  'in_progress': AppColors.gold,
  'completed': Color(0xFF34D399),
  'declined': Color(0xFFF87171),
};

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late Future<List<Task>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AuthState>().api.tasks();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _openPostSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PostTaskSheet(),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isFreelancer = context.read<AuthState>().user?.isFreelancer ?? false;
    return Scaffold(
      floatingActionButton: isFreelancer
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              onPressed: _openPostSheet,
              icon: const Icon(Icons.add),
              label: const Text('Post a task', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: FutureBuilder<List<Task>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}', style: const TextStyle(color: AppColors.textMuted)));
          }
          final tasks = snap.data ?? [];
          if (tasks.isEmpty) {
            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No tasks yet.', style: TextStyle(color: AppColors.textMuted))),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: tasks.length,
              itemBuilder: (_, i) => _TaskCard(tasks[i], isFreelancer: isFreelancer),
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final bool isFreelancer;
  const _TaskCard(this.task, {required this.isFreelancer});

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[task.status] ?? Colors.grey;
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
                child: Text(task.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _pill(task.status.replaceAll('_', ' '), color),
            ],
          ),
          if (isFreelancer && task.clientName != null) ...[
            const SizedBox(height: 4),
            Text('From ${task.clientName}', style: const TextStyle(color: AppColors.gold, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Text(task.description, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (task.category != null) _meta(Icons.folder_outlined, task.category!),
              if (task.budget != null) _meta(Icons.attach_money, task.budget!),
              if (task.deadline != null) _meta(Icons.event_outlined, task.deadline!),
              if (task.isPaid) _pill('Paid', const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData i, String v) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(v, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _PostTaskSheet extends StatefulWidget {
  const _PostTaskSheet();

  @override
  State<_PostTaskSheet> createState() => _PostTaskSheetState();
}

class _PostTaskSheetState extends State<_PostTaskSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _category = TextEditingController();
  final _budget = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _category.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      setState(() => _error = 'Title and description are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().api.createTask(
            title: _title.text.trim(),
            description: _desc.text.trim(),
            category: _category.text.trim(),
            budget: _budget.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Post a task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          TextField(controller: _title, decoration: const InputDecoration(hintText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe what you need…')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _category, decoration: const InputDecoration(hintText: 'Category'))),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Budget'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : const Text('POST TASK'),
          ),
        ],
      ),
    );
  }
}
