import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../state/call_state.dart';
import '../theme.dart';

/// Wraps the app so an incoming call takes over the screen from anywhere,
/// the way the web CallOverlay does.
class CallHost extends StatelessWidget {
  final Widget child;
  const CallHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallState>();

    return Stack(
      children: [
        child,
        if (call.inCall) const Positioned.fill(child: _CallScreen()),
      ],
    );
  }
}

class _CallScreen extends StatelessWidget {
  const _CallScreen();

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallState>();
    final ringing = call.phase == CallPhase.incoming;

    return Material(
      color: AppColors.ink,
      child: SafeArea(
        child: Stack(
          children: [
            // Remote video fills the screen once the far side sends one.
            if (call.phase == CallPhase.connected && call.isVideo)
              Positioned.fill(
                child: RTCVideoView(call.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            if (call.phase == CallPhase.connected && call.isVideo)
              Positioned(
                right: 16,
                top: 16,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(call.localRenderer, mirror: true),
                ),
              ),

            // Caller identity + status.
            Positioned(
              left: 0,
              right: 0,
              top: call.phase == CallPhase.connected && call.isVideo ? 24 : 120,
              child: Column(
                children: [
                  if (!(call.phase == CallPhase.connected && call.isVideo)) ...[
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                      child: Text(
                        call.peerName.isEmpty ? '?' : call.peerName[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 44, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(call.peerName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(_status(call),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  if (call.error != null) ...[
                    const SizedBox(height: 10),
                    Text(call.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
                  ],
                ],
              ),
            ),

            // Controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: ringing ? const _RingingControls() : const _InCallControls(),
            ),
          ],
        ),
      ),
    );
  }

  static String _status(CallState call) {
    switch (call.phase) {
      case CallPhase.incoming:
        return call.isVideo ? 'Incoming video call…' : 'Incoming call…';
      case CallPhase.outgoing:
        return 'Calling…';
      case CallPhase.connected:
        final d = call.elapsed;
        final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
        final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
        return '$mm:$ss';
      case CallPhase.idle:
        return '';
    }
  }
}

class _RingingControls extends StatelessWidget {
  const _RingingControls();

  @override
  Widget build(BuildContext context) {
    final call = context.read<CallState>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: Icons.call_end,
          color: const Color(0xFFEF4444),
          label: 'Decline',
          onTap: call.decline,
        ),
        _RoundButton(
          icon: call.isVideo ? Icons.videocam : Icons.call,
          color: const Color(0xFF22C55E),
          label: 'Accept',
          onTap: call.accept,
        ),
      ],
    );
  }
}

class _InCallControls extends StatelessWidget {
  const _InCallControls();

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallState>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: call.micEnabled ? Icons.mic : Icons.mic_off,
          color: AppColors.ink600,
          label: call.micEnabled ? 'Mute' : 'Unmute',
          onTap: call.toggleMic,
        ),
        const SizedBox(width: 18),
        if (call.isVideo) ...[
          _RoundButton(
            icon: call.camEnabled ? Icons.videocam : Icons.videocam_off,
            color: AppColors.ink600,
            label: 'Camera',
            onTap: call.toggleCam,
          ),
          const SizedBox(width: 18),
          _RoundButton(
            icon: Icons.cameraswitch,
            color: AppColors.ink600,
            label: 'Flip',
            onTap: call.switchCamera,
          ),
          const SizedBox(width: 18),
        ],
        _RoundButton(
          icon: Icons.call_end,
          color: const Color(0xFFEF4444),
          label: 'End',
          onTap: call.hangUp,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
