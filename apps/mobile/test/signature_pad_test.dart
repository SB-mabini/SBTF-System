import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/widgets/signature_pad.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  /// Rasterising needs the real event loop, which widget tests fake. Every
  /// engine call (encode and decode) therefore goes through `runAsync`.
  Future<Uint8List?> export(WidgetTester tester, SignaturePadController c) {
    return tester.runAsync<Uint8List?>(() => c.exportPng());
  }

  testWidgets('exportPng returns null before anything is drawn',
      (tester) async {
    final controller = SignaturePadController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(SignaturePad(controller: controller)));
    await tester.pumpAndSettle();

    expect(controller.hasInk.value, isFalse);
    expect(await export(tester, controller), isNull);
  });

  testWidgets('the drawing survives the pad being disposed and rebuilt',
      (tester) async {
    final controller = SignaturePadController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(SignaturePad(controller: controller)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SignaturePad), const Offset(60, 24));
    await tester.pumpAndSettle();
    expect(controller.hasInk.value, isTrue);
    expect(controller.strokes, isNotEmpty);

    // Simulate scrolling the pad far enough out of a long form that Flutter
    // disposes it, then scrolling back: the strokes used to live in the pad's
    // State and were lost here, which is how a blank pad reached the printer.
    await tester.pumpWidget(host(const SizedBox(height: 600)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(SignaturePad(controller: controller)));
    await tester.pumpAndSettle();

    expect(controller.hasInk.value, isTrue);
    expect(controller.strokes, isNotEmpty);

    final bytes = await export(tester, controller);
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(0));
  });

  testWidgets('the export contains ink and no pad border or placeholder',
      (tester) async {
    final controller = SignaturePadController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(SignaturePad(controller: controller)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SignaturePad), const Offset(80, 30));
    await tester.pumpAndSettle();

    final bytes = await export(tester, controller);
    expect(bytes, isNotNull);

    final raw = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final data = pixels?.buffer.asUint8List();
      image.dispose();
      codec.dispose();
      return data;
    });
    expect(raw, isNotNull);

    var inkPixels = 0;
    for (var index = 3; index < raw!.length; index += 4) {
      if (raw[index] != 0) inkPixels++;
    }
    expect(inkPixels, greaterThan(0), reason: 'the exported PNG has ink');

    // The pad's border and "Sign here" placeholder used to be captured with
    // the drawing. A transparent corner proves the export is ink only.
    expect(raw[3], 0, reason: 'the top-left pixel is transparent');
  });

  testWidgets('clear empties the drawing and turns hasInk off', (tester) async {
    final controller = SignaturePadController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(SignaturePad(controller: controller)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SignaturePad), const Offset(50, 20));
    await tester.pumpAndSettle();
    expect(controller.hasInk.value, isTrue);

    await tester.tap(find.text('Clear signature'));
    await tester.pumpAndSettle();

    expect(controller.hasInk.value, isFalse);
    expect(controller.strokes, isEmpty);
    expect(await export(tester, controller), isNull);
  });
}
