import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Base URL of the Laravel API.
///
/// - Android emulator reaches the host machine via 10.0.2.2
/// - Web / desktop use 127.0.0.1
/// - On a real phone, replace with your PC's LAN IP, e.g. http://192.168.1.15:8000/api
String get apiBaseUrl {
  if (kIsWeb) return 'http://127.0.0.1:8000/api';
  if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
  return 'http://127.0.0.1:8000/api';
}

/// Origin of the API host (base URL without the trailing `/api`).
String get apiOrigin {
  final base = apiBaseUrl;
  return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
}

/// Origin used for the Google OAuth round-trip.
///
/// Google only accepts public hostnames or loopback as a redirect URI — never
/// `10.0.2.2` — and the OAuth session cookie has to live on the same host for
/// the whole trip, so the flow starts on loopback too. On the Android emulator
/// that requires the port to be forwarded to the machine running Laravel:
///
///     adb reverse tcp:8000 tcp:8000
///
/// Point this at your real domain in production.
String get oauthOrigin {
  final origin = Uri.parse(apiOrigin);
  return origin.replace(host: '127.0.0.1').toString();
}

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
