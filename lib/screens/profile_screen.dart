import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/auth.dart';
import '../state/i18n.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// This screen sits above the auth gate, so clearing the session alone would
  /// swap the screen underneath while the profile stayed on top. Pop back to
  /// the root first, then log out.
  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthState>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _AccountCard(),
          const SizedBox(height: 12),
          const _PasswordCard(),
          const SizedBox(height: 12),
          const _LanguageCard(),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, size: 18, color: Color(0xFFF87171)),
              label: const Text('Log out', style: TextStyle(color: Color(0xFFF87171))),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthState>().user;
    _name.text = user?.name ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthState>().api.updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
          );
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Account',
      children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save changes'),
        ),
      ],
    );
  }
}

class _PasswordCard extends StatefulWidget {
  const _PasswordCard();

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Local checks first, so an obvious mistake never costs a round trip.
  String? _validate() {
    if (_password.text.length < 8) return 'The new password must be at least 8 characters.';
    if (_password.text != _confirm.text) return 'The new passwords do not match.';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await context.read<AuthState>().api.updatePassword(
            currentPassword: _current.text,
            password: _password.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(message)));
      _current.clear();
      _password.clear();
      _confirm.clear();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Password',
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Update password'),
        ),
      ],
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();

    return _Card(
      title: 'Language',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: I18n.supported.entries.map((entry) {
            final isSelected = entry.key == i18n.locale;
            return ChoiceChip(
              selected: isSelected,
              onSelected: (_) => context.read<I18n>().setLocale(entry.key),
              label: Text(entry.value),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.ink : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              backgroundColor: AppColors.ink700,
              selectedColor: AppColors.gold,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }
}
