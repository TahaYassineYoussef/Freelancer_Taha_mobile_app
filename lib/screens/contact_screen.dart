import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Logged-out visitors can write too — the fields just start empty.
    final user = context.read<AuthState>().user;
    _name.text = user?.name ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final subject = _subject.text.trim();
      final message = await context.read<AuthState>().api.sendContact(
            name: _name.text.trim(),
            email: _email.text.trim(),
            subject: subject.isEmpty ? null : subject,
            body: _message.text.trim(),
          );
      messenger.showSnackBar(SnackBar(content: Text(message)));
      _subject.clear();
      _message.clear();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have a question or a project in mind? Send Taha a message.',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Tell Taha what you need…',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
