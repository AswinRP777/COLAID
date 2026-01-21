import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/color_utils.dart';

class LiveVideoPreviewPage extends StatefulWidget {
  final CameraController controller;

  const LiveVideoPreviewPage({super.key, required this.controller});

  @override
  State<LiveVideoPreviewPage> createState() => _LiveVideoPreviewPageState();
}

class _LiveVideoPreviewPageState extends State<LiveVideoPreviewPage> {
  String selectedDefect = "protanopia";
  double intensity = 1.0; // 🔥 NEW: intensity slider value

  final FlutterTts flutterTts = FlutterTts();
  final GlobalKey repaintKey = GlobalKey();
  String detectedColor = "";

  // Identity matrix (4x5 color matrix format)
  // [ R',  G',  B',  A', offset ]
  static const List<double> _identityMatrix = [
    // R    G    B    A   offset
    1.0, 0.0, 0.0, 0.0, 0.0, // Red channel
    0.0, 1.0, 0.0, 0.0, 0.0, // Green channel
    0.0, 0.0, 1.0, 0.0, 0.0, // Blue channel
    0.0, 0.0, 0.0, 1.0, 0.0, // Alpha channel
  ];

  // Correction Matrices (from daltonize.py algorithm)
  // These are ADDED to identity matrix
  static const List<double> _protCorrection = [
    // R       G       B      A   offset
    0.0, 0.0, 0.0, 0.0, 0.0, // Red
    0.303, -0.303, 0.0, 0.0, 0.0, // Green
    0.433, -0.433, 0.0, 0.0, 0.0, // Blue
    0.0, 0.0, 0.0, 0.0, 0.0, // Alpha
  ];

  static const List<double> _deutCorrection = [
    // R       G       B      A   offset
    -0.7, 0.7, 0.0, 0.0, 0.0, // Red
    0.0, 0.0, 0.0, 0.0, 0.0, // Green
    -0.49, 0.49, 0.0, 0.0, 0.0, // Blue
    0.0, 0.0, 0.0, 0.0, 0.0, // Alpha
  ];

  static const List<double> _tritCorrection = [
    // R       G       B      A   offset
    0.0, -0.332, 0.332, 0.0, 0.0, // Red
    0.0, -0.475, 0.475, 0.0, 0.0, // Green
    0.0, 0.0, 0.0, 0.0, 0.0, // Blue
    0.0, 0.0, 0.0, 0.0, 0.0, // Alpha
  ];

  List<double> _getCorrectionMatrix() {
    switch (selectedDefect) {
      case "protanopia":
        return _protCorrection;
      case "deuteranopia":
        return _deutCorrection;
      case "tritanopia":
        return _tritCorrection;
      default:
        return List.filled(20, 0.0);
    }
  }

  /// 🔥 Apply Correction: Final = Identity + (Correction * Intensity * 2.0)
  List<double> _blendedMatrix() {
    final correction = _getCorrectionMatrix();
    // Map slider 0.0-1.0 to multiplier 0.0-2.0 (1.5 matches backend)
    final double multiplier = intensity * 2.0;

    return List.generate(20, (i) {
      // Identity part (diagonal is 1, rest 0)
      double val = _identityMatrix[i];

      // Add correction part
      val += correction[i] * multiplier;

      return val;
    });
  }

  // ---------------- COLOR DETECTION LOGIC ----------------
  Future<void> detectColor(TapDownDetails details) async {
    try {
      final boundary =
          repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final box = boundary as RenderBox;

      // Capture the image from the RepaintBoundary
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null || !mounted) return;

      final localPos = box.globalToLocal(details.globalPosition);
      final x = localPos.dx.toInt();
      final y = localPos.dy.toInt();

      if (x < 0 || y < 0 || x >= image.width || y >= image.height) return;

      // Average 5x5 area (noise reduction)
      int rSum = 0, gSum = 0, bSum = 0, count = 0;

      for (int dx = -2; dx <= 2; dx++) {
        for (int dy = -2; dy <= 2; dy++) {
          final px = x + dx;
          final py = y + dy;

          if (px < 0 || py < 0 || px >= image.width || py >= image.height) {
            continue;
          }

          final i = (py * image.width + px) * 4;
          rSum += byteData.getUint8(i);
          gSum += byteData.getUint8(i + 1);
          bSum += byteData.getUint8(i + 2);
          count++;
        }
      }

      final r = (rSum / count).round();
      final g = (gSum / count).round();
      final b = (bSum / count).round();

      final color = Color.fromARGB(255, r, g, b);
      final name = getColorName(color);

      if (mounted) {
        setState(() {
          detectedColor = name;
        });
      }

      // Check Audio Alerts Setting
      final audioAlerts = Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).audioAlerts;
      if (audioAlerts) {
        await flutterTts.stop();
        await flutterTts.speak(name);
      }
    } catch (e) {
      debugPrint("Color detection error: $e");
    }
  }

  Widget _defectButton(String label) {
    final value = label.toLowerCase();
    final isActive = selectedDefect == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.blue : Colors.black54,
        ),
        onPressed: () {
          setState(() => selectedDefect = value);
        },
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🎥 REAL-TIME VIDEO WITH INTENSITY CONTROL
          RepaintBoundary(
            key: repaintKey,
            child: GestureDetector(
              onTapDown: detectColor,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_blendedMatrix()),
                child: CameraPreview(widget.controller),
              ),
            ),
          ),

          // 🎨 DETECTED COLOR OVERLAY
          if (detectedColor.isNotEmpty)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Detected: $detectedColor",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // TOP BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // BOTTOM CONTROLS
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // DEFECT BUTTONS
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _defectButton("Protanopia"),
                    _defectButton("Deuteranopia"),
                    _defectButton("Tritanopia"),
                  ],
                ),

                const SizedBox(height: 12),

                // 🔥 INTENSITY SLIDER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        "Low",
                        style: TextStyle(color: Colors.white70),
                      ),
                      Expanded(
                        child: Slider(
                          value: intensity,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white38,
                          onChanged: (v) {
                            setState(() => intensity = v);
                          },
                        ),
                      ),
                      const Text(
                        "High",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
