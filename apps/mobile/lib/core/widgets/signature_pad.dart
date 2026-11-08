import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A controller for [SignaturePad].
///
/// The screen keeps one controller in its state, listens to [hasInk] to enable
/// the submit button, and calls [exportPng] to upload the drawing.
class SignaturePadController {
  final GlobalKey _boundaryKey = GlobalKey();

  /// True once at least one stroke has been drawn.
  final ValueNotifier<bool> hasInk = ValueNotifier<bool>(false);

  VoidCallback? _clear;

  /// Clears every stroke.
  void clear() => _clear?.call();

  /// Exports the drawing as a PNG (transparent ink on white).
  ///
  /// Returns null when nothing has been drawn.
  Future<Uint8List?> exportPng({double pixelRatio = 3}) async {
    if (!hasInk.value) return null;

    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  void dispose() {
    hasInk.dispose();
  }
}

/// A simple in-app signature drawing surface.
///
/// Uses only Flutter primitives (no plugin): pointer strokes are painted by a
/// [CustomPainter] inside a [RepaintBoundary], which is rasterised to PNG for
/// upload. The signature is an electronic signature; the office may still ask
/// for a wet-signed printed copy.
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
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset>? _current;
  SignaturePadController? _owned;
  Size _size = Size.zero;
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
      _strokes.clear();
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
      _strokes.add(_current!);
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
        RepaintBoundary(
          key: _controller._boundaryKey,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _size = Size(constraints.maxWidth, constraints.maxHeight);
                // The eager recognizer claims the pointer before the
                // surrounding scroll view can turn a vertical stroke into a
                // page scroll. The Listener draws from raw pointer events, so
                // the first dot is captured too.
                return RawGestureDetector(
                  gestures: <Type, GestureRecognizerFactory>{
                    EagerGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          EagerGestureRecognizer
                        >(EagerGestureRecognizer.new, (_) {}),
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
                      size: _size,
                      painter: _SignaturePainter(strokes: _strokes),
                      child: _strokes.isEmpty
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
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Clear signature'),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
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

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
