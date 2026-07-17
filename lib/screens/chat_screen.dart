import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/auth.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Future<List<ChatPartner>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthState>().api.chatPartners();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChatPartner>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        final partners = snap.data ?? [];
        if (partners.isEmpty) {
          return const Center(child: Text('No conversations yet.', style: TextStyle(color: AppColors.textMuted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: partners.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
          itemBuilder: (_, i) {
            final p = partners[i];
            final initials = p.name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold,
                child: Text(initials, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
              ),
              title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(p.role, style: const TextStyle(color: AppColors.textMuted)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChatThreadScreen(partner: p)),
              ),
            );
          },
        );
      },
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  final ChatPartner partner;
  const ChatThreadScreen({super.key, required this.partner});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Message> _messages = [];
  Timer? _timer;
  bool _sending = false;
  int get _meId => context.read<AuthState>().user!.id;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final msgs = await context.read<AuthState>().api.messages(widget.partner.id);
      if (!mounted) return;
      final grew = msgs.length != _messages.length;
      setState(() => _messages = msgs);
      if (grew) _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final msgs = await context.read<AuthState>().api.sendMessage(widget.partner.id, text);
      _input.clear();
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.partner.name)),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('No messages yet. Say hello 👋', style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _bubble(_messages[i]),
                  ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(Message m) {
    final mine = m.senderId == _meId;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? AppColors.gold : AppColors.ink600,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Text(m.body, style: TextStyle(color: mine ? AppColors.ink : Colors.white)),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: AppColors.ink800,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Type a message…'),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.gold,
              child: IconButton(
                icon: _sending
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                    : const Icon(Icons.send, color: AppColors.ink),
                onPressed: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
