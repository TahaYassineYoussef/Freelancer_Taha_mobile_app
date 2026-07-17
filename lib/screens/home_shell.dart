import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'portfolio_screen.dart';
import 'tasks_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Portfolio', 'Tasks', 'Messages'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            children: [
              TextSpan(text: 'TAHA'),
              TextSpan(text: '.', style: TextStyle(color: AppColors.gold)),
              TextSpan(text: '  ·  ', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(_titles[_index], style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await auth.logout();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          PortfolioScreen(),
          TasksScreen(),
          ChatScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.ink800,
        indicatorColor: AppColors.gold.withValues(alpha: 0.2),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.person, color: AppColors.gold),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.assignment, color: AppColors.gold),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.chat_bubble, color: AppColors.gold),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
