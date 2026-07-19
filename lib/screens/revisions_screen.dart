import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

class RevisionsScreen extends StatefulWidget {
  const RevisionsScreen({super.key});

  @override
  State<RevisionsScreen> createState() => _RevisionsScreenState();
}

class _RevisionsScreenState extends State<RevisionsScreen> {
  late Future<List<Revision>> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.revisions();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisions')),
      body: FutureBuilder<List<Revision>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load change requests.');
          }

          final revisions = snap.data ?? const <Revision>[];

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: revisions.isEmpty
                ? const _Empty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: revisions.length,
                    itemBuilder: (_, i) => _RevisionCard(revision: revisions[i]),
                  ),
          );
        },
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  final Revision revision;
  const _RevisionCard({required this.revision});

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final note = revision.note;
    final previousNote = revision.previousNote;
    final hasPrevious = (previousNote != null && previousNote.isNotEmpty) ||
        revision.previousLink != null ||
        revision.previousFile != null;

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
          Text(revision.title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          if (revision.client != null) ...[
            const SizedBox(height: 4),
            Text('from ${revision.client}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          if (revision.deadline != null || revision.budget != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (revision.deadline != null)
                  _Chip(icon: Icons.event_outlined, text: revision.deadline!),
                if (revision.budget != null)
                  _Chip(icon: Icons.payments_outlined, text: revision.budget!),
              ],
            ),
          ],
          if (note != null && note.isNotEmpty)
            _Note(
              icon: Icons.loop,
              label: 'Changes requested',
              body: note,
              color: AppColors.gold,
            ),
          if (hasPrevious) ...[
            const SizedBox(height: 12),
            const Text('Previous delivery',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            if (previousNote != null && previousNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(previousNote,
                  style: const TextStyle(color: Colors.white70, height: 1.4)),
            ],
            if (revision.previousLink != null || revision.previousFile != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (revision.previousLink != null)
                    OutlinedButton.icon(
                      onPressed: () => _open(revision.previousLink!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open link'),
                    ),
                  if (revision.previousFile != null)
                    OutlinedButton.icon(
                      onPressed: () => _open(revision.previousFile!),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
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
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Text('No change requests.', style: TextStyle(color: AppColors.textMuted)),
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
