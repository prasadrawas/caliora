import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/theme/theme_colors.dart';

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  late MobileScannerController _controller;
  bool _hasScanned = false;
  bool _torchOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    log.i('[BarcodeScreen] Scanner initialized');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    log.i('[BarcodeScreen] Scanned: $code (format: ${barcode.format})');

    _hasScanned = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanWidth = screenSize.width * 0.75;
    const scanHeight = 180.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              log.e('[BarcodeScreen] Camera error: ${error.errorCode}');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Camera error: ${error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: C.of(context).text70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please grant camera permission in settings',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: C.of(context).text30, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scan area guide
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Container(
                width: scanWidth,
                height: scanHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.accentGreen,
                    width: 2.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Corner accents
                    ..._buildCorners(scanWidth, scanHeight),
                    // Scan line animation
                    _buildScanLine(scanWidth),
                  ],
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner,
                              color: AppColors.accentGreen, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Scan Barcode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _circleButton(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      () {
                        _controller.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          color: C.of(context).text54, size: 18),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Point camera at the barcode on the packaging',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  List<Widget> _buildCorners(double width, double height) {
    const size = 24.0;
    const thickness = 4.0;
    const color = AppColors.accentGreen;

    Widget corner({
      required AlignmentGeometry alignment,
      required BorderRadius borderRadius,
    }) {
      return Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: alignment == Alignment.topLeft ||
                      alignment == Alignment.topRight
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              bottom: alignment == Alignment.bottomLeft ||
                      alignment == Alignment.bottomRight
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              left: alignment == Alignment.topLeft ||
                      alignment == Alignment.bottomLeft
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              right: alignment == Alignment.topRight ||
                      alignment == Alignment.bottomRight
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return [
      corner(
          alignment: Alignment.topLeft,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16))),
      corner(
          alignment: Alignment.topRight,
          borderRadius:
              const BorderRadius.only(topRight: Radius.circular(16))),
      corner(
          alignment: Alignment.bottomLeft,
          borderRadius:
              const BorderRadius.only(bottomLeft: Radius.circular(16))),
      corner(
          alignment: Alignment.bottomRight,
          borderRadius:
              const BorderRadius.only(bottomRight: Radius.circular(16))),
    ];
  }

  Widget _buildScanLine(double width) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Positioned(
          top: value * 160,
          left: 8,
          right: 8,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.accentGreen.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (mounted) setState(() {});
      },
    );
  }
}
