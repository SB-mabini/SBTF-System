import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:sbtf_mobile/core/ui.dart';

/// A controller for [SignaturePad].
///
/// The screen keeps one controller in its state, listens to [hasInk] to show the
/// submit control, and calls [exportPng] to upload the drawing.
///
/// The strokes live here rather than in the pad's [State] so the drawing
/// survives the pad being rebuilt or scrolled out of the list. Previously the
/// list could dispose the pad while the driver scrolled down to Submit, which
/// silently emptied the drawing and uploaded a blank pad.
class SignaturePadController {
  /// Every stroke drawn so far, in pad coordinates.
  final List<List<Offset>> strokes = <List<Offset>>[];

  /// True once at least one stroke has been drawn.
  final ValueNotifier<bool> hasInk = ValueNotifier<bool>(false);

  /// The pad's last laid-out size. Only used to rasterise the export.
  Size _size = const Size(360, 180);

  VoidCallback? _clear;

  /// Clears every stroke.
  void clear() => _clear?.call();

  /// Exports the drawing as a transparent PNG.
  ///
  /// Strokes are replayed onto a fresh canvas instead of screenshotting the
  /// widget, so the file carries only the ink — not the pad's border or its
  /// "Sign here" placeholder. The image is cropped to the ink with a small
  /// margin, so the printed letter shows a signature and not a mostly blank
  /// box.
  ///
  /// Returns null when nothing has been drawn.
  Future<Uint8List?> exportPng({double pixelRatio = 3}) async {
    if (!hasInk.value || strokes.isEmpty) return null;

    final bounds = _inkBounds();
    if (bounds == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    canvas.translate(-bounds.left, -bounds.top);
    _paintStrokes(canvas, strokes);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (bounds.width * pixelRatio).round().clamp(1, 100000),
      (bounds.height * pixelRatio).round().clamp(1, 100000),
    );
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// The smallest rectangle that contains every stroke, padded a little and
  /// clamped to the pad.
  Rect? _inkBounds() {
    double? left, top, right, bottom;
    for (final stroke in strokes) {
      for (final point in stroke) {
        left = left == null ? point.dx : (point.dx < left ? point.dx : left);
        top = top == null ? point.dy : (point.dy < top ? point.dy : top);
        right =
            right == null ? point.dx : (point.dx > right ? point.dx : right);
        bottom =
            bottom == null ? point.dy : (point.dy > bottom ? point.dy : bottom);
      }
    }
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }

    const padding = 8.0;
    final rect = Rect.fromLTRB(
      (left - padding).clamp(0.0, _size.width),
      (top - padding).clamp(0.0, _size.height),
      (right + padding).clamp(0.0, _size.width),
      (bottom + padding).clamp(0.0, _size.height),
    );
    if (rect.width < 1 || rect.height < 1) return null;
    return rect;
  }

  void dispose() {
    hasInk.dispose();
  }
}

/// A simple in-app signature drawing surface.
///
/// Uses only Flutter primitives (no plugin): pointer strokes are painted by a
/// [CustomPainter] and rasterised to PNG for upload. The signature is an
/// electronic signature; the office may still ask for a wet-signed printed copy.
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    this.controller,
    this.height = 180,
    this.onChanged,
  });

  final SignaturePadController? controller;
  final double height;
  final ValueChanged<bool>? onChanged;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  List<Offset>? _current;
  SignaturePadController? _owned;
  int? _activePointer;

  SignaturePadController get _controller =>
      widget.controller ?? (_owned ??= SignaturePadController());

  @override
  void initState() {
    super.initState();
    _controller._clear = _clear;
  }

  @override
  void didUpdateWidget(covariant SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller._clear = _clear;
    }
  }

  @override
  void dispose() {
    _controller._clear = null;
    _owned?.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _controller.strokes.clear();
      _current = null;
      _activePointer = null;
    });
    _setInk(false);
  }

  void _setInk(bool value) {
    _controller.hasInk.value = value;
    widget.onChanged?.call(value);
  }

  void _start(Offset point) {
    setState(() {
      _current = <Offset>[point];
      _controller.strokes.add(_current!);
    });
    _setInk(true);
  }

  void _extend(Offset point) {
    final current = _current;
    if (current == null) return;
    setState(() => current.add(point));
  }

  void _end() {
    _current = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _controller._size =
                  Size(constraints.maxWidth, constraints.maxHeight);
              // The eager recognizer claims the pointer before the
              // surrounding scroll view can turn a vertical stroke into a
              // page scroll. The Listener draws from raw pointer events, so
              // the first dot is captured too.
              return RawGestureDetector(
                gestures: <Type, GestureRecognizerFactory>{
                  EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                      EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (_) {},
                  ),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if (_activePointer != null) return;
                    _activePointer = event.pointer;
                    _start(event.localPosition);
                  },
                  onPointerMove: (event) {
                    if (event.pointer != _activePointer) return;
                    _extend(event.localPosition);
                  },
                  onPointerUp: (event) {
                    if (event.pointer != _activePointer) return;
                    _activePointer = null;
                    _end();
                  },
                  onPointerCancel: (event) {
                    if (event.pointer != _activePointer) return;
                    _activePointer = null;
                    _end();
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(strokes: _controller.strokes),
                    child: _controller.strokes.isEmpty
                        ? const Center(
                            child: Text(
                              'Sign here',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _controller.strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Clear signature'),
          ),
        ),
      ],
    );
  }
}

/// Draws [strokes] with the app's signature ink. Shared by the on-screen pad
/// and the PNG export so the printed signature matches what was drawn.
void _paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
  final paint = Paint()
    ..color = const Color(0xFF0F172A)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6;

  for (final stroke in strokes) {
    if (stroke.isEmpty) continue;
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, 1.3, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (final point in stroke.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) => _paintStrokes(canvas, strokes);

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
