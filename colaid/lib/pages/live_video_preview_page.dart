import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class LiveVideoPreviewPage extends StatefulWidget {
  final CameraController controller;

  const LiveVideoPreviewPage({
    super.key,
    required this.controller,
  });

  @override
  State<LiveVideoPreviewPage> createState() =>
      _LiveVideoPreviewPageState();
}

class _LiveVideoPreviewPageState extends State<LiveVideoPreviewPage> {
  String selectedDefect = "protanopia";
  double intensity = 1.0; // 🔥 NEW: intensity slider value

  // Identity matrix
  static const List<double> _identityMatrix = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  List<double> _cvdMatrix() {
    switch (selectedDefect) {
      case "protanopia":
        return [
          0.567, 0.433, 0, 0, 0,
          0.558, 0.442, 0, 0, 0,
          0, 0.242, 0.758, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case "deuteranopia":
        return [
          0.625, 0.375, 0, 0, 0,
          0.7, 0.3, 0, 0, 0,
          0, 0.3, 0.7, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case "tritanopia":
        return [
          0.95, 0.05, 0, 0, 0,
          0, 0.433, 0.567, 0, 0,
          0, 0.475, 0.525, 0, 0,
          0, 0, 0, 1, 0,
        ];
      default:
        return _identityMatrix;
    }
  }

  /// 🔥 Blend identity & CVD matrix using intensity
  List<double> _blendedMatrix() {
    final cvd = _cvdMatrix();
    return List.generate(20, (i) {
      return _identityMatrix[i] * (1 - intensity) +
          cvd[i] * intensity;
    });
  }

  Widget _defectButton(String label) {
    final value = label.toLowerCase();
    final isActive = selectedDefect == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isActive ? Colors.blue : Colors.black54,
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
          ColorFiltered(
            colorFilter: ColorFilter.matrix(_blendedMatrix()),
            child: CameraPreview(widget.controller),
          ),

          // TOP BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white),
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
