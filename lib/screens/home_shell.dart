import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth.dart';
import '../state/i18n.dart';
import '../theme.dart';
import 'app_drawer.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'deliveries_screen.dart';
import 'notifications_screen.dart';
import 'payments_screen.dart';
import 'portfolio_screen.dart';
import 'profile_screen.dart';
import 'revisions_screen.dart';
import 'tasks_screen.dart';

/// One tab in the bottom bar.
class _Tab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
  const _Tab(this.label, this.icon, this.activeIcon, this.screen);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  /// Notification badge count. Non-fatal: the shell works without it.
  Future<void> _loadUnread() async {
    try {
      final feed = await context.read<AuthState>().api.notifications();
      if (mounted) setState(() => _unread = feed.unread);
    } catch (_) {/* badge stays hidden */}
  }

  /// The freelancer gets their console; a client gets the portfolio app.
  List<_Tab> _tabs(bool isFreelancer) {
    if (isFreelancer) {
      return const [
        _Tab('Dashboard', Icons.dashboard_outlined, Icons.dashboard, DashboardScreen()),
        _Tab('Tasks', Icons.assignment_outlined, Icons.assignment, TasksScreen()),
        _Tab('Get Paid', Icons.payments_outlined, Icons.payments, PaymentsScreen()),
        _Tab('Revisions', Icons.loop, Icons.loop, RevisionsScreen()),
        _Tab('Chat', Icons.chat_bubble_outline, Icons.chat_bubble, ChatScreen()),
      ];
    }
    return const [
      _Tab('Portfolio', Icons.person_outline, Icons.person, PortfolioScreen()),
      _Tab('Tasks', Icons.assignment_outlined, Icons.assignment, TasksScreen()),
      _Tab('Deliveries', Icons.inventory_2_outlined, Icons.inventory_2, DeliveriesScreen()),
      _Tab('Chat', Icons.chat_bubble_outline, Icons.chat_bubble, ChatScreen()),
    ];
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _loadUnread();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final auth = context.watch<AuthState>();
    final isFreelancer = auth.user?.isFreelancer ?? false;
    final tabs = _tabs(isFreelancer);
    // Role can change on re-login, so never index past the current tab list.
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      // Full map of the app, mirroring the web sidebar.
      drawer: AppDrawer(
        tabLabels: tabs.map((t) => t.label).toList(),
        selectedTab: index,
        onSelectTab: (i) => setState(() => _index = i),
        unread: _unread,
      ),
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            children: [
              TextSpan(text: 'TAHA'),
              TextSpan(text: '.', style: TextStyle(color: AppColors.gold)),
            ],
          ),
        ),
        actions: [
          Center(
            child: Text(i18n.t(tabs[index].label),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          IconButton(
            tooltip: i18n.t('Notifications'),
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              backgroundColor: AppColors.gold,
              textColor: AppColors.ink,
              child: const Icon(Icons.notifications_none, color: Colors.white70),
            ),
          ),
          IconButton(
            tooltip: i18n.t('Profile'),
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white70),
            onPressed: () => _open(const ProfileScreen()),
          ),
          IconButton(
            tooltip: i18n.t('Log out'),
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.ink800,
        indicatorColor: AppColors.gold.withValues(alpha: 0.2),
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon, color: AppColors.textMuted),
                  selectedIcon: Icon(t.activeIcon, color: AppColors.gold),
                  label: i18n.t(t.label),
                ))
            .toList(),
      ),
    );
  }
}
