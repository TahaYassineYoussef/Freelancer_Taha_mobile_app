import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

/// Where the freelancer receives money.
///
/// The two switches only show or hide each method for clients — credentials
/// stay saved either way, matching the web Payment Settings page.
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  late Future<PaymentSettings> _future;

  ApiService get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _api.paymentSettings();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Settings')),
      body: FutureBuilder<PaymentSettings>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return _Retry(onRetry: _refresh, message: 'Could not load payment settings.');
          }

          final settings = snap.data ?? PaymentSettings();

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _refresh,
            // Keyed on the loaded values so a refresh rebuilds the fields with
            // fresh text instead of keeping stale input.
            child: _Form(key: ValueKey(settings.hashCode), settings: settings, api: _api),
          );
        },
      ),
    );
  }
}

class _Form extends StatefulWidget {
  final PaymentSettings settings;
  final ApiService api;
  const _Form({super.key, required this.settings, required this.api});

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _paypalEmail = TextEditingController(text: widget.settings.paypalEmail);
  late final _paypalClientId = TextEditingController(text: widget.settings.paypalClientId);
  late final _d17Number = TextEditingController(text: widget.settings.d17Number);
  late bool _paypalEnabled = widget.settings.paypalEnabled;
  late bool _d17Enabled = widget.settings.d17Enabled;
  bool _saving = false;

  @override
  void dispose() {
    _paypalEmail.dispose();
    _paypalClientId.dispose();
    _d17Number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await widget.api.savePaymentSettings(
        paypalEmail: _paypalEmail.text.trim(),
        paypalClientId: _paypalClientId.text.trim(),
        paypalEnabled: _paypalEnabled,
        d17Number: _d17Number.text.trim(),
        d17Enabled: _d17Enabled,
      );
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Card(
          title: 'PayPal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Toggle(
                label: 'Show PayPal to clients',
                value: _paypalEnabled,
                onChanged: (v) => setState(() => _paypalEnabled = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _paypalEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'PayPal email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paypalClientId,
                decoration: InputDecoration(
                  labelText: 'Client ID',
                  helperText: s.envPaypalClientId && _paypalClientId.text.isEmpty
                      ? 'Falling back to the .env client id'
                      : null,
                  helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 10),
              Text('Mode: ${s.paypalMode} · Currency: ${s.currency}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'D17',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Toggle(
                label: 'Show D17 to clients',
                value: _d17Enabled,
                onChanged: (v) => setState(() => _d17Enabled = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _d17Number,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Wallet number'),
              ),
              const SizedBox(height: 14),
              const Text('QR code', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              if (s.d17QrUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(s.d17QrUrl!,
                      height: 140,
                      errorBuilder: (_, __, ___) => const _NoQr()),
                )
              else
                const _NoQr(),
              const SizedBox(height: 6),
              const Text('Upload or replace the QR image on the website.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save settings'),
          ),
        ),
      ],
    );
  }
}

class _NoQr extends StatelessWidget {
  const _NoQr();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('No QR uploaded', style: TextStyle(color: AppColors.textMuted)),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.gold),
      ],
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
                  color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          child,
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
