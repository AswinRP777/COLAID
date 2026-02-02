import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // import dotenv
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../widgets/before_after_slider.dart';
import '../utils/color_utils.dart';
import 'saved_images_page.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ImagePreviewPage extends StatefulWidget {
  final File imageFile;

  const ImagePreviewPage({super.key, required this.imageFile});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  Uint8List? processedImage;
  bool loading = false;
  String selectedDefect = "protanopia";

  final FlutterTts flutterTts = FlutterTts();
  String detectedColor = "";

  // 🔑 KEY FOR RENDERED IMAGE
  final GlobalKey repaintKey = GlobalKey();

  // ---------------- PROCESS IMAGE ----------------
  Future<void> processImage() async {
    setState(() => loading = true);

    try {
      final url = "${dotenv.env['API_URL']}/daltonize";
      debugPrint("🚀 SENDING TO: $url");

      final request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['defect'] = selectedDefect;
      request.files.add(
        await http.MultipartFile.fromPath('image', widget.imageFile.path),
      );

      final response = await request.send();
      final bytes = await response.stream.toBytes();

      if (mounted) {
        setState(() {
          processedImage = bytes;
          detectedColor = "";
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ---------------- SAVE IMAGE ----------------
  Future<void> saveEnhancedImage() async {
    if (processedImage == null) return;

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception("Storage not available");

      final saveDir = Directory("${directory.path}/ColAid");
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final filePath =
          "${saveDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.png";

      final file = File(filePath);
      await file.writeAsBytes(processedImage!);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Image saved successfully")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  // ---------------- COLOR DETECTION (FIXED) ----------------
  Future<void> detectColor(TapDownDetails details) async {
    try {
      final boundary =
          repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final box = boundary as RenderBox;

      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) return;
      if (!mounted) return;

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

      await flutterTts.stop();

      if (!mounted) return;
      final audioAlerts = Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).audioAlerts;

      if (audioAlerts) {
        await flutterTts.speak(name);
      }
    } catch (e) {
      debugPrint("Color detection error: $e");
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Color Enhanced Image"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // IMAGE AREA (RENDERED & TAPPABLE)
          Expanded(
            child: RepaintBoundary(
              key: repaintKey,
              child: GestureDetector(
                onTapDown: detectColor,
                child: processedImage == null
                    ? Center(
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : BottomSliderCompare(
                        before: Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                        after: Image.memory(
                          processedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
          ),

          // COLOR NAME DISPLAY
          if (detectedColor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                "Detected color: $detectedColor",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // CONTROLS
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButton<String>(
                  dropdownColor: Colors.black,
                  value: selectedDefect,
                  items: const [
                    DropdownMenuItem(
                      value: "protanopia",
                      child: Text(
                        "Protanopia",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "deuteranopia",
                      child: Text(
                        "Deuteranopia",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "tritanopia",
                      child: Text(
                        "Tritanopia",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      selectedDefect = v!;
                      processedImage = null;
                      detectedColor = "";
                    });
                  },
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : processImage,
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text(loading ? "Processing..." : "Enhance Colors"),
                  ),
                ),

                if (processedImage != null) ...[
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saveEnhancedImage,
                      icon: const Icon(Icons.download),
                      label: const Text("Save Enhanced Image"),
                    ),
                  ),

                  const SizedBox(height: 6),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedImagesPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text("View Saved Images"),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
