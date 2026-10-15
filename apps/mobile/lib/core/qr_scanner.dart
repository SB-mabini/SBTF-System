import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Receives the first QR value a scanner view reads.
typedef QrScanCallback = void Function(String value);

/// Builds the camera preview that watches for a QR code and reports it through
/// [onDetect].
///
/// The screen depends on this shape rather than on `mobile_scanner` directly,
/// so the scanner view can be swapped for a fake in widget tests — a camera
/// cannot run under `flutter test`. This mirrors how `DocumentPicker` keeps the
/// file chooser out of the wizard's tests.
typedef QrScannerViewBuilder = Widget Function(
  BuildContext context,
  QrScanCallback onDetect,
);

/// The default builder: a live camera preview.
///
/// Returns the value of the first QR code it detects. The screen replaces this
/// widget once it has a value, which disposes the preview and stops the camera
/// for free, so nothing here needs to pause explicitly.
Widget buildCameraQrScanner(BuildContext context, QrScanCallback onDetect) {
  return _CameraQrScanner(onDetect: onDetect);
}

class _CameraQrScanner extends StatefulWidget {
  const _CameraQrScanner({required this.onDetect});

  final QrScanCallback onDetect;

  @override
  State<_CameraQrScanner> createState() => _CameraQrScannerState();
}

class _CameraQrScannerState extends State<_CameraQrScanner> {
  /// Guards against the burst of duplicate frames a camera reports for the same
  /// code before the screen has swapped this widget out.
  bool _reported = false;

  void _handleCapture(BarcodeCapture capture) {
    if (_reported) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _reported = true;
        widget.onDetect(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: _handleCapture,
      errorBuilder: (context, error) =>
          _CameraError(message: error.errorCode.message),
    );
  }
}

/// Shown when the camera cannot start — most often a denied permission.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 40),
              const SizedBox(height: 12),
              const Text(
                'The camera could not be started.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                'You can still verify a certificate by typing its code below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
