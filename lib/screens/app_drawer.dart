import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth.dart';
import '../state/i18n.dart';
import '../theme.dart';
import 'availability_screen.dart';
import 'blocked_screen.dart';
import 'bookings_screen.dart';
import 'contact_screen.dart';
import 'inbox_screen.dart';
import 'manage_cv_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'review_moderation_screen.dart';
import 'visitors_screen.dart';

/// Side navigation, mirroring the web sidebar.
///
/// Tabs already in the bottom bar switch the shell in place (via [onSelectTab]);
/// everything else is pushed as its own screen.
class AppDrawer extends StatelessWidget {
  final List<String> tabLabels;
  final int selectedTab;
  final ValueChanged<int> onSelectTab;
  final int unread;

  const AppDrawer({
    super.key,
    required this.tabLabels,
    required this.selectedTab,
    required this.onSelectTab,
    this.unread = 0,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final i18n = context.watch<I18n>();
    final user = auth.user;
    final isFreelancer = user?.isFreelancer ?? false;

    return Drawer(
      backgroundColor: AppColors.ink800,
      child: SafeArea(
        child: Column(
          children: [
            _Header(name: user?.name ?? '', subtitle: user?.email ?? '', isFreelancer: isFreelancer),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // The bottom-bar destinations, so the drawer is a full map of
                  // the app rather than a leftovers menu.
                  for (var i = 0; i < tabLabels.length; i++)
                    _Item(
                      icon: _tabIcons[tabLabels[i]] ?? Icons.circle_outlined,
                      label: i18n.t(tabLabels[i]),
                      selected: i == selectedTab,
                      badge: tabLabels[i] == 'Chat' && unread > 0 ? unread : null,
                      onTap: () {
                        Navigator.pop(context);
                        onSelectTab(i);
                      },
                    ),
                  const _Divider(),
                  if (isFreelancer) ...[
                    _SectionLabel(i18n.t('Manage')),
                    _Push(icon: Icons.event_available_outlined, label: i18n.t('Bookings'), screen: const BookingsScreen()),
                    _Push(icon: Icons.schedule, label: i18n.t('Availability'), screen: const AvailabilityScreen()),
                    _Push(icon: Icons.star_border, label: i18n.t('Reviews'), screen: const ReviewModerationScreen()),
                    _Push(icon: Icons.mail_outline, label: i18n.t('Inbox'), screen: const InboxScreen()),
                    _Push(icon: Icons.insights_outlined, label: i18n.t('Visitors'), screen: const VisitorsScreen()),
                    _Push(icon: Icons.shield_outlined, label: i18n.t('Blocked'), screen: const BlockedScreen()),
                    _Push(icon: Icons.description_outlined, label: i18n.t('Manage CV'), screen: const ManageCvScreen()),
                    const _Divider(),
                  ],
                  _SectionLabel(i18n.t('Account')),
                  _Push(
                    icon: Icons.notifications_none,
                    label: i18n.t('Notifications'),
                    screen: const NotificationsScreen(),
                    badge: unread > 0 ? unread : null,
                  ),
                  _Push(icon: Icons.account_circle_outlined, label: i18n.t('Profile'), screen: const ProfileScreen()),
                  if (!isFreelancer)
                    _Push(icon: Icons.support_agent_outlined, label: i18n.t('Contact'), screen: const ContactScreen()),
                ],
              ),
            ),
            const _Divider(),
            _Item(
              icon: Icons.logout,
              label: i18n.t('Log out'),
              color: const Color(0xFFF87171),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthState>().logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const _tabIcons = <String, IconData>{
    'Dashboard': Icons.dashboard_outlined,
    'Portfolio': Icons.person_outline,
    'Tasks': Icons.assignment_outlined,
    'Get Paid': Icons.payments_outlined,
    'Revisions': Icons.loop,
    'Deliveries': Icons.inventory_2_outlined,
    'Chat': Icons.chat_bubble_outline,
  };
}

class _Header extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isFreelancer;
  const _Header({required this.name, required this.subtitle, required this.isFreelancer});

  @override
  Widget build(BuildContext context) {
    final initials =
        name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.goldDark, AppColors.gold],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.ink,
            // The freelancer is Taha, so use his bundled portrait.
            backgroundImage: isFreelancer ? const AssetImage('assets/taha.png') : null,
            child: isFreelancer
                ? null
                : Text(initials,
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          const SizedBox(height: 12),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 17)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.ink.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16);
}

/// A drawer row that pushes [screen].
class _Push extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget screen;
  final int? badge;
  const _Push({required this.icon, required this.label, required this.screen, this.badge});

  @override
  Widget build(BuildContext context) {
    return _Item(
      icon: icon,
      label: label,
      badge: badge,
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final int? badge;
  final Color? color;

  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (selected ? AppColors.gold : Colors.white70);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? AppColors.gold.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: tint),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tint,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      )),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
