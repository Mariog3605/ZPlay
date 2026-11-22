import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Experimental AVFoundation playback for direct, authorized HTTPS media.
/// Unsupported formats and missing native plugins show a recoverable error.
class TvOSNativePlayer extends StatefulWidget {
  const TvOSNativePlayer({
    super.key,
    required this.title,
    required this.url,
    this.initialPosition,
  });

  final String title;
  final String? url;
  final Duration? initialPosition;

  @override
  State<TvOSNativePlayer> createState() => _TvOSNativePlayerState();
}

class _TvOSNativePlayerState extends State<TvOSNativePlayer> {
  VideoPlayerController? _controller;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error =
          'This source is not supported by the Apple TV beta. '
          'Only direct HTTPS media is supported; torrent playback is unavailable.');
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      controller.addListener(_onPlayerChanged);
      await controller.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      final start = widget.initialPosition;
      if (start != null && start > Duration.zero &&
          start < controller.value.duration) {
        await controller.seekTo(start);
      }
      if (!mounted) return;
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error =
          'AVPlayer could not open this media. The format, connection, '
          'or source may not be supported.');
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    if (_controller?.value.hasError ?? false) {
      _error = 'Playback failed. Return to the previous screen to try again.';
    }
    setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.removeListener(_onPlayerChanged);
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c == null || !_ready || _error != null) return;
    try {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Playback control failed.');
    }
  }

  Future<void> _seek(int seconds) async {
    final c = _controller;
    if (c == null || !_ready || _error != null) return;
    final max = c.value.duration.inMilliseconds;
    if (max <= 0) return;
    final ms = (c.value.position.inMilliseconds + seconds * 1000)
        .clamp(0, max).toInt();
    try {
      await c.seekTo(Duration(milliseconds: ms));
    } catch (_) {
      if (mounted) setState(() => _error = 'Seeking is unavailable.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text(_error!, textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 24)),
                      )
                    : !_ready || c == null
                        ? const CircularProgressIndicator()
                        : AspectRatio(
                            aspectRatio: c.value.aspectRatio > 0
                                ? c.value.aspectRatio : 16 / 9,
                            child: VideoPlayer(c),
                          ),
              ),
            ),
            Positioned(
              top: 24, left: 24, right: 24,
              child: Row(children: [
                FilledButton(
                  autofocus: !_ready || _error != null,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 24),
                Expanded(child: Text(widget.title, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 22))),
              ]),
            ),
            if (_ready && c != null && _error == null)
              Positioned(bottom: 24, left: 24, right: 24,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  VideoProgressIndicator(c, allowScrubbing: false),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FilledButton(onPressed: () => _seek(-10),
                        child: const Text('−10 s')),
                    const SizedBox(width: 16),
                    FilledButton(autofocus: true, onPressed: _toggle,
                        child: Text(c.value.isPlaying ? 'Pause' : 'Play')),
                    const SizedBox(width: 16),
                    FilledButton(onPressed: () => _seek(10),
                        child: const Text('+10 s')),
                  ]),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
