import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({
    super.key,
    required this.player,
    required this.child,
  });

  final Player player;
  final Widget child;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  _SwipeKind? _kind;
  double _value = 0;
  bool _showHud = false;
  Offset? _lastFocal;

  @override
  void dispose() {
    ScreenBrightness.instance.resetApplicationScreenBrightness();
    super.dispose();
  }

  Future<void> _begin(Offset local, Size size) async {
    _kind = local.dx < size.width / 2 ? _SwipeKind.brightness : _SwipeKind.volume;
    _lastFocal = local;
    try {
      if (_kind == _SwipeKind.brightness) {
        _value = (await ScreenBrightness.instance.application).clamp(0, 1);
      } else {
        VolumeController.instance.showSystemUI = false;
        _value = (await VolumeController.instance.getVolume()).clamp(0, 1);
      }
      setState(() => _showHud = true);
    } catch (_) {
      _kind = null;
    }
  }

  Future<void> _update(Offset local, Size size) async {
    if (_kind == null || _lastFocal == null) {
      return;
    }
    final delta = (_lastFocal!.dy - local.dy) / size.height;
    _lastFocal = local;
    _value = (_value + delta).clamp(0.0, 1.0);
    try {
      if (_kind == _SwipeKind.brightness) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(_value);
      } else {
        await VolumeController.instance.setVolume(_value);
      }
    } catch (_) {}
    setState(() {});
  }

  void _end() {
    setState(() {
      _showHud = false;
      _kind = null;
      _lastFocal = null;
    });
  }

  Future<void> _skip(TapDownDetails details, Size size) async {
    final backward = details.localPosition.dx < size.width / 2;
    final current = widget.player.state.position;
    final target = backward
        ? current - const Duration(seconds: 10)
        : current + const Duration(seconds: 10);
    await widget.player.seek(
      target < Duration.zero ? Duration.zero : target,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (details) => _begin(details.localPosition, size),
          onVerticalDragUpdate: (details) => _update(details.localPosition, size),
          onVerticalDragEnd: (_) => _end(),
          onVerticalDragCancel: _end,
          onDoubleTapDown: (details) => _skip(details, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (_showHud && _kind != null)
                IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _kind == _SwipeKind.brightness
                                  ? Icons.wb_sunny_outlined
                                  : Icons.volume_up_outlined,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _kind == _SwipeKind.brightness
                                  ? 'Brightness'
                                  : 'Volume',
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                value: _value,
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${(_value * 100).round()}%'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _SwipeKind { brightness, volume }
