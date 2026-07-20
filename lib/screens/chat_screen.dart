import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../state/auth.dart';
import '../state/call_state.dart';
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${p.unread}',
                          style: const TextStyle(
                              color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatThreadScreen(partner: p)),
                );
                // Reading the thread clears its unread count server-side.
                if (mounted) {
                  setState(() => _future = context.read<AuthState>().api.chatPartners());
                }
              },
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
      appBar: AppBar(
        title: Text(widget.partner.name),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call),
            onPressed: () => context
                .read<CallState>()
                .callUser(widget.partner.id, widget.partner.name, video: false),
          ),
          IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam),
            onPressed: () => context
                .read<CallState>()
                .callUser(widget.partner.id, widget.partner.name, video: true),
          ),
        ],
      ),
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

  /// A Messenger-style call-log row: icon + "Video call · 2:14" or "Missed call".
  Widget _callCard(Message m, bool mine) {
    final video = m.callKind == 'video';
    final missed = m.callStatus == 'missed' || m.callStatus == 'declined';
    final label = missed
        ? (mine ? 'Cancelled call' : 'Missed call')
        : (video ? 'Video call' : 'Voice call');
    final secs = m.callSeconds ?? 0;
    final duration = (!missed && secs > 0)
        ? ' · ${(secs ~/ 60)}:${(secs % 60).toString().padLeft(2, '0')}'
        : '';
    final color = missed ? const Color(0xFFF87171) : AppColors.gold;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.ink600,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              video ? Icons.videocam : Icons.call,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text('$label$duration',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _bubble(Message m) {
    final mine = m.senderId == _meId;
    if (m.isCall) return _callCard(m, mine);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.hasAttachment) _attachment(m, mine),
            if (m.body.isNotEmpty)
              Text(m.body, style: TextStyle(color: mine ? AppColors.ink : Colors.white)),
            if (mine)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(m.read ? Icons.done_all : Icons.done,
                    size: 14, color: AppColors.ink.withValues(alpha: 0.55)),
              ),
          ],
        ),
      ),
    );
  }

  /// Image attachments preview inline; anything else opens externally.
  Widget _attachment(Message m, bool mine) {
    Future<void> onTap() async {
      final uri = Uri.tryParse(m.attachmentUrl!);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (m.isImage) {
      return Padding(
        padding: EdgeInsets.only(bottom: m.body.isEmpty ? 0 : 8),
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(m.attachmentUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _attachmentChip(m, mine, onTap)),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: m.body.isEmpty ? 0 : 8),
      child: _attachmentChip(m, mine, onTap),
    );
  }

  Widget _attachmentChip(Message m, bool mine, VoidCallback onTap) {
    final color = mine ? AppColors.ink : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(m.attachmentName ?? 'Attachment',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, decoration: TextDecoration.underline, fontSize: 13)),
          ),
        ],
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
