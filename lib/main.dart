import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/call_overlay.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/push_service.dart';
import 'state/auth.dart';
import 'state/call_state.dart';
import 'state/i18n.dart';
import 'theme.dart';

void main() {
  // Required: bootstrap() touches SharedPreferences (a plugin) before runApp,
  // which needs the platform channels to exist first.
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthState()..bootstrap();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        // Shares the auth service so translations ride the same client.
        ChangeNotifierProvider(create: (_) => I18n(auth.api)..bootstrap()),
        ChangeNotifierProvider(create: (_) => CallState(auth.api)),
      ],
      child: const TahaApp(),
    ),
  );
}

class TahaApp extends StatelessWidget {
  const TahaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();

    return MaterialApp(
      title: 'Taha Yassine Youssef',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Arabic flips the whole UI, matching the web site's `dir` switch.
      builder: (context, child) => I18nScope(
        notifier: i18n,
        child: Directionality(
          textDirection: i18n.direction,
          // Above the navigator, so a call takes over from any screen.
          child: CallHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _listening = false;

  /// Only ring while someone is signed in.
  void _syncCallListener(bool loggedIn) {
    if (loggedIn == _listening) return;
    _listening = loggedIn;
    final auth = context.read<AuthState>();
    final calls = context.read<CallState>();
    if (loggedIn) {
      calls.start();
      PushService.start(auth.api);
    } else {
      calls.stop();
      PushService.stop(auth.api);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCallListener(auth.isLoggedIn));

    return auth.isLoggedIn ? const HomeShell() : const LoginScreen();
  }
}
