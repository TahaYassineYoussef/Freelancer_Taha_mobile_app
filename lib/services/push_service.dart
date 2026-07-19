import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

/// Entry point for a push that arrives while the app is killed or backgrounded.
///
/// Must be a top-level function: Android spawns a fresh isolate for it, so
/// nothing from the running app is available here.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['type'] == 'call') {
    await PushService.showIncomingCall(message.data);
  }
}

/// Wakes the app for incoming calls.
///
/// The call itself still runs over the WebRTC signalling in [CallState]; this
/// only exists so a closed app finds out a call is ringing, because a polling
/// timer cannot run when there is no process.
class PushService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static String? _token;

  /// Channel is `high` importance with a full-screen intent so Android shows
  /// the call over the lock screen instead of a silent banner.
  static const _channel = AndroidNotificationChannel(
    'calls',
    'Incoming calls',
    description: 'Rings when someone calls you',
    importance: Importance.max,
    playSound: true,
  );

  /// Sets up Firebase and registers this device against the signed-in user.
  /// Every failure is swallowed: no push must ever stop the app starting.
  static Future<void> start(ApiService api) async {
    if (kIsWeb) return;

    try {
      await Firebase.initializeApp();

      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      // Foreground: CallState's poll will pick the offer up within seconds, so
      // just surface the notification for a phone sitting on a desk.
      FirebaseMessaging.onMessage.listen((m) {
        if (m.data['type'] == 'call') showIncomingCall(m.data);
      });

      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await api.registerDevice(_token!);

      // Tokens rotate; keep the server in step.
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        _token = t;
        try {
          await api.registerDevice(t);
        } catch (_) {/* retried on next launch */}
      });
    } catch (e) {
      debugPrint('Push disabled: $e');
    }
  }

  /// Stops this device ringing for an account that just signed out.
  static Future<void> stop(ApiService api) async {
    final token = _token;
    if (token == null) return;
    try {
      await api.forgetDevice(token);
    } catch (_) {/* the token expires on its own */}
  }

  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    final name = data['from_name']?.toString() ?? 'Someone';
    final isVideo = data['video'] == '1';

    await _notifications.show(
      id: 1,
      title: isVideo ? 'Incoming video call' : 'Incoming call',
      body: name,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          // Launches the app straight into the ringing screen.
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
        ),
      ),
    );
  }

  /// Clears the ringing notification once the call is answered or gone.
  static Future<void> clearIncomingCall() => _notifications.cancel(id: 1);
}
