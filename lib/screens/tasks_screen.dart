import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';
import 'payment_sheet.dart';

const _statusColors = {
  'open': Color(0xFF60A5FA),
  'in_progress': AppColors.gold,
  'delivered': Color(0xFFA78BFA),
  'completed': Color(0xFF34D399),
  'declined': Color(0xFFF87171),
};

const _statusLabels = {
  'all': 'All',
  'open': 'Open',
  'in_progress': 'In progress',
  'delivered': 'Delivered',
  'completed': 'Completed',
  'declined': 'Declined',
};

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late Future<TaskPage> _future;
  PaymentConfig? _payments;
  String _filter = 'all';
  String _search = '';

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPaymentConfig();
  }

  void _load() {
    _future = _api.tasks();
  }

  /// Which payment methods the freelancer has enabled. Failure is non-fatal —
  /// the task list still works, just without pay buttons.
  Future<void> _loadPaymentConfig() async {
    try {
      final config = await _api.paymentConfig();
      if (mounted) setState(() => _payments = config);
    } catch (_) {/* payments simply stay hidden */}
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

  List<Task> _visible(List<Task> tasks) {
    final q = _search.trim().toLowerCase();
    return tasks.where((t) {
      if (_filter != 'all' && t.status != _filter) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          (t.category?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isFreelancer = context.read<AuthState>().user?.isFreelancer ?? false;
    return Scaffold(
      floatingActionButton: isFreelancer
          ? null
          : FloatingActionButton.extended(
              onPressed: _openPostSheet,
              icon: const Icon(Icons.add),
              label: const Text('Post a task'),
            ),
      body: FutureBuilder<TaskPage>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your tasks.');
          }

          final page = snap.data ?? TaskPage(tasks: const []);
          final visible = _visible(page.tasks);

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: Column(
              children: [
                _SearchField(onChanged: (v) => setState(() => _search = v)),
                _FilterChips(
                  counts: page.counts,
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _Empty(isFiltered: _filter != 'all' || _search.isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: visible.length,
                          itemBuilder: (_, i) => _TaskCard(
                            task: visible[i],
                            isFreelancer: isFreelancer,
                            payments: _payments,
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

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Search tasks…',
          prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
          isDense: true,
        ),
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
    // Only offer a status that actually has tasks (plus "All").
    final keys = _statusLabels.keys.where((k) => k == 'all' || (counts[k] ?? 0) > 0).toList();

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
            label: Text('${_statusLabels[key]} ($count)'),
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

class _TaskCard extends StatefulWidget {
  final Task task;
  final bool isFreelancer;
  final PaymentConfig? payments;
  final ApiService api;
  final Future<void> Function() onChanged;

  const _TaskCard({
    required this.task,
    required this.isFreelancer,
    required this.payments,
    required this.api,
    required this.onChanged,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _busy = false;

  Task get task => widget.task;

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

  Future<void> _approve() => _run(() => widget.api.approveTask(task.id));

  Future<void> _requestChanges() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _RequestChangesDialog(),
    );
    if (note == null) return;
    await _run(() => widget.api.requestChanges(task.id, note));
  }

  Future<void> _deliver() async {
    final result = await showModalBottomSheet<({String note, String link})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DeliverSheet(task: task),
    );
    if (result == null) return;
    await _run(() => widget.api.deliverTask(task.id, note: result.note, link: result.link));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ink800,
        title: const Text('Remove task?'),
        content: Text('“${task.title}” will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run(() => widget.api.deleteTask(task.id));
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[task.status] ?? AppColors.textMuted;

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
                child: Text(task.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _Badge(text: _statusLabels[task.status] ?? task.status, color: color),
            ],
          ),
          if (widget.isFreelancer && task.clientName != null) ...[
            const SizedBox(height: 4),
            Text('from ${task.clientName}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Text(task.description, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (task.category != null) _Chip(icon: Icons.folder_outlined, text: task.category!),
              if (task.budget != null) _Chip(icon: Icons.payments_outlined, text: task.budget!),
              if (task.deadline != null) _Chip(icon: Icons.event_outlined, text: task.deadline!),
              if (task.isPaid) const _Badge(text: 'Paid', color: Color(0xFF34D399)),
              if (task.pendingPayment)
                const _Badge(text: 'Payment pending', color: AppColors.gold),
            ],
          ),
          if (task.revisionNote != null && task.revisionNote!.isNotEmpty)
            _Note(
              icon: Icons.loop,
              label: 'Changes requested',
              body: task.revisionNote!,
              color: AppColors.gold,
            ),
          if (task.hasDelivery) _delivery(),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
            )
          else
            _actions(),
        ],
      ),
    );
  }

  Widget _delivery() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ink600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFFA78BFA)),
              SizedBox(width: 6),
              Text('Delivery',
                  style: TextStyle(
                      color: Color(0xFFA78BFA), fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          if (task.deliverableNote != null && task.deliverableNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(task.deliverableNote!,
                style: const TextStyle(color: Colors.white70, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (task.deliverableUrl != null)
                OutlinedButton.icon(
                  onPressed: () => _open(task.deliverableUrl!),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                ),
              if (task.deliverableLink != null)
                OutlinedButton.icon(
                  onPressed: () => _open(task.deliverableLink!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open link'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final children = <Widget>[];

    if (widget.isFreelancer) {
      if (task.status == 'open') {
        children.addAll([
          ElevatedButton(onPressed: () => _run(() => widget.api.acceptTask(task.id)), child: const Text('Accept')),
          OutlinedButton(onPressed: () => _run(() => widget.api.declineTask(task.id)), child: const Text('Decline')),
        ]);
      }
      // Re-delivering is allowed, so a delivered task keeps the button.
      if (task.status == 'in_progress' || task.status == 'delivered') {
        children.add(
          ElevatedButton.icon(
            onPressed: _deliver,
            icon: const Icon(Icons.upload_outlined, size: 18),
            label: Text(task.status == 'delivered' ? 'Re-deliver' : 'Deliver work'),
          ),
        );
      }
    } else {
      if (task.status == 'delivered') {
        children.addAll([
          ElevatedButton(onPressed: _approve, child: const Text('Approve')),
          OutlinedButton(onPressed: _requestChanges, child: const Text('Request changes')),
        ]);
      }
      children.add(
        TextButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF87171)),
          label: const Text('Delete', style: TextStyle(color: Color(0xFFF87171))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(spacing: 8, runSpacing: 6, children: children),
          ),
        // Pay buttons only for the client, and only when a method is enabled.
        if (!widget.isFreelancer && widget.payments != null)
          PaymentButtons(
            task: task,
            config: widget.payments!,
            api: widget.api,
            onPaid: widget.onChanged,
          ),
      ],
    );
  }
}

/// Sends work to the client: a link and/or a note. The API also accepts a file
/// upload, which the web app handles — on mobile a link keeps it one step.
class _DeliverSheet extends StatefulWidget {
  final Task task;
  const _DeliverSheet({required this.task});

  @override
  State<_DeliverSheet> createState() => _DeliverSheetState();
}

class _DeliverSheetState extends State<_DeliverSheet> {
  late final TextEditingController _note =
      TextEditingController(text: widget.task.deliverableNote ?? '');
  late final TextEditingController _link =
      TextEditingController(text: widget.task.deliverableLink ?? '');
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    _link.dispose();
    super.dispose();
  }

  void _submit() {
    final link = _link.text.trim();
    if (link.isEmpty) {
      setState(() => _error = 'Paste a link to the finished work.');
      return;
    }
    if (Uri.tryParse(link)?.hasScheme != true) {
      setState(() => _error = 'Enter a full URL, including https://');
      return;
    }
    Navigator.pop(context, (note: _note.text.trim(), link: link));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deliver “${widget.task.title}”',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('The client is notified and can approve it or ask for changes.',
                style: TextStyle(color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link to the work',
                hintText: 'https://…',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'What you delivered, how to run it…',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _submit, child: const Text('Send delivery')),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestChangesDialog extends StatefulWidget {
  const _RequestChangesDialog();

  @override
  State<_RequestChangesDialog> createState() => _RequestChangesDialogState();
}

class _RequestChangesDialogState extends State<_RequestChangesDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.ink800,
      title: const Text('Request changes'),
      content: TextField(
        controller: _note,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'What should Taha change?',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String label;
  final String body;
  final Color color;
  const _Note({required this.icon, required this.label, required this.body, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
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
            isFiltered ? 'No tasks match this filter.' : 'No tasks yet.',
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

class _PostTaskSheet extends StatefulWidget {
  const _PostTaskSheet();

  @override
  State<_PostTaskSheet> createState() => _PostTaskSheetState();
}

class _PostTaskSheetState extends State<_PostTaskSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _budget = TextEditingController();
  DateTime? _deadline;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDate: _deadline ?? now,
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  String? get _deadlineIso => _deadline == null
      ? null
      : '${_deadline!.year.toString().padLeft(4, '0')}-'
          '${_deadline!.month.toString().padLeft(2, '0')}-'
          '${_deadline!.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().api.createTask(
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category.text.trim(),
            budget: _budget.text.trim(),
            deadline: _deadlineIso,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Post a task',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 16),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'At least 15 characters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Budget (optional)'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Deadline (optional)'),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      _deadlineIso ?? 'Pick a date',
                      style: TextStyle(
                          color: _deadline == null ? AppColors.textMuted : Colors.white),
                    ),
                    const Spacer(),
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
