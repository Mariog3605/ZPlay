import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/player/player_top_bar.dart';
import '../../widgets/player/player_transport.dart';

/// Experimental AVFoundation playback for direct, authorized HTTPS media.
/// Unsupported formats and missing native plugins show a recoverable error.
class TvOSNativePlayer extends StatefulWidget {
  const TvOSNativePlayer({
    super.key,
    required this.title,
    required this.url,
    this.initialPosition,
    this.subtitle,
    this.sourceLabel,
  });

  final String title;
  final String? url;
  final Duration? initialPosition;
  final String? subtitle;
  final String? sourceLabel;

  @override
  State<TvOSNativePlayer> createState() => _TvOSNativePlayerState();
}

class _TvOSNativePlayerState extends State<TvOSNativePlayer> {
  VideoPlayerController? _controller;
  String? _error;
  bool _ready = false;
  bool _controlsVisible = true;
  bool _menuOpen = false;
  bool _scrubbing = false;
  double _lastVolume = 1;
  BoxFit _fit = BoxFit.contain;
  Timer? _hideTimer;
  final _pageFocus = FocusNode(debugLabel: 'tvOS player');
  final _playFocus = FocusNode(debugLabel: 'tvOS play/pause');
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _buffered = ValueNotifier<Duration?>(null);

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
      if (mounted) {
        setState(() => _ready = true);
        _showControls();
      }
    } catch (_) {
      if (mounted) setState(() => _error =
          'AVPlayer could not open this media. The format, connection, '
          'or source may not be supported.');
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value == null) return;
    _position.value = value.position;
    _buffered.value = value.buffered.isEmpty ? null : value.buffered.last.end;
    if (value.hasError) {
      _error = 'Playback failed. Return to the previous screen to try again.';
      _controlsVisible = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageFocus.dispose();
    _playFocus.dispose();
    _position.dispose();
    _buffered.dispose();
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
      _showControls();
    } catch (_) {
      if (mounted) setState(() => _error = 'Playback control failed.');
    }
  }

  Future<void> _seek(int seconds) async {
    final c = _controller;
    if (c == null || !_ready || _error != null) return;
    await _seekTo(c.value.position + Duration(seconds: seconds));
  }

  Future<void> _seekTo(Duration target) async {
    final c = _controller;
    if (c == null || !_ready || _error != null) return;
    final max = c.value.duration.inMilliseconds;
    if (max <= 0) return;
    final ms = target.inMilliseconds.clamp(0, max).toInt();
    try {
      await c.seekTo(Duration(milliseconds: ms));
      _showControls(focus: false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Seeking is unavailable.');
    }
  }

  void _showControls({bool focus = true}) {
    if (!mounted) return;
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    if (focus && _ready && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controlsVisible && !_menuOpen) _playFocus.requestFocus();
      });
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_menuOpen || _scrubbing || !_ready || _error != null ||
        !(_controller?.value.isPlaying ?? false)) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _menuOpen || _scrubbing ||
          !(_controller?.value.isPlaying ?? false)) return;
      setState(() => _controlsVisible = false);
      _pageFocus.requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      unawaited(_toggle());
      return KeyEventResult.handled;
    }
    if (!_controlsVisible && !_menuOpen) {
      if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        _showControls();
        return KeyEventResult.handled;
      }
    }
    _scheduleHide();
    return KeyEventResult.ignored;
  }

  Future<void> _setVolume(double value) async {
    final c = _controller;
    if (c == null || !_ready) return;
    final volume = value.clamp(0.0, 1.0).toDouble();
    try {
      await c.setVolume(volume);
      if (volume > 0) _lastVolume = volume;
    } catch (_) {}
    _showControls(focus: false);
  }

  void _toggleMute() {
    final volume = _controller?.value.volume ?? 0;
    unawaited(_setVolume(volume > 0 ? 0 : _lastVolume));
  }

  Future<void> _chooseSpeed() async {
    final c = _controller;
    if (c == null || !_ready) return;
    _menuOpen = true;
    _hideTimer?.cancel();
    final rate = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Playback speed'),
        children: [
          for (final rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, rate),
              child: Text('${rate}×${c.value.playbackSpeed == rate ? ' ✓' : ''}'),
            ),
        ],
      ),
    );
    _menuOpen = false;
    if (!mounted) return;
    if (rate != null) {
      try { await c.setPlaybackSpeed(rate); } catch (_) {}
    }
    _showControls();
  }

  Future<void> _chooseAspect() async {
    _menuOpen = true;
    _hideTimer?.cancel();
    final selected = await showDialog<BoxFit>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Video aspect ratio'),
        children: [
          for (final entry in const {
            BoxFit.contain: 'Original aspect ratio',
            BoxFit.cover: 'Zoom to fill screen',
            BoxFit.fill: 'Stretch to fit',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(entry.value + (_fit == entry.key ? ' ✓' : '')),
            ),
        ],
      ),
    );
    _menuOpen = false;
    if (!mounted) return;
    if (selected != null) setState(() => _fit = selected);
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final active = _ready && c != null && _error == null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _pageFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text(_error!, textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 24)),
                      )
                    : !active || c == null
                        ? const CircularProgressIndicator()
                        : ClipRect(
                            child: SizedBox.expand(
                              child: FittedBox(
                                fit: _fit,
                                child: SizedBox(
                                  width: c.value.size.width > 0 ? c.value.size.width : 1920,
                                  height: c.value.size.height > 0 ? c.value.size.height : 1080,
                                  child: VideoPlayer(c),
                                ),
                              ),
                            ),
                          ),
              ),
            ),
            if (_controlsVisible || !active)
              Positioned(top: 0, left: 0, right: 0,
                child: PlayerTopBar(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  sourceLabel: widget.sourceLabel,
                  onBack: () => Navigator.of(context).pop(),
                  // Return to the existing source list instead of creating a
                  // second incompatible player route.
                  onShowSources: widget.sourceLabel == null
                      ? null : () => Navigator.of(context).pop(),
                ),
              ),
            if (_controlsVisible && active && c != null)
              Positioned(bottom: 0, left: 0, right: 0,
                child: SafeArea(top: false, child: PlayerTransport(
                  isPlaying: c.value.isPlaying,
                  positionListenable: _position,
                  duration: c.value.duration,
                  bufferedListenable: _buffered,
                  volume: c.value.volume,
                  isMuted: c.value.volume == 0,
                  playbackRate: c.value.playbackSpeed,
                  isSubtitlesActive: false,
                  isSubSyncActive: false,
                  isAudioActive: false,
                  isFullscreen: true,
                  showAudioSubtitleControls: false,
                  showFullscreenControl: false,
                  allowVolumeBoost: false,
                  entryFocusNode: _playFocus,
                  onPlayPause: _toggle,
                  onSeek: _seekTo,
                  onSeekBack10: () => _seek(-10),
                  onSeekForward10: () => _seek(10),
                  onVolumeChanged: _setVolume,
                  onToggleMute: _toggleMute,
                  onToggleAspectMenu: _chooseAspect,
                  onToggleSpeedMenu: _chooseSpeed,
                  onToggleAudioMenu: () {},
                  onToggleSubtitleMenu: () {},
                  onToggleSubSync: () {},
                  onToggleFullscreen: () {},
                  onScrubbingChanged: (value) {
                    _scrubbing = value;
                    _scheduleHide();
                  },
                )),
              ),
          ],
        ),
      ),
    );
  }
}
