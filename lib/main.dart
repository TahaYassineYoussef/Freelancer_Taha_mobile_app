import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/auth.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthState()..bootstrap(),
      child: const TahaApp(),
    ),
  );
}

class TahaApp extends StatelessWidget {
  const TahaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taha Yassine Youssef',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return auth.isLoggedIn ? const HomeShell() : const LoginScreen();
  }
}
