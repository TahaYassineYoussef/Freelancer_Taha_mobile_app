import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../state/auth.dart';
import '../theme.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late Future<Freelancer?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthState>().api.portfolio();
  }

  Future<void> _refresh() async {
    setState(() => _future = context.read<AuthState>().api.portfolio());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Freelancer?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        if (snap.hasError || snap.data == null) {
          return _Retry(onRetry: _refresh, message: 'Could not load the portfolio.');
        }
        final f = snap.data!;
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              _Hero(f: f),
              if (f.bio != null) ...[
                const SizedBox(height: 24),
                const _SectionTitle('About'),
                Text(f.bio!, style: const TextStyle(color: Colors.white70, height: 1.5)),
              ],
              _contact(f),
              if (f.skills.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _SectionTitle('Skills'),
                ...f.skills.map((s) => _SkillBar(s)),
              ],
              if (f.services.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _SectionTitle('Services'),
                ...f.services.map((s) => _Card(
                      title: s.title,
                      subtitle: s.price != null ? 'From \$${s.price}' : null,
                      body: s.description,
                    )),
              ],
              if (f.projects.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _SectionTitle('Projects'),
                ...f.projects.map((p) => _ProjectCard(p)),
              ],
              if (f.experiences.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _SectionTitle('Experience'),
                ...f.experiences.map((e) => _Card(
                      title: e.position,
                      subtitle: e.company,
                      meta: _range(e.startDate, e.endDate, e.isCurrent),
                      body: e.description,
                    )),
              ],
              if (f.internships.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _SectionTitle('Internships'),
                ...f.internships.map((e) => _Card(
                      title: e.position,
                      subtitle: e.company,
                      meta: _range(e.startDate, e.endDate, false),
                      body: e.description,
                    )),
              ],
              if (f.diplomas.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _SectionTitle('Education'),
                ...f.diplomas.map((d) => _Card(
                      title: d.title,
                      subtitle: d.institution,
                      meta: [d.startYear, d.endYear].where((e) => e != null).join(' — '),
                      body: d.description,
                    )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _contact(Freelancer f) {
    final rows = <Widget>[];
    void add(IconData i, String? v) {
      if (v != null && v.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Icon(i, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(child: Text(v, style: const TextStyle(color: Colors.white70))),
          ]),
        ));
      }
    }

    add(Icons.location_on_outlined, f.location);
    add(Icons.phone_outlined, f.phone);
    add(Icons.mail_outline, f.email);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 12), child: Column(children: rows));
  }

  String _range(String? a, String? b, bool current) {
    String fmt(String? d) => d == null ? '' : d.substring(0, 7);
    final from = fmt(a);
    final to = current ? 'Present' : fmt(b);
    return [from, to].where((e) => e.isNotEmpty).join(' — ');
  }
}

class _Hero extends StatelessWidget {
  final Freelancer f;
  const _Hero({required this.f});

  @override
  Widget build(BuildContext context) {
    final initials = f.name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join();
    final initialsFallback = Container(
      color: AppColors.ink700,
      alignment: Alignment.center,
      child: Text(initials,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.gold)),
    );
    // Bundled photo of Taha — always available (no network / CORS needed).
    final bundledPhoto = Image.asset(
      'assets/taha.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => initialsFallback,
    );
    // Uploaded avatar first; on any failure fall back to the bundled photo.
    final Widget photo = f.avatarUrl != null
        ? Image.network(
            f.avatarUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => bundledPhoto,
          )
        : bundledPhoto;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
          child: ClipOval(
            child: SizedBox(width: 104, height: 104, child: photo),
          ),
        ),
        const SizedBox(height: 14),
        Text(f.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        if (f.headline != null) ...[
          const SizedBox(height: 4),
          Text(f.headline!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gold)),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Container(height: 3, width: 40, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(3))),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final Skill s;
  const _SkillBar(this.s);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.name, style: const TextStyle(color: Colors.white)),
              Text('${s.level}%', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s.level / 100,
              minHeight: 7,
              backgroundColor: AppColors.ink600,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? meta;
  final String? body;
  const _Card({required this.title, this.subtitle, this.meta, this.body});

  @override
  Widget build(BuildContext context) {
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
                child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              if (meta != null && meta!.isNotEmpty)
                Text(meta!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
          ],
          if (body != null && body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body!, style: const TextStyle(color: Colors.white70, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project p;
  const _ProjectCard(this.p);

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static const _placeholder = SizedBox(
    height: 160,
    width: double.infinity,
    child: ColoredBox(
      color: AppColors.ink600,
      child: Icon(Icons.image_outlined, color: AppColors.textMuted, size: 40),
    ),
  );

  /// Show [primary]; if it fails to load (e.g. a self-hosted image blocked by
  /// CORS on web), fall back to the YouTube [fallback] thumbnail, then a
  /// neutral placeholder — so a card never renders half-broken.
  Widget _thumbnail(String primary, String? fallback) {
    Widget net(String url, ImageErrorWidgetBuilder onError) => Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: onError,
        );
    return net(primary, (_, __, ___) {
      if (fallback != null && fallback != primary) {
        return net(fallback, (_, __, ___) => _placeholder);
      }
      return _placeholder;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.ink700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.thumbnailUrl != null)
            GestureDetector(
              onTap: p.watchUrl != null ? () => _open(p.watchUrl!) : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _thumbnail(p.thumbnailUrl!, youtubeThumbnail(p.liveUrl)),
                  if (p.watchUrl != null)
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                if (p.techStack != null) ...[
                  const SizedBox(height: 4),
                  Text(p.techStack!, style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                ],
                if (p.description != null) ...[
                  const SizedBox(height: 8),
                  Text(p.description!, style: const TextStyle(color: Colors.white70, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  final VoidCallback onRetry;
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
