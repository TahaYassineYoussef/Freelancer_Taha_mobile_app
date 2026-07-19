import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/auth.dart';
import '../theme.dart';

/// Leave a star review. Held unapproved until Taha publishes it, same as web.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ReviewSheet(),
    );
  }

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  final _body = TextEditingController();
  final _roleTitle = TextEditingController();
  int _rating = 5;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    _roleTitle.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_body.text.trim().length < 10) {
      setState(() => _error = 'Please write at least 10 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final message = await context.read<AuthState>().api.submitReview(
            rating: _rating,
            body: _body.text.trim(),
            roleTitle: _roleTitle.text.trim(),
          );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leave a review',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(filled ? Icons.star : Icons.star_border,
                      color: AppColors.gold, size: 30),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your review',
                hintText: 'How was working with Taha?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleTitle,
              decoration: const InputDecoration(
                labelText: 'Your role (optional)',
                hintText: 'e.g. Founder, Acme',
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
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
