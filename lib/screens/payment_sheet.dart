import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Payment entry points for an unpaid task, mirroring the web app: a method is
/// offered only when the freelancer switched it on in Payment Settings AND the
/// matching credential exists.
class PaymentButtons extends StatelessWidget {
  final Task task;
  final PaymentConfig config;
  final ApiService api;
  final VoidCallback onPaid;

  const PaymentButtons({
    super.key,
    required this.task,
    required this.config,
    required this.api,
    required this.onPaid,
  });

  @override
  Widget build(BuildContext context) {
    if (!task.isPayable || !config.any) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          if (config.showPaypal)
            ElevatedButton.icon(
              onPressed: () => _payWithPaypal(context),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: Text('Pay ${task.budget} ${config.paypalCurrency}'),
            ),
          if (config.showD17)
            OutlinedButton.icon(
              onPressed: () => _payWithD17(context),
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('Pay with D17'),
            ),
        ],
      ),
    );
  }

  Future<void> _payWithPaypal(BuildContext context) async {
    final url = Uri.parse('$apiOrigin/paypal/checkout').replace(queryParameters: {
      'client_id': config.paypalClientId!,
      'currency': config.paypalCurrency,
      'amount': task.budget!,
      'title': task.title,
    });

    // Flutter web cannot host a web view; open the checkout in a new tab there.
    if (kIsWeb) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        _snack(context, 'Finish the payment in the tab that just opened, then pull to refresh.');
      }
      return;
    }

    final orderId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _PaypalCheckoutPage(url: url)),
    );

    if (orderId == null || !context.mounted) return;

    try {
      await api.payWithPaypal(task.id, orderId);
      if (context.mounted) _snack(context, 'Payment received. Thank you!');
      onPaid();
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  Future<void> _payWithD17(BuildContext context) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _D17Sheet(task: task, config: config, api: api),
    );

    if (sent == true) onPaid();
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// In-app PayPal checkout. Watches for the `/paypal/done` redirect the checkout
/// page performs after a successful capture and returns the order id.
class _PaypalCheckoutPage extends StatefulWidget {
  final Uri url;
  const _PaypalCheckoutPage({required this.url});

  @override
  State<_PaypalCheckoutPage> createState() => _PaypalCheckoutPageState();
}

class _PaypalCheckoutPageState extends State<_PaypalCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null && uri.path == '/paypal/done') {
            // Pop with the captured order id (null when the user cancelled).
            Navigator.of(context).pop(uri.queryParameters['order_id']);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(title: const Text('PayPal')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        ],
      ),
    );
  }
}

/// D17 (DigiPost) transfer: show the wallet number + QR, then collect the
/// transfer reference. Recorded as pending until Taha confirms it.
class _D17Sheet extends StatefulWidget {
  final Task task;
  final PaymentConfig config;
  final ApiService api;
  const _D17Sheet({required this.task, required this.config, required this.api});

  @override
  State<_D17Sheet> createState() => _D17SheetState();
}

class _D17SheetState extends State<_D17Sheet> {
  final _reference = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reference.text.trim().isEmpty) {
      setState(() => _error = 'Enter the transfer reference.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.payWithD17(widget.task.id, _reference.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('D17 payment submitted. Taha will confirm it shortly.'),
        ));
      }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pay with D17',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Transfer ${widget.task.budget} TND to the wallet below, then paste the '
              'reference so Taha can confirm it.',
              style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ink700,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('D17 wallet', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      SelectableText(widget.config.d17Number ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.config.d17QrUrl != null) ...[
            const SizedBox(height: 14),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.config.d17QrUrl!,
                    height: 160,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _reference,
            decoration: InputDecoration(
              labelText: 'Transfer reference',
              hintText: 'e.g. 123456789',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('I sent the transfer'),
            ),
          ),
        ],
      ),
    );
  }
}
