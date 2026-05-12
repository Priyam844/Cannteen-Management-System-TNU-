import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'api_service.dart';

class ManagerQRScanPage extends StatefulWidget {
  final VoidCallback? onScanSuccess;
  const ManagerQRScanPage({super.key, this.onScanSuccess});

  @override
  State<ManagerQRScanPage> createState() => _ManagerQRScanPageState();
}

class _ManagerQRScanPageState extends State<ManagerQRScanPage> {
  bool isProcessing = false;
  String? lastScanned;
  MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  ////////////////////////////////////////////////////////////
  /// HANDLE QR SCAN
  ////////////////////////////////////////////////////////////
  Future<void> handleScan(String qrData) async {
    if (isProcessing || qrData == lastScanned) return;

    setState(() {
      isProcessing = true;
      lastScanned = qrData;
    });

    try {
      final String uuid = qrData.trim();

      if (uuid.isEmpty || uuid.length < 10) {
        throw Exception("Invalid QR code");
      }

      final response = await ApiService.post("/scan-meal/", {"qr_uuid": uuid});
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (widget.onScanSuccess != null) widget.onScanSuccess!();
        _showVerificationResult(
          success: true,
          studentName: data["student"]["name"],
          slot: data["meal"]["slot"],
          combo: data["meal"]["combo"],
        );
      } else {
        _showVerificationResult(
          success: false,
          error: data["error"] ?? "Failed to verify meal",
        );
      }
    } catch (e) {
      _showVerificationResult(success: false, error: e.toString());
    }

    // Delay to prevent accidental double scans
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => isProcessing = false);
  }

  ////////////////////////////////////////////////////////////
  /// RESULT UI (BOTTOM SHEET STYLE)
  ////////////////////////////////////////////////////////////
  void _showVerificationResult({
    required bool success,
    String? studentName,
    String? slot,
    String? combo,
    String? error,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: success ? Colors.green : Colors.red,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              success ? "VERIFIED" : "FAILED",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: success ? Colors.green : Colors.red,
                letterSpacing: 2,
              ),
            ),
            const Divider(height: 32),
            if (success) ...[
              _resultRow("Student", studentName ?? ""),
              _resultRow("Slot", slot?.toUpperCase() ?? ""),
              _resultRow("Meal", combo ?? ""),
            ] else ...[
              Text(
                error ?? "Unknown Error",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("CONTINUE SCANNING", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off: return const Icon(Icons.flash_off);
                  case TorchState.on: return const Icon(Icons.flash_on);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (barcodeCapture) {
              final List<Barcode> barcodes = barcodeCapture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  handleScan(code);
                  break;
                }
              }
            },
          ),
          
          // --- CUSTOM SCANNER OVERLAY ---
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),

          // --- SCANNING LINE ANIMATION (SIMULATED WITH POSITIONED) ---
          const Positioned(
            top: 0, bottom: 0, left: 0, right: 0,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Align QR code within the frame",
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 300), // Height of scan area
                ],
              ),
            ),
          ),

          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// SCANNER OVERLAY PAINTER
////////////////////////////////////////////////////////////
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    
    // Transparent area for scanning
    const double scanAreaSize = 250.0;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final Rect scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Draw darkened outer area
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(20))),
      ),
      paint,
    );

    // Draw white corners/border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(20)), borderPaint);
    
    // Optional: Draw corner accents
    final cornerPaint = Paint()
      ..color = const Color.fromARGB(255, 152, 29, 68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    
    const double lineLen = 30.0;
    // Top Left
    canvas.drawLine(Offset(left, top + lineLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + lineLen, top), cornerPaint);
    // Top Right
    canvas.drawLine(Offset(left + scanAreaSize - lineLen, top), Offset(left + scanAreaSize, top), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top), Offset(left + scanAreaSize, top + lineLen), cornerPaint);
    // Bottom Left
    canvas.drawLine(Offset(left, top + scanAreaSize - lineLen), Offset(left, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left, top + scanAreaSize), Offset(left + lineLen, top + scanAreaSize), cornerPaint);
    // Bottom Right
    canvas.drawLine(Offset(left + scanAreaSize - lineLen, top + scanAreaSize), Offset(left + scanAreaSize, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top + scanAreaSize), Offset(left + scanAreaSize, top + scanAreaSize - lineLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}