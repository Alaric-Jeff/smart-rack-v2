import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _hasScanned = false;

  // Animation for the scanning line
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      // Validate it's the expected JSON format before popping
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data.containsKey('macId') && data.containsKey('pairingCode')) {
          _hasScanned = true;
          Navigator.pop(context, raw);
          return;
        } else {
          _showError("Invalid QR: Missing macId or pairingCode.");
          return;
        }
      } catch (_) {
        _showError("Not a valid Smart Rack QR code.");
        return;
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        onVisible: () {
          // Allow re-scanning after error
          Future.delayed(const Duration(seconds: 2), () {
            _hasScanned = false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double scanAreaSize = MediaQuery.of(context).size.width * 0.70;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Scan Device QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 🔦 Torch toggle
          ValueListenableBuilder(
            valueListenable: cameraController,
            builder: (context, state, child) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                iconSize: 28.0,
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.yellow : Colors.white,
                ),
                onPressed: () => cameraController.toggleTorch(),
              );
            },
          ),
          // 📷 Camera flip
          ValueListenableBuilder(
            valueListenable: cameraController,
            builder: (context, state, child) {
              final isFront = state.cameraDirection == CameraFacing.front;
              return IconButton(
                iconSize: 28.0,
                icon: Icon(
                  isFront ? Icons.camera_front : Icons.camera_rear,
                  color: Colors.white,
                ),
                onPressed: () => cameraController.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 📸 Full screen camera feed
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // 🌑 Dimmed overlay with cutout
          _buildDimmedOverlay(scanAreaSize),

          // 🎯 Scan frame + animated line
          _buildScanFrame(scanAreaSize),

          // 📝 Top & bottom labels
          _buildLabels(scanAreaSize),
        ],
      ),
    );
  }

  /// Dark overlay with a transparent square cutout in the center
  Widget _buildDimmedOverlay(double scanAreaSize) {
    return CustomPaint(
      painter: _OverlayPainter(scanAreaSize: scanAreaSize),
      child: const SizedBox.expand(),
    );
  }

  /// The blue corner brackets + animated scan line inside the cutout
  Widget _buildScanFrame(double scanAreaSize) {
    return Center(
      child: SizedBox(
        width: scanAreaSize,
        height: scanAreaSize,
        child: Stack(
          children: [
            // Corner brackets
            _buildCorner(Alignment.topLeft),
            _buildCorner(Alignment.topRight),
            _buildCorner(Alignment.bottomLeft),
            _buildCorner(Alignment.bottomRight),

            // Animated scan line
            AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                return Positioned(
                  top: _scanLineAnimation.value * (scanAreaSize - 4),
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF2962FF).withOpacity(0.8),
                          const Color(0xFF2962FF),
                          const Color(0xFF2962FF).withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2962FF).withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Instruction texts above and below the frame
  Widget _buildLabels(double scanAreaSize) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Text above frame
          const Text(
            'Point camera at the QR code\non your Smart Rack device',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),

          SizedBox(height: 32 + scanAreaSize + 32),

          // Text below frame
          const Text(
            'Make sure the QR code is well-lit\nand fits inside the frame',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    const double size = 28;
    const double thickness = 4;
    const Color color = Color(0xFF2962FF);
    const radius = Radius.circular(4);

    final bool isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final bool isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerPainter(
            isLeft: isLeft,
            isTop: isTop,
            color: color,
            thickness: thickness,
            radius: radius,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Dimmed overlay with transparent center cutout
// ──────────────────────────────────────────────
class _OverlayPainter extends CustomPainter {
  final double scanAreaSize;

  _OverlayPainter({required this.scanAreaSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.62);

    final center = Offset(size.width / 2, size.height / 2);
    final half = scanAreaSize / 2;
    const cornerRadius = Radius.circular(16);

    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        center.dx - half,
        center.dy - half,
        center.dx + half,
        center.dy + half,
      ),
      cornerRadius,
    );

    // Full screen path minus the cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.scanAreaSize != scanAreaSize;
}

// ──────────────────────────────────────────────
// Corner bracket painter
// ──────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;
  final Color color;
  final double thickness;
  final Radius radius;

  _CornerPainter({
    required this.isLeft,
    required this.isTop,
    required this.color,
    required this.thickness,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isLeft && isTop) {
      path.moveTo(0, size.height);
      path.lineTo(0, radius.x);
      path.arcToPoint(Offset(radius.x, 0), radius: radius);
      path.lineTo(size.width, 0);
    } else if (!isLeft && isTop) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius.x, 0);
      path.arcToPoint(Offset(size.width, radius.x), radius: radius);
      path.lineTo(size.width, size.height);
    } else if (isLeft && !isTop) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - radius.x);
      path.arcToPoint(Offset(radius.x, size.height), radius: radius);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - radius.x);
      path.arcToPoint(Offset(size.width - radius.x, size.height), radius: radius);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => false;
} 