import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Base URL of the Laravel API.
///
/// - Android emulator reaches the host machine via 10.0.2.2
/// - Web / desktop use 127.0.0.1
/// - On a real phone, replace with your PC's LAN IP, e.g. http://192.168.1.15:8000/api
/// Host the app talks to on Android.
///
/// A real phone reaches the dev machine over Wi-Fi at its LAN IP, provided the
/// server runs with `--host=0.0.0.0` and TCP 8000 is allowed through the
/// firewall. (`adb reverse` did not route on the test A50, so the tunnel isn't
/// relied on.) The emulator reaches this LAN IP fine too. In production this is
/// simply your domain.
const _androidHost = '192.168.0.230';

String get apiBaseUrl {
  if (kIsWeb) return 'http://127.0.0.1:8000/api';
  if (Platform.isAndroid) return 'http://$_androidHost:8000/api';
  return 'http://127.0.0.1:8000/api';
}

/// Origin of the API host (base URL without the trailing `/api`).
String get apiOrigin {
  final base = apiBaseUrl;
  return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
}

/// Origin used for the Google OAuth round-trip.
///
/// The whole trip must stay on one host so the OAuth session cookie survives,
/// so this simply follows [apiOrigin].
///
/// Note for real devices: Google only accepts a public hostname or loopback as
/// a redirect URI — never a LAN IP — so sign-in needs a public URL (an ngrok
/// tunnel in development, your domain in production) registered in the Google
/// console. Email/password login has no such constraint.
String get oauthOrigin => apiOrigin;

/// The 11-character video id in a YouTube watch/share/short/embed link, or null.
String? youtubeId(String? url) {
  if (url == null || url.isEmpty) return null;
  final m = RegExp(
    r'(?:youtube\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
  ).firstMatch(url);
  return m?.group(1);
}

/// Derives a YouTube thumbnail URL from a watch/share/short/embed link, or
/// returns null if [url] isn't a recognisable YouTube link. Mirrors the web
/// `youtubeThumbnail` helper so projects with only a video link still show art.
String? youtubeThumbnail(String? url) {
  final id = youtubeId(url);
  return id == null ? null : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}

/// Embed URL that plays inline inside a web view rather than launching the
/// YouTube app.
String youtubeEmbed(String id) =>
    'https://www.youtube.com/embed/$id?autoplay=1&playsinline=1&rel=0&modestbranding=1';

/// The backend serialises media URLs with an absolute host (e.g.
/// `http://127.0.0.1:8000/storage/...`). That host is unreachable from an
/// Android emulator or a real device, so rewrite any backend-local URL to the
/// same host the app already uses to reach the API.
String? mediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return raw;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return raw;
  const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};
  if (!localHosts.contains(uri.host)) return raw;
  final origin = Uri.parse(apiOrigin);
  return uri
      .replace(scheme: origin.scheme, host: origin.host, port: origin.port)
      .toString();
}
