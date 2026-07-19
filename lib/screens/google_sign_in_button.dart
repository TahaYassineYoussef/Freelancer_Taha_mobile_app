import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/private_tab.dart';
import '../state/auth.dart';

/// "Continue with Google", mirroring the web site's button.
///
/// Google blocks OAuth inside embedded web views, so the flow runs in a private
/// (ephemeral) browser tab against the site's existing Socialite routes. When
/// it finishes, the server redirects to `freelancertaha://auth?token=…`, which
/// Android hands back to the app and we swap for a signed-in session.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _links;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for the deep link the browser tab redirects to.
    _links = AppLinks().uriLinkStream.listen(_onLink, onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back with no deep link means the user dismissed the browser tab,
    // so clear the waiting state instead of spinning forever.
    if (state == AppLifecycleState.resumed && _busy && mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _onLink(Uri uri) async {
    if (uri.scheme != 'freelancertaha' || uri.host != 'auth') return;

    final token = uri.queryParameters['token'];
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() => _busy = false);
      _say('Google sign-in was cancelled.');
      return;
    }

    try {
      await context.read<AuthState>().signInWithToken(token);
      // A successful sign-in swaps the whole screen, so nothing else to do.
    } catch (_) {
      if (mounted) _say('Could not complete Google sign-in.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      // Loopback, not the emulator alias: Google redirects back to 127.0.0.1
      // and the OAuth session must stay on one host. See config.oauthOrigin.
      await PrivateTab.open(Uri.parse('$oauthOrigin/auth/google/mobile'));
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _say('Could not open the browser for Google sign-in.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Explicit light styling: the login card is white, so the app's dark/gold
    // button theme would read as out of place here.
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _start,
        icon: _busy
            ? const SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const _GoogleGlyph(),
        label: Text(_busy ? 'Waiting for Google…' : 'Continue with Google'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          side: const BorderSide(color: Color(0xFFDADCE0)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// The Google "G" drawn from text so no network asset is needed.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text('G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.w900,
            fontSize: 14,
            height: 1.1,
          )),
    );
  }
}
