import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';
import '../services/push_service.dart';

enum CallPhase { idle, incoming, outgoing, connected }

/// Audio/video calling, speaking the same signalling contract as the web
/// client (`useCall.js`): JSON payloads over `/api/calls/*`, drained by a poll.
///
/// The browser is the other end of these calls, so the payload shapes matter:
///   offer  -> {"sdp": {type, sdp}, "video": bool}
///   answer -> {"sdp": {type, sdp}}
///   ice    -> the RTCIceCandidate fields
class CallState extends ChangeNotifier {
  final ApiService api;
  CallState(this.api);

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Timer? _poll;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  Timer? _ticker;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  CallPhase phase = CallPhase.idle;
  int? peerId;
  String peerName = '';
  bool isVideo = false;
  bool micEnabled = true;
  bool camEnabled = true;
  Duration elapsed = Duration.zero;
  String? error;

  /// Offer we were rung with, held until the user accepts.
  Map<String, dynamic>? _pendingOffer;
  DateTime? _startedAt;

  bool get inCall => phase != CallPhase.idle;

  // ---- Lifecycle ---------------------------------------------------------

  /// Begin listening for calls. Safe to call more than once.
  void start() {
    _poll ??= Timer.periodic(const Duration(seconds: 3), (_) => _drain());
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    _teardown(notify: false);
  }

  Future<void> _ensureRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  @override
  void dispose() {
    stop();
    if (_renderersReady) {
      localRenderer.dispose();
      remoteRenderer.dispose();
    }
    super.dispose();
  }

  // ---- Signalling --------------------------------------------------------

  Future<void> _drain() async {
    if (api.token == null) return;
    try {
      final signals = await api.pollCalls();
      for (final s in signals) {
        await _handle(s);
      }
    } catch (_) {
      // A dropped poll is not worth surfacing; the next tick retries.
    }
  }

  Future<void> _handle(Map<String, dynamic> sig) async {
    final kind = sig['kind'];
    final from = sig['from_id'] as int?;

    switch (kind) {
      case 'offer':
        // Busy: politely decline a second caller.
        if (inCall && from != peerId) {
          await api.sendCallSignal(toId: from!, kind: 'decline');
          return;
        }
        final data = jsonDecode(sig['payload'] ?? '{}') as Map<String, dynamic>;
        _pendingOffer = data;
        peerId = from;
        peerName = sig['from_name'] ?? 'Someone';
        isVideo = data['video'] == true;
        phase = CallPhase.incoming;
        notifyListeners();
        break;

      case 'answer':
        final data = jsonDecode(sig['payload'] ?? '{}') as Map<String, dynamic>;
        final sdp = data['sdp'] as Map<String, dynamic>;
        await _pc?.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
        _markConnected();
        break;

      case 'ice':
        final c = jsonDecode(sig['payload'] ?? '{}') as Map<String, dynamic>;
        if (c['candidate'] != null) {
          await _pc?.addCandidate(
            RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
          );
        }
        break;

      case 'decline':
      case 'hangup':
        _teardown();
        break;
    }
  }

  // ---- Actions -----------------------------------------------------------

  /// Answer the call we are being rung with.
  Future<void> accept() async {
    final offer = _pendingOffer;
    final to = peerId;
    if (offer == null || to == null) return;

    if (!await _grantPermissions(video: isVideo)) {
      error = 'Microphone permission is required to take calls.';
      await decline();
      return;
    }

    try {
      await _ensureRenderers();
      await _openPeer(video: isVideo);

      final sdp = offer['sdp'] as Map<String, dynamic>;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));

      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);

      await api.sendCallSignal(
        toId: to,
        kind: 'answer',
        payload: jsonEncode({
          'sdp': {'type': answer.type, 'sdp': answer.sdp},
        }),
      );

      _pendingOffer = null;
      _markConnected();
    } catch (e) {
      error = 'Could not start the call.';
      await hangUp();
    }
  }

  Future<void> decline() async {
    final to = peerId;
    if (to != null) {
      await _safeSignal(to, 'decline');
      await _log(to, 'declined');
    }
    _teardown();
  }

  Future<void> hangUp() async {
    final to = peerId;
    final seconds = elapsed.inSeconds;
    if (to != null) {
      await _safeSignal(to, 'hangup');
      // Only the side that was actually connected logs a completed call.
      if (phase == CallPhase.connected) await _log(to, 'completed', seconds);
    }
    _teardown();
  }

  void toggleMic() {
    micEnabled = !micEnabled;
    for (final t in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = micEnabled;
    }
    notifyListeners();
  }

  void toggleCam() {
    camEnabled = !camEnabled;
    for (final t in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = camEnabled;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track != null) await Helper.switchCamera(track);
  }

  // ---- Plumbing ----------------------------------------------------------

  Future<bool> _grantPermissions({required bool video}) async {
    final wanted = [Permission.microphone, if (video) Permission.camera];
    final results = await wanted.request();
    return results.values.every((s) => s.isGranted);
  }

  Future<void> _openPeer({required bool video}) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
    localRenderer.srcObject = _localStream;

    final pc = await createPeerConnection(_iceServers);

    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      final to = peerId;
      if (to == null) return;
      _safeSignal(
        to,
        'ice',
        jsonEncode({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        notifyListeners();
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _teardown();
      }
    };

    _pc = pc;
  }

  void _markConnected() {
    if (phase == CallPhase.connected) return;
    PushService.clearIncomingCall();
    phase = CallPhase.connected;
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed = DateTime.now().difference(_startedAt ?? DateTime.now());
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _safeSignal(int to, String kind, [String? payload]) async {
    try {
      await api.sendCallSignal(toId: to, kind: kind, payload: payload);
    } catch (_) {/* the call is ending anyway */}
  }

  Future<void> _log(int to, String status, [int? seconds]) async {
    try {
      await api.logCall(
        toId: to,
        kind: isVideo ? 'video' : 'voice',
        status: status,
        seconds: seconds,
      );
    } catch (_) {/* logging must never block hanging up */}
  }

  void _teardown({bool notify = true}) {
    PushService.clearIncomingCall();
    _ticker?.cancel();
    _ticker = null;
    _pc?.close();
    _pc = null;
    for (final t in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      t.stop();
    }
    _localStream?.dispose();
    _localStream = null;
    if (_renderersReady) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }

    phase = CallPhase.idle;
    peerId = null;
    peerName = '';
    isVideo = false;
    micEnabled = true;
    camEnabled = true;
    elapsed = Duration.zero;
    _pendingOffer = null;
    _startedAt = null;

    if (notify) notifyListeners();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
