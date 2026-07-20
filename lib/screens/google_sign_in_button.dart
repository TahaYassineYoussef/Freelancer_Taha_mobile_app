import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/auth.dart';

/// "Continue with Google", mirroring the web site's button.
///
/// Uses native Google Sign-In rather than a browser redirect: Google Play
/// Services returns an ID token straight to the app, which the server verifies.
/// That sidesteps OAuth redirect URIs entirely — they can only be a public
/// hostname or loopback, never the LAN address a real phone talks to.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // The Firebase "Web" OAuth client (client_type 3 in google-services.json).
  // Native sign-in mints its ID token for this audience, which is what the
  // backend verifies against.
  static const _serverClientId =
      '784467110916-9q7u3isane98cc4tg4e2uln365q2tti0.apps.googleusercontent.com';

  Future<void> _init() async {
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Play Services missing or the app isn't registered in the console;
      // the button stays disabled rather than failing on tap.
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final auth = context.read<AuthState>();

    try {
      debugPrint('GSI: calling authenticate()');
      final account = await GoogleSignIn.instance.authenticate();
      debugPrint('GSI: account = ${account.email}');
      final idToken = account.authentication.idToken;
      debugPrint('GSI: idToken = ${idToken == null ? "NULL" : "${idToken.length} chars"}');

      if (idToken == null) {
        _say('Google did not return a sign-in token.');
        return;
      }

      debugPrint('GSI: posting idToken to backend…');
      await auth.signInWithGoogle(idToken);
      debugPrint('GSI: backend accepted, signed in');
      // Success swaps the whole screen, so there is nothing more to do here.
    } on GoogleSignInException catch (e) {
      debugPrint('GSI ERROR: GoogleSignInException code=${e.code.name} desc=${e.description}');
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _say('Google sign-in failed: ${e.code.name}');
      }
    } on ApiException catch (e) {
      debugPrint('GSI ERROR: ApiException ${e.message}');
      _say(e.message);
    } catch (e, st) {
      debugPrint('GSI ERROR: ${e.runtimeType} :: $e');
      debugPrint('GSI STACK: $st');
      _say('Could not complete Google sign-in.');
    } finally {
      if (mounted) setState(() => _busy = false);
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
        onPressed: _busy || !_ready ? null : _start,
        icon: _busy
            ? const SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const _GoogleGlyph(),
        label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
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
