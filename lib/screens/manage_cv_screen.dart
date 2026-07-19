import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

/// The six CV sections, in the order the website lists them. The key is the
/// counts key from the API; 'experiences' is labelled 'Experience'.
const _sections = <String, String>{
  'skills': 'Skills',
  'services': 'Services',
  'projects': 'Projects',
  'diplomas': 'Diplomas',
  'experiences': 'Experience',
  'internships': 'Internships',
};

class ManageCvScreen extends StatefulWidget {
  const ManageCvScreen({super.key});

  @override
  State<ManageCvScreen> createState() => _ManageCvScreenState();
}

class _ManageCvScreenState extends State<ManageCvScreen> {
  late Future<CvOverview> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.cv();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage CV')),
      body: FutureBuilder<CvOverview>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load your CV.');
          }

          final overview = snap.data ?? CvOverview();

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Keyed on the loaded values so a pull-to-refresh rebuilds the
                // controllers with the fresh profile instead of keeping stale text.
                _ProfileCard(
                  key: ValueKey(overview.profile.toString()),
                  profile: overview.profile,
                ),
                const SizedBox(height: 12),
                _SectionsCard(counts: overview.counts),
                const SizedBox(height: 12),
                const Text('Add and edit individual entries on the website.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

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
                  color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final Map<String, String> profile;
  const _ProfileCard({super.key, required this.profile});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  final _headline = TextEditingController();
  final _headlineFr = TextEditingController();
  final _headlineAr = TextEditingController();
  final _bio = TextEditingController();
  final _bioFr = TextEditingController();
  final _bioAr = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _headline.text = p['headline'] ?? '';
    _headlineFr.text = p['headline_fr'] ?? '';
    _headlineAr.text = p['headline_ar'] ?? '';
    _bio.text = p['bio'] ?? '';
    _bioFr.text = p['bio_fr'] ?? '';
    _bioAr.text = p['bio_ar'] ?? '';
    _location.text = p['location'] ?? '';
    _phone.text = p['phone'] ?? '';
  }

  @override
  void dispose() {
    _headline.dispose();
    _headlineFr.dispose();
    _headlineAr.dispose();
    _bio.dispose();
    _bioFr.dispose();
    _bioAr.dispose();
    _location.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final message = await context.read<AuthState>().api.updateCvProfile({
        'headline': _headline.text.trim(),
        'headline_fr': _headlineFr.text.trim(),
        'headline_ar': _headlineAr.text.trim(),
        'bio': _bio.text.trim(),
        'bio_fr': _bioFr.text.trim(),
        'bio_ar': _bioAr.text.trim(),
        'location': _location.text.trim(),
        'phone': _phone.text.trim(),
      });
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Profile',
      children: [
        TextField(
          controller: _headline,
          decoration: const InputDecoration(labelText: 'Headline (EN)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _headlineFr,
          decoration: const InputDecoration(labelText: 'Headline (FR)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _headlineAr,
          decoration: const InputDecoration(labelText: 'Headline (AR)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bio,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Bio (EN)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioFr,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Bio (FR)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioAr,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Bio (AR)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _location,
          decoration: const InputDecoration(labelText: 'Location'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save profile'),
          ),
        ),
      ],
    );
  }
}

class _SectionsCard extends StatelessWidget {
  final Map<String, int> counts;
  const _SectionsCard({required this.counts});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Sections',
      children: [
        for (final entry in _sections.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(entry.value,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                _Badge(text: '${counts[entry.key] ?? 0}'),
              ],
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
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
