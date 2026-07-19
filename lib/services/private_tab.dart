import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens URLs in a private browser tab.
///
/// Google refuses OAuth inside embedded web views (`disallowed_useragent`), so
/// sign-in must run in a real browser. On Android we ask the host activity for
/// an *ephemeral* Custom Tab — a private session whose cookies and history are
/// discarded when it closes — falling back to the default browser elsewhere.
class PrivateTab {
  static const _channel = MethodChannel('taha/customtabs');

  /// Returns true when the URL opened in a genuinely private/ephemeral tab.
  static Future<bool> open(Uri url) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final ephemeral = await _channel.invokeMethod<bool>(
          'openPrivate',
          {'url': url.toString()},
        );
        return ephemeral ?? false;
      } on PlatformException {
        // No Custom Tabs provider — fall through to the default browser.
      } on MissingPluginException {
        // Channel not registered (e.g. running on an older build).
      }
    }

    await launchUrl(url, mode: LaunchMode.externalApplication);
    return false;
  }
}
