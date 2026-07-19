import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config.dart';
import '../theme.dart';

/// A project video that plays inside its card: the poster image shows until the
/// user hits play, then the mp4 streams in place with tap-to-pause and a scrub
/// bar. The controller is only created on first play, so a long portfolio does
/// not spin up a decoder per card.
class InlineVideo extends StatefulWidget {
  final String url;
  final String? poster;
  final String? posterFallback;

  const InlineVideo({super.key, required this.url, this.poster, this.posterFallback});

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    if (c != null && c.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          // Play badge while paused, so the card reads as a video.
          if (!c.value.isPlaying)
            IgnorePointer(
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.gold,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      );
    }

    // Not playing yet — poster + play button.
    return GestureDetector(
      onTap: _start,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _poster(),
          if (_loading)
            const CircularProgressIndicator(color: AppColors.gold)
          else
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
          if (_failed)
            Positioned(
              bottom: 8,
              child: Text('Could not play this video.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      backgroundColor: Colors.black54)),
            ),
        ],
      ),
    );
  }

  Widget _poster() {
    const placeholder = SizedBox(
      height: 160,
      width: double.infinity,
      child: ColoredBox(
        color: AppColors.ink600,
        child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 40),
      ),
    );

    Widget net(String url, ImageErrorWidgetBuilder onError) => Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: onError,
        );

    final poster = widget.poster;
    if (poster == null) return placeholder;

    return net(poster, (_, __, ___) {
      final fallback = widget.posterFallback;
      if (fallback != null && fallback != poster) {
        return net(fallback, (_, __, ___) => placeholder);
      }
      return placeholder;
    });
  }
}

/// A YouTube video that plays inside its card. Projects with only a YouTube
/// link have no mp4 to stream, so the embed player is hosted in a web view
/// (YouTube permits embedded playback — it only forbids OAuth in web views).
class InlineYoutube extends StatefulWidget {
  final String videoId;
  final String? poster;

  const InlineYoutube({super.key, required this.videoId, this.poster});

  @override
  State<InlineYoutube> createState() => _InlineYoutubeState();
}

class _InlineYoutubeState extends State<InlineYoutube> {
  WebViewController? _controller;

  void _start() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.ink);

    // Without this the embed ignores autoplay and shows a second play button.
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    controller.loadRequest(Uri.parse(youtubeEmbed(widget.videoId)));
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c != null) {
      return AspectRatio(aspectRatio: 16 / 9, child: WebViewWidget(controller: c));
    }

    return GestureDetector(
      onTap: _start,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            widget.poster ?? 'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg',
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 160,
              width: double.infinity,
              child: ColoredBox(
                color: AppColors.ink600,
                child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 40),
              ),
            ),
          ),
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}
