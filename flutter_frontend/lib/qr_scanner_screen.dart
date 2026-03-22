import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _hasScanned = false; // 🔒 Prevent multiple pops

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan Device QR',
          style: TextStyle(color: Colors.white),
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
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 📸 Camera feed
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_hasScanned) return; // ignore further detections

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _hasScanned = true;
                  // ✅ Returns the raw QR string back to DevicePairingScreen
                  // Expected format: {"macId": "mac-id-001", "pairingCode": "123456"}
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),

          // 🎯 Scan overlay UI
          _buildScanOverlay(context),
        ],
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    final double scanAreaSize = MediaQuery.of(context).size.width * 0.7;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // Instruction text
        const Text(
          'Point camera at the QR code\non your Smart Rack device',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),

        // Scan frame
        Center(
          child: SizedBox(
            width: scanAreaSize,
            height: scanAreaSize,
            child: Stack(
              children: [
                // Dimmed border effect
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                // Corner accents — Top Left
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),
        const Text(
          'Make sure the QR code is well-lit\nand fits inside the frame',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),

        const Spacer(flex: 3),
      ],
    );
  }

  // Styled corner bracket for the scan frame
  Widget _buildCorner(Alignment alignment) {
    const double size = 24;
    const double thickness = 4;
    const Color color = Color(0xFF2962FF);
    const radius = Radius.circular(4);

    final bool isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final bool isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;

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

// Custom painter for the corner brackets
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